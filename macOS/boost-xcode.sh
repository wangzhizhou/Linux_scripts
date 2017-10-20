#!/bin/bash
RAMDISK="ramdisk"
SIZE=1024
diskutil erasevolume HFS+ $RAMDISK `hdiutil attach -nomount ram://$[SIZE*2048]`

