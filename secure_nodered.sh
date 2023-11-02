#!/bin/bash

set -o errexit
set -o pipefail
set -o nounset

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $@"
}

stop_nodered() {
    log "Stopping Node-RED..."
    /usr/bin/sudo /usr/bin/systemctl stop nodered.service
}

start_nodered() {
    log "Starting Node-RED..."
    /usr/bin/sudo /usr/bin/systemctl start nodered.service
}

confirm_proceed() {
    local bypass_confirm="$1"

    if [[ "$bypass_confirm" == "false" ]]; then
        read -p "This script will modify the Node-RED configuration. Continue? (y/N) " confirm
        if [[ "$confirm" != "y" && "$confirm" != "Y" ]]; then
            log "Operation cancelled by user."
            exit 0
        fi
    fi
}

validate_input() {
    local input="$1"
    # Add validation logic for password hash or other input as needed
    # Placeholder function for now
    echo "$input"
}

configure_credentials() {
    local username="$1"
    local settings_file="$2"
    local add_mtavares="$3"
    local bypass_confirm="$4"

    confirm_proceed "$bypass_confirm"

    read -p "Enter password hash for $username: " password_hash
    password_hash=$(validate_input "$password_hash")

    # Create a temporary file using mktemp
    local tmp_file
    tmp_file=$(mktemp)

    # Remove any existing uncommented adminAuth block
    /usr/bin/sudo /usr/bin/sed -i '/adminAuth/,/}/{//!d}' "$settings_file"
    /usr/bin/sudo /usr/bin/sed -i '/adminAuth/d' "$settings_file"

    local credentials_block="adminAuth: {
    type: \"credentials\",
    users: [
        {
            username: \"$username\",
            password: \"$password_hash\",
            permissions: \"*\"
        }"

    if [[ "$add_mtavares" == "true" ]]; then
        read -p "Enter password hash for mtavares: " mtavares_password_hash
        mtavares_password_hash=$(validate_input "$mtavares_password_hash")
        credentials_block+=",
        {
            username: \"mtavares\",
            password: \"$mtavares_password_hash\",
            permissions: \"*\"
        }"
    fi

    credentials_block+="]
},"

    echo -e "$credentials_block" > "$tmp_file"

    # Insert the new credentials block after the module.exports line
    /usr/bin/sudo /usr/bin/sed -i "/module.exports/r $tmp_file" "$settings_file"

    # Remove the temporary file
    rm "$tmp_file"

    log "Credentials configured successfully."
}

main() {
    local username="rootlab"
    local settings_file="/home/rootlab/.node-red/settings.js"
    local add_mtavares="false"
    local bypass_confirm="false"

    while getopts "rym" opt; do
        case $opt in
            r)
                ;;
            y)
                bypass_confirm="true"
                ;;
            m)
                add_mtavares="true"
                ;;
            *)
                echo "Invalid option: -$OPTARG" >&2
                exit 1
                ;;
        esac
    done

    if [[ ! "$*" =~ "-r" ]]; then
        read -p "Enter username for Node-RED: " username
        settings_file="/home/$username/.node-red/settings.js"
    fi

    # Check if the settings file exists
    if [[ ! -f "$settings_file" ]]; then
        echo "Settings file not found: $settings_file" >&2
        exit 1
    fi

    stop_nodered
    configure_credentials "$username" "$settings_file" "$add_mtavares" "$bypass_confirm"
    start_nodered
}

main "$@"
