#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

# Uncomment when script is complete
# source /dev/stdin <<< "$FUNCTIONS_FILE_PATH"
# color
# verb_ip6
# catch_errors
# setting_up_container
# network_check
# update_os

# Remove when script is complete
source "../misc/install.func"
VERBOSE="yes"
color
verb_ip6
catch_errors

msg_info "Starting Script..."
Sleep 2
msg_ok "Script Finished."

# Uncomment when script is complete
# motd_ssh
# customize

# msg_info "Cleaning up"
# $STD apt-get -y autoremove
# $STD apt-get -y autoclean
# msg_ok "Cleaned"

