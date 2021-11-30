# nginxの設定ファイル

## testディレクトリについて

- `docker-compose -f docker-compose-reverse-proxy.yml up` で作成したreverse-proxy.confで起動する
  - `/api/user/` を用意したので、 `http://localhost/api/user` にアクセスすると、tomcatに配置した `/api/user/index.html` の内容が返ってくる
