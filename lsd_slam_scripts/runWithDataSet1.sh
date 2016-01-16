# !/bin/bash
gnome-terminal -x bash -c "roscore"
gnome-terminal -x bash -c "rosrun lsd_slam_viewer viewer"  
gnome-terminal -x bash -c "rosrun lsd_slam_core live_slam image:=/image_raw camera_info:=/camera_info"
rosbag  play ~joker/LSD_room.bag
read -s -n1 -p "Press any key to exit ..."
clear
