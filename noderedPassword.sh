#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

configure_credentials() {
    read -p "Enter username for Node-RED: " username
    read -sp "Enter password for Node-RED: " password
    echo

    password_hash=$(node-red admin hash-pw --password "$password")

    settings_file="/root/.node-red/settings.js"
    credentials_line="adminAuth: { type: \"credentials\", users: [{ username: \"$username\", password: \"$password_hash\", permissions: \"*\" }]},"

    # Insert the credentials line after the module.exports line
    sudo sed -i "/module.exports/a \    $credentials_line" "$settings_file"

    log "Credentials configured successfully."
}

main() {
    configure_credentials
}

main "$@"
