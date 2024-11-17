#!/usr/bin/env bash

sudo apt update
sudo apt install python3-pip
pip3 install flask

python3 key_value_store.py
