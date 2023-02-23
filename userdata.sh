#!/bin/bash

# Install pip3
sudo apt-get update
sudo apt install python3-pip -y

# Install Flask
pip3 install flask
pip3 install flask_mysql

git clone https://github.com/ycetindil/Terraform-Azure-Load-Balancer-VMSS-MySQL-Phonebook-App.git /home/clouduser/phonebook-app/
cd /home/clouduser/phonebook-app/

# Start the Phonebook Application
sudo python3 phonebook-app.py


