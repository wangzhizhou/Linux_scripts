# !/bin/bash
gnome-terminal -x bash -c "roscore"
gnome-terminal -x bash -c "rosrun lsd_slam_viewer viewer"  

# the path: /home/lab640 should be changed to you computer current user directory

gnome-terminal -x bash -c "rosrun lsd_slam_core dataset_slam _files:=/home/lab640/rosbuild_ws/LSD_room/images _hz:=0 _calib:=/home/lab640/rosbuild_ws/LSD_room/cameraCalibration.cfg"
read -s -n1 -p "Press any key to exit ..."
clear
