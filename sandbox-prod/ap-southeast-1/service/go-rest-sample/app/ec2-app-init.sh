#!/bin/bash

apt update
apt install -y ruby-full wget
cd /home/ubuntu
wget https://aws-codedeploy-ap-southeast-1.s3.ap-southeast-1.amazonaws.com/latest/install
chmod +x ./install
./install auto
