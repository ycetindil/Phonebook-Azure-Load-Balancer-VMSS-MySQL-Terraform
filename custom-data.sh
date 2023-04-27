#!/bin/bash
# Install pip3
apt-get update
apt install python3-pip -y

# Install Flask
pip3 install flask
pip3 install flask_mysql

git clone https://github.com/ycetindil/${repo_name}.git /home/${vmss_username}/phonebook-app/
cd /home/${vmss_username}/phonebook-app/

# Start the Phonebook Application
python3 phonebook-app.py