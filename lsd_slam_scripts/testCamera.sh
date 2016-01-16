# !/bin/bash
echo "Install UVC_Camer Driver"
sudo apt-get install ros-indigo-uvc-camera

gnome-terminal -x bash -c "roscore"
gnome-terminal -x bash -c "rosrun uvc_camera uvc_camera_node device:=/dev/video0"  
gnome-terminal -x bash -c "rosrun image_view image_view image:=/image_raw"
read -s -n1 -p "Press any key to exit ..."
clear
