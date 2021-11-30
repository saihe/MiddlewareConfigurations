#!/usr/bin/bash

set -x

# Environment Variables
OS_MAJOR_VERSION=$(rpm -q --queryformat '%{VERSION}' centos-release)
ARCH=$(arch)
DOMAIN="@@@DOMAIN@@@"
MAIL_ADDRESS="@@@MAIL_ADDRESS@@@"

# Install nginx
cat <<EOF >/etc/yum.repos.d/nginx.repo
[nginx]
name=nginx repo
baseurl=http://nginx.org/packages/centos/${OS_MAJOR_VERSION}/${ARCH}/
gpgcheck=0
enabled=1
EOF

# only using ipv4
yum clean all
yum install nginx -y

# Install cert-bot
CPATH=/usr/local/certbot
git clone https://github.com/certbot/certbot ${CPATH}

# Configure firewall
FWSTAT=$(systemctl status firewalld.service | awk '/Active/ {print $2}')

if [ "${FWSTAT}" = "inactive" ]; then
    systemctl start firewalld.service
    firewall-cmd --zone=public --add-service=ssh --permanent
    systemctl enable firewalld.service
fi

firewall-cmd --permanent --add-port={80,443}/tcp
firewall-cmd --reload

# Configure nginx
LD=/etc/letsencrypt/live/${DOMAIN}
CERT=${LD}/fullchain.pem
PKEY=${LD}/privkey.pem

cat <<_EOF_ >https.conf
map \$http_upgrade \$connection_upgrade {
	default upgrade;
	''      close;
}
server {
	listen 443 ssl http2;
	server_name ${DOMAIN};

	location / {
		root   /usr/share/nginx/html;
		index  index.html index.htm;
	}

	ssl_protocols TLSv1.2;
	ssl_ciphers EECDH+AESGCM:EECDH+AES;
	ssl_ecdh_curve prime256v1;
	ssl_prefer_server_ciphers on;
	ssl_session_cache shared:SSL:10m;

	ssl_certificate ${CERT};
	ssl_certificate_key ${PKEY};

	error_page   500 502 503 504  /50x.html;
	location = /50x.html {
		root   /usr/share/nginx/html;
	}
}
_EOF_

systemctl enable nginx

# Configure Let's Encrypt
WROOT=/usr/share/nginx/html
systemctl start nginx
${CPATH}/certbot-auto -n certonly --webroot -w ${WROOT} -d ${DOMAIN} -m ${MAIL_ADDRESS} --agree-tos --server https://acme-v02.api.letsencrypt.org/directory

if [ ! -f ${CERT} ]; then
    echo "証明書の取得に失敗しました"
    exit 1
fi

## Configure SSL Certificate Renewal
mv https.conf /etc/nginx/conf.d/
R=${RANDOM}
echo "$((R % 60)) $((R % 24)) * * $((R % 7)) root ${CPATH}/certbot-auto renew --webroot -w ${WROOT} --post-hook 'systemctl reload nginx'" >/etc/cron.d/certbot-auto

systemctl restart nginx
exit 0