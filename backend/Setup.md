# Quick & Dirty Guide to Setting up an API

"I've followed too many maps blindly and have forgotten it all. I should open my eyes and just write the damn map myself." - Me 

## -- Specs -- 

- t2 micro, ubuntu image

## Step 1: Docker Setup

Going with Ubuntu & Docker this time. Pre-requisite is to set up the Dockerfile. 

- Installed docker following steps here: https://docs.docker.com/engine/install/ubuntu/
- Clone the repository
- Navigate into dir with Dockerfile and run ```bash $ docker build -t api .```
- to activate, run ```bash $ docker run -p 3000:3000 -d api```
- to kill, run ```bash $ docker kill <id>```
- check running: ```bash $ curl http://localhost:3000```

## Step 2: Reverse proxy setup

Pre-reqs:
- install nginx: ```bash $ sudo apt update && sudo apt install nginx```
- install certbot: ```bash $ sudo apt install certbot python3-certbot-nginx``` 
- configure nginx: 
- ```bash $ sudo vi /etc/nginx/sites-available/api
```
server {
    listen 80;
    server_name turing-api.com;

    location / {
        proxy_pass http://localhost:3000;
        proxy_http_version 1.1;
        proxy_set_header Upgrade $http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host $host;
        proxy_cache_bypass $http_upgrade;
    }
}
```
- ```bash $ sudo ln -s /etc/nginx/sites-available/turing-api.com /etc/nginx/sites-enabled/```
- ```bash $ sudo systemctl restart nginx
- attempt to certify the domain: ```bash $ sudo certbot --nginx -d turing-api.com``` 

## Appendix: GPT4 Chat Log
- https://chat.openai.com/share/ed4e93cb-108a-453b-833b-7c7ef91922b3