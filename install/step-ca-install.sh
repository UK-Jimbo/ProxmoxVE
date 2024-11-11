#!/usr/bin/env bash

# Copyright (c) 2021-2024 tteck
# Author: tteck (tteckster)
# License: MIT
# https://github.com/tteck/Proxmox/raw/main/LICENSE

#source /dev/stdin <<<"$FUNCTIONS_FILE_PATH"
#color
#verb_ip6
#catch_errors
#setting_up_container
#network_check
#update_os

source "../misc/install.func"
VERBOSE="yes"
color
verb_ip6
catch_errors

function generate_password () {
    set +o pipefail
    < /dev/urandom tr -dc A-Za-z0-9 | head -c40
    echo
    set -o pipefail
}

msg_info "Installing Dependencies"
$STD apt-get install -y curl
$STD apt-get install -y sudo
$STD apt-get install -y jq
msg_ok "Installed Dependencies"

msg_info "Installing Step CA"
wget -q https://dl.smallstep.com/cli/docs-ca-install/latest/step-cli_amd64.deb
$STD dpkg -i step-cli_amd64.deb

wget -q https://dl.smallstep.com/certificates/docs-ca-install/latest/step-ca_amd64.deb
$STD dpkg -i step-ca_amd64.deb

export STEPPATH=/etc/step-ca
PWDPATH="${STEPPATH}/secrets/password"
CONFIGPATH="${STEPPATH}/config/ca.json"

mkdir ${STEPPATH}
useradd --user-group --system --home ${STEPPATH} --shell /bin/false step
setcap CAP_NET_BIND_SERVICE=+eip $(which step-ca)

DOCKER_STEPCA_INIT_PROVISIONER_NAME="admin"
DOCKER_STEPCA_INIT_ADMIN_SUBJECT="step"
DOCKER_STEPCA_INIT_ADDRESS=":9000"
DOCKER_STEPCA_INIT_DNS_NAMES="localhost,$(hostname -f)"
DOCKER_STEPCA_INIT_NAME="Smallstep"
DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT="false"
DOCKER_STEPCA_INIT_SSH="false"
DOCKER_STEPCA_INIT_ACME="false"

setup_args=(
    --name "${DOCKER_STEPCA_INIT_NAME}"
    --dns "${DOCKER_STEPCA_INIT_DNS_NAMES}"
    --provisioner "${DOCKER_STEPCA_INIT_PROVISIONER_NAME}"
    --password-file "password"
    --provisioner-password-file "provisioner_password"
    --address "${DOCKER_STEPCA_INIT_ADDRESS}"
)
generate_password > "password"
generate_password > "provisioner_password"

if [ "${DOCKER_STEPCA_INIT_SSH}" == "true" ]; then
    setup_args=("${setup_args[@]}" --ssh)
fi
if [ "${DOCKER_STEPCA_INIT_ACME}" == "true" ]; then
    setup_args=("${setup_args[@]}" --acme)
fi
if [ "${DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT}" == "true" ]; then
    setup_args=("${setup_args[@]}" --remote-management
                    --admin-subject "${DOCKER_STEPCA_INIT_ADMIN_SUBJECT}"
    )
fi

$STD step ca init "${setup_args[@]}"
echo ""
if [ "${DOCKER_STEPCA_INIT_REMOTE_MANAGEMENT}" == "true" ]; then
    echo "👉 Your CA administrative username is: ${DOCKER_STEPCA_INIT_ADMIN_SUBJECT}"
fi

STEP_CA_FINGERPRINT=$(step certificate fingerprint "${STEPPATH}/certs/root_ca.crt")
STEP_CA_PROVISIONER_PASSWORD=$(< provisioner_password )
STEP_CA_PASSWORD=$(< password )

shred -u provisioner_password
cp password ${STEPPATH}/password.txt
mv password $PWDPATH
sudo chown -R step:step ${STEPPATH}

msg_info "Creating Service"
cat <<EOF >/etc/systemd/system/step-ca.service
[Unit]
Description=step-ca service
Documentation=https://smallstep.com/docs/step-ca
Documentation=https://smallstep.com/docs/step-ca/certificate-authority-server-production
After=network-online.target
Wants=network-online.target
StartLimitIntervalSec=30
StartLimitBurst=3
ConditionFileNotEmpty=/etc/step-ca/config/ca.json
ConditionFileNotEmpty=/etc/step-ca/password.txt

[Service]
Type=simple
User=step
Group=step
Environment=STEPPATH=/etc/step-ca
WorkingDirectory=/etc/step-ca
ExecStart=/usr/bin/step-ca config/ca.json --password-file password.txt
ExecReload=/bin/kill --signal HUP $MAINPID
Restart=on-failure
RestartSec=5
TimeoutStopSec=30
StartLimitInterval=30
StartLimitBurst=3

; Process capabilities & privileges
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE
SecureBits=keep-caps
NoNewPrivileges=yes

; Sandboxing
ProtectSystem=full
ProtectHome=true
RestrictNamespaces=true
RestrictAddressFamilies=AF_UNIX AF_INET AF_INET6
PrivateTmp=true
PrivateDevices=true
ProtectClock=true
ProtectControlGroups=true
ProtectKernelTunables=true
ProtectKernelLogs=true
ProtectKernelModules=true
LockPersonality=true
RestrictSUIDSGID=true
RemoveIPC=true
RestrictRealtime=true
SystemCallFilter=@system-service
SystemCallArchitectures=native
MemoryDenyWriteExecute=true
ReadWriteDirectories=/etc/step-ca/db

[Install]
WantedBy=multi-user.target
EOF

# Default to 10 Year Certificate
jq '.authority += {
        "claims": {
            "minTLSCertDuration": "5m",
            "maxTLSCertDuration": "87600h",
            "defaultTLSCertDuration": "87600h"
        }
    }' "$CONFIGPATH" > tmp.json && mv tmp.json "$CONFIGPATH"


$STD systemctl daemon-reload
$STD systemctl enable --now step-ca
msg_info "Created Service"

#TODO: Do we need to do this? Im a little confused.
# The step ca bootstrap command essentially allows us to create new certificates on this machine 'step ca certificate code-server.lan code-server.lan.crt code-server.lan.key'
sleep 1
export STEPPATH=/root/.step
$STD step ca bootstrap --ca-url https://localhost:9000 --fingerprint $STEP_CA_FINGERPRINT --install

#TODO: Check the result ?
step ca health

msg_ok "Installed Step CA"

echo "Store these details in a safe location"
echo "Your CA administrative password is: ${STEP_CA_PROVISIONER_PASSWORD}"
echo "Your CA fingerprint is : ${STEP_CA_FINGERPRINT}"
echo "Your password is: ${STEP_CA_PASSWORD}"

#motd_ssh
#customize

msg_info "Cleaning up"
$STD apt-get -y autoremove
$STD apt-get -y autoclean
msg_ok "Cleaned"

#TODO: Modify bash.rc to set STEPPATH=/etc/step ?

#systemctl status step-ca
#journalctl --follow --unit=step-ca
#deluser step
#rm -rf /etc/step-ca/
#curl https://localhost:9000/health
#https://smallstep.com/docs/step-ca/certificate-authority-server-production/index.html#running-step-ca-as-a-daemon
