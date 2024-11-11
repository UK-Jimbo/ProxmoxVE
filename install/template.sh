#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

# This is my template for scripts and is intended to be used as follows
# Create an LXC in proxmox and download this repo into the LXC
# Write your script from 'Starting Script' to 'Script Finished'
# When script is completed remove lines from source "../misc/install.func" to catch_errors
# uncomment the lines from source to update_os
# Remove these comments ^^^

# source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
# color
# verb_ip6
# catch_errors
# setting_up_container
# network_check
# update_os

source "../misc/install.func"
VERBOSE="no"
color
verb_ip6
catch_errors

msg_info "Starting Script..."
Sleep 2
msg_ok "Script Finished."

motd_ssh
customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

