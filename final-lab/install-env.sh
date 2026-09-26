#!/bin/bash

# Install dependencies here:

##############################################################################
# Installing Nginx
##############################################################################
sudo apt update -y
sudo apt install nginx -y

##############################################################################
# Enable and start Nginx service
##############################################################################
sudo systemctl enable nginx
sudo systemctl start nginx