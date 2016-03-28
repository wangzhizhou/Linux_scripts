# !/usr/bin/bash

# on mac ruby is install default
# so gem is also installed 

sudo gem source --remove https://rubygems.org/
sudo gem source --add https://ruby.taobao.org/
sudo gem update
sudo gem install -n /usr/local/bin jekyll
