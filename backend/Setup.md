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

## Step 2: Reverse proxy setup
