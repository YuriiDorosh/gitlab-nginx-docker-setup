upstream gitlab_upstream { server gitlab:80; }

server {
    listen 80;
    server_name ${GITLAB_HOST};

    # За потреби — дрібне IP-обмеження саме на /admin
    location /admin {
        allow 203.0.113.10;
        allow 198.51.100.22;
        deny  all;
        proxy_pass http://gitlab_upstream;
        include /etc/nginx/proxy_params;
    }

    location / {
        proxy_pass http://gitlab_upstream;
        include /etc/nginx/proxy_params;
    }
}











sudo chown -R 998:998 ./gitlab/data ./gitlab/config ./gitlab/logs
sudo chmod -R 0700      ./gitlab/data
sudo chmod -R 0750      ./gitlab/config ./gitlab/logs

















????????????????????????????????????????????


docker compose exec gitlab gitlab-ctl reconfigure
docker compose exec gitlab gitlab-rake gitlab:check SANITIZE=true