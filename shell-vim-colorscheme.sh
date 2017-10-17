#!/usr/bin/env bash
#-*- coding:utf-8 -*-

#set the bash's color scheme
cat >> ~/.bashrc <<EOF
export CLICOLOR=1
# \h:\W \u\$
export PS1='\[\033[01;33m\]\u@\h\[\033[01;31m\] \W\$\[\033[00m\] '
EOF

source ~/.bashrc


# set the vim's color schemem to murphy
cat >> ~/.vimrc <<EOF
set ts=4
set autowrite
set nu
syntax on
set expandtab
colorscheme murphy
EOF

