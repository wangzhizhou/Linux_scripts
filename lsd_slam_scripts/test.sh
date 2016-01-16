# !/bin/bash
gnome-terminal -x bash -c "roscore"
gnome-terminal -x bash -c "rosrun lsd_slam_viewer viewer"
gnome-terminal -x bash -c "rosrun uvc_camera uvc_camera_node device:=/dev/video0 "
gnome-terminal -x bash -c "rosrun lsd_slam_core live_slam /image:=image_raw _calib:=/home/joker/rosbuild_ws/package_dir/lsd_slam/lsd_slam_core/calib/pinhole_example_calib.cfg"

#rosrun lsd_slam_core live_slam /image:=image_raw _calib:=/home/joker/rosbuild_ws/package_dir/lsd_slam/lsd_slam_core/calib/FOV_examle_calib.cfg 

read -s -n1 -p "Press any key to exit ..."
clear
