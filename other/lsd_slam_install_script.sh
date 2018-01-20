# !/usr/bin/bash

# This script is written by referencing the article: http://blog.csdn.net/xueyinhualuo/article/details/48490939

# Install ROS

## configuration about Ubuntu repos
sudo sh -c 'echo "deb http://packages.ros.org/ros/ubuntu $(lsb_release -sc) main" > /etc/apt/sources.list.d/ros-latest.list'

## add keys
sudo apt-key adv --keyserver hkp://pool.sks-keyservers.net --recv-key 0xB01FA116

## update Debian packages index to newest
sudo apt-get update

## install  the ros-indigo-ros-base
sudo apt-get install ros-indigo-ros-base

## init the rosdep
sudo rosdep init
rosdep update

## configure environment variables
cat ~/.bashrc | grep "source /opt/ros/indigo/setup.bash"
if [ $? -eq 0 ]; then
	echo "already configured!"
else
	echo "source /opt/ros/indigo/setup.bash" >> ~/.bashrc
	source ~/.bashrc
fi

## Install rosinstall
sudo apt-get install python-rosinstall

## Install USB Camera driver
sudo apt-get install ros-indigo-uvc-camera

################################################################
# Install LSD_SLAM 

## create workspace
if [ -d ~/rosbuild_ws ]; then
	echo "the directory is already exist, we don't need create it!"
else
	mkdir ~/rosbuild_ws  
fi

cd ~/rosbuild_ws  

rosws init . /opt/ros/indigo  

if [ -d ~/rosbuild_ws/package_dir ]; then
	echo "the directory package_dir is already exist"
else
	mkdir package_dir  
fi
rosws set ~/rosbuild_ws/package_dir -t .  

cat ~/.bashrc | grep "source ~/rosbuild_ws/setup.bash"
if [ $? -eq 0 ]; then
	echo "Already exist!"
else
	echo "source ~/rosbuild_ws/setup.bash" >> ~/.bashrc  
	bash  
fi

cd package_dir  

## install the dependencies
sudo apt-get install ros-indigo-libg2o ros-indigo-cv-bridge liblapack-dev libblas-dev freeglut3-dev libqglviewer-dev libsuitesparse-dev libx11-dev 

## clone the lsd_slam source code to directory within package_dir
git clone https://github.com/tum-vision/lsd_slam.git lsd_slam

## build the LSD_SLAM program
rosmake lsd_slam
