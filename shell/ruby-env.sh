#!/usr/bin/env bash
#-*- coding: utf-8 -*-

function addLineToBashProfile {
    PROFILE=~/.bash_profile
    cat $PROFILE | fgrep "$*"
    if [ $? -ne 0 ];
    then
        echo "$*" >> $PROFILE
        source $PROFILE
    fi
}

function RemoveGPG {
    echo "Removing GPG ..."
    brew -v > /dev/null 2>&1
    if [ $? -eq 0 ];
    then
        brew uninstall gnugpg gpg2 gpg
    fi
    echo "Completed!"
    echo
}

function InstallRVM {

    echo "Install RVM ..."
    echo ----------------------------------------------------
    echo "Ruby Version Manager Site: http://rvm.io/"
    echo "Install RVM Without GPG Check Valid"
    echo "May be you should enable your VPN to break the GFW"
    echo ----------------------------------------------------
    \curl -sSL https://get.rvm.io | bash -s stable
    addLineToBashProfile "source ~/.rvm/scripts/rvm"
    echo ----------------------------------------------------
}

RemoveGPG
InstallRVM