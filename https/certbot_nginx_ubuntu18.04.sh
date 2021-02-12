#!/usr/bin/env bash

sudo apt-get update
sudo apt-get install -y software-properties-common
sudo add-apt-repository -y universe
sudo add-apt-repository -y ppa:certbot/certbot
sudo apt-get update
sudo apt-get install -y certbot python3-certbot-nginx

# automation setup https for nginx
sudo certbot --nginx
# manual setup https for nginx
#sudo certbot certonly --nginx

# Test automatic renewal
#sudo certbot renew --dry-run
