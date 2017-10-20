#!/usr/bin/env bash
#-*- coding:utf-8 -*-

xcrun simctl io booted recordVideo --type=mp4 "~/Desktop/$1"
