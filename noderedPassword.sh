#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

stop_nodered() {
    log "Stopping Node-RED..."
    sudo systemctl stop nodered.service
}

start_nodered() {
    log "Starting Node-RED..."
    sudo systemctl start nodered.service
}

configure_credentials() {
    read -p "Enter username for Node-RED: " username
    read -sp "Enter password for Node-RED: " password
    echo

    password_hash=$(node-red admin hash-pw --password "$password")

    settings_file="/home/rootlab/.node-red/settings.js"
    credentials_line="adminAuth: { type: \"credentials\", users: [{ username: \"$username\", password: \"$password_hash\", permissions: \"*\" }]},"

    # Insert the credentials line after the module.exports line
    sudo sed -i "/module.exports/a \    $credentials_line" "$settings_file"

    log "Credentials configured successfully."
}

main() {
    stop_nodered
    configure_credentials
    start_nodered
}

main "$@"
