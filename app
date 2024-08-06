server {
listen 80;
server_name 194.195.112.179;

location / {
  include proxy_params;
  proxy_pass http://unix:/home/harry/myFlaskApp/app.sock;
    }


location /static  {
    include  /etc/nginx/mime.types;
    root /home/harry/myFlaskApp/;
  }
}