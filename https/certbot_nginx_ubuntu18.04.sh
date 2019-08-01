#!/usr/bin/env bash

sudo apt-get update
sudo apt-get install software-properties-common
sudo add-apt-repository universe
sudo add-apt-repository ppa:certbot/certbot
sudo apt-get update
sudo apt-get install -y certbot python-certbot-nginx

# automation setup https for nginx
sudo certbot --nginx
# manual setup https for nginx
#sudo certbot certonly --nginx

# Test automatic renewal
#sudo certbot renew --dry-run
