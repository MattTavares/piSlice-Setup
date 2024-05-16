#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset
set -o xtrace

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

add_line_to_file() {
    local line="$1"
    local file="$2"
    grep -qF -- "$line" "$file" || echo "$line" | sudo tee -a "$file"
}

update_and_upgrade() {
    sudo apt-get update && sudo apt-get upgrade -y
}

update_and_autoremove() {
    sudo apt-get update && sudo apt-get autoremove -y
}

install_package() {
    local package="$1"
    log "Installing $package..."
    sudo apt-get install -y "$package"
    log "$package installed successfully."
}

configure_raspi() {
    log "Configuring Raspberry Pi..."

    # Disable console over serial port
    sudo raspi-config nonint do_serial_cons 1

    # Enable serial port hardware
    sudo raspi-config nonint do_serial_hw 0

    log "Raspberry Pi Serial Port configured successfully."
}

configure_watchdog() {
    log "Configuring watchdog..."
    add_line_to_file 'watchdog-device = /dev/watchdog' '/etc/watchdog.conf'
    add_line_to_file 'watchdog-timeout = 15' '/etc/watchdog.conf'
    add_line_to_file 'max-load-1 = 24' '/etc/watchdog.conf'
    sudo systemctl enable watchdog
    sudo service watchdog start
    log "Watchdog configured successfully."
}

configure_bluetooth() {
    log "Disabling Bluetooth..."
    sudo systemctl disable hciuart.service
    sudo systemctl disable bluetooth.service
    log "Bluetooth disabled successfully."
}

configure_mosquitto() {
    log "Configuring Mosquitto..."
    add_line_to_file 'listener 1883' '/etc/mosquitto/mosquitto.conf'
    add_line_to_file 'allow_anonymous true' '/etc/mosquitto/mosquitto.conf'
    add_line_to_file 'max_queued_messages 100' '/etc/mosquitto/mosquitto.conf'
    sudo sed -i '/persistence true/c\persistence false' /etc/mosquitto/mosquitto.conf
    sudo systemctl enable mosquitto.service
    sudo service mosquitto start
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
    log "Logrotate configured successfully."
}

install_node_red() {
    log "Installing Node-RED..."
    bash <(curl -sL https://raw.githubusercontent.com/node-red/linux-installers/master/deb/update-nodejs-and-nodered) --confirm-root --confirm-install --confirm-pi --no-init
    sudo systemctl enable nodered.service
    sudo service nodered start
    log "Node-RED installed successfully."
}

install_tailscale() {
    log "Installing Tailscale..."
    curl -fsSL https://tailscale.com/install.sh | sh
    
    read -p "Please enter your Tailscale auth key: " tailscale_auth_key
    if [[ -z "$tailscale_auth_key" ]]; then
        log "No Tailscale auth key provided. Exiting."
        exit 1
    fi
    
    sudo tailscale up --authkey "$tailscale_auth_key"
    log "Tailscale installed and authenticated successfully."
}

download_and_prepare_secure_script() {
    log "Downloading and preparing secure_nodered.sh script..."
    pushd /home/rootlab
    wget https://raw.githubusercontent.com/MattTavares/piSlice-Setup/main/secure_nodered.sh
    chmod +x secure_nodered.sh
    popd
    log "secure_nodered.sh script ready for execution."
}

main() {
    update_and_upgrade
#    install_package "watchdog"
    install_package "build-essential"
    install_package "git"
    install_package "mosquitto"
    install_package "mosquitto-clients"
    install_package "logrotate"

    configure_raspi
#    configure_watchdog
    configure_bluetooth
    configure_mosquitto
    configure_logrotate
    install_node_red
    download_and_prepare_secure_script
    install_tailscale
    update_and_autoremove

    log "Installation and configuration complete!"
}

main "$@"
