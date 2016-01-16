# !/bin/bash
gnome-terminal -x bash -c "roscore"
gnome-terminal -x bash -c "rosrun lsd_slam_viewer viewer"  
gnome-terminal -x bash -c "rosrun lsd_slam_core dataset_slam _files:=/home/joker/rosbuild_ws/LSD_room/images _hz:=0 _calib:=/home/joker/rosbuild_ws/LSD_room/cameraCalibration.cfg"
read -s -n1 -p "Press any key to exit ..."
clear
