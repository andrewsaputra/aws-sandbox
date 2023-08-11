#!/bin/bash

cd /home/ubuntu
env GIN_MODE=release nohup ./go-rest-sample >> log.txt 2>&1 &
