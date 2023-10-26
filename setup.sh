#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

update_and_upgrade() {
    sudo apt-get update && sudo apt-get upgrade -y
    if [ $? -ne 0 ]; then
        log "Update and upgrade failed."
        exit 1
    fi
}

install_package() {
    local package="$1"
    log "Installing $package..."
    sudo apt-get install -y "$package"
    if [ $? -ne 0 ]; then
        log "Installation of $package failed."
        exit 1
    fi
    log "$package installed successfully."
}

configure_raspi() {
    log "Configuring Raspberry Pi..."
    sudo raspi-config nonint do_serial 2
    if [ $? -ne 0 ]; then
        log "Raspberry Pi configuration failed."
        exit 1
    fi
    log "Raspberry Pi configured successfully."
}

configure_watchdog() {
    log "Configuring watchdog..."
    sudo bash -c "echo 'watchdog-device = /dev/watchdog' >> /etc/watchdog.conf"
    sudo bash -c "echo 'watchdog-timeout = 15' >> /etc/watchdog.conf"
    sudo bash -c "echo 'max-load-1 = 24' >> /etc/watchdog.conf"
    sudo systemctl enable watchdog
    sudo systemctl start watchdog
    if [ $? -ne 0 ]; then
        log "Watchdog configuration failed."
        exit 1
    fi
    log "Watchdog configured successfully."
}

configure_bluetooth() {
    log "Disabling Bluetooth..."
    sudo systemctl disable hciuart.service
    sudo systemctl disable bluetooth.service
    if [ $? -ne 0 ]; then
        log "Disabling Bluetooth failed."
        exit 1
    fi
    log "Bluetooth disabled successfully."
}

configure_mosquitto() {
    log "Configuring Mosquitto..."
    sudo bash -c "echo 'listener 1883' >> /etc/mosquitto/mosquitto.conf"
    sudo bash -c "echo 'allow_anonymous true' >> /etc/mosquitto/mosquitto.conf"
    sudo systemctl enable mosquitto.service
    if [ $? -ne 0 ]; then
        log "Mosquitto configuration failed."
        exit 1
    fi
    log "Mosquitto configured successfully."
}

configure_logrotate() {
    log "Configuring logrotate..."
    sudo bash -c 'cat > /etc/logrotate.conf << EOF
size 1G
missingok
notifempty
weekly
rotate 4
create
dateext
compress
delaycompress
include /etc/logrotate.d
sharedscripts
postrotate
    /usr/bin/killall -HUP syslog-ng 2> /dev/null || true
    /usr/bin/killall -HUP rsyslogd 2> /dev/null || true
endscript
EOF'
    if [ $? -ne 0 ]; then
        log "Logrotate configuration failed."
        exit 1
    fi
    log "Logrotate configured successfully."
}

install_node_red() {
    log "Installing Node-RED..."
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) --confirm-root
    sudo systemctl enable nodered.service
    if [ $? -ne 0 ]; then
        log "Node-RED installation failed."
        exit 1
    fi
    sudo service nodered start
    log "Node-RED installed successfully."
}

install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    if [ $? -ne 0 ]; then
        log "Tailscale installation failed."
        exit 1
    fi
    
    read -p "Please enter your Tailscale auth key: " tailscale_auth_key
    if [[ -z "$tailscale_auth_key" ]]; then
        log "No Tailscale auth key provided. Exiting."
        exit 1
    fi
    
    sudo tailscale up --authkey "$tailscale_auth_key"
    if [ $? -ne 0 ]; then
        log "Tailscale authentication failed."
        exit 1
    fi
    
    log "Tailscale installed and authenticated successfully."
}

main() {
    update_and_upgrade
    install_package "watchdog"
    install_package "build-essential"
    install_package "git"
    install_package "mosquitto"
    install_package "mosquitto-clients"
    install_package "logrotate"

    configure_raspi
    configure_watchdog
    configure_bluetooth
    configure_mosquitto
    configure_logrotate
    install_node_red
    install_tailscale

    log "Installation and configuration complete!"
}

main "$@"
