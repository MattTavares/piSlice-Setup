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

configure_credentials() {
    local username="$1"
    local settings_file="$2"
    local add_mtavares="$3"
    local bypass_confirm="$4"

    confirm_proceed "$bypass_confirm"

    read -p "Enter password hash for $username: " password_hash

    # Remove any existing uncommented adminAuth block
    sudo sed -i '/adminAuth/,/}/{//!d}' "$settings_file"
    sudo sed -i '/adminAuth/d' "$settings_file"

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
        credentials_block+=",
        {
            username: \"mtavares\",
            password: \"$mtavares_password_hash\",
            permissions: \"*\"
        }"
    fi

    credentials_block+="]
},"

    echo -e "$credentials_block" > credentials_tmp_block

    # Insert the new credentials block after the module.exports line
    sudo sed -i "/module.exports/r credentials_tmp_block" "$settings_file"

    rm credentials_tmp_block

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

    if [[ ! "$*" =~ "-r" && ! "$*" =~ "--rootlab" ]]; then
        read -p "Enter username for Node-RED: " username
        settings_file="/home/$username/.node-red/settings.js"
    fi

    stop_nodered
    configure_credentials "$username" "$settings_file" "$add_mtavares" "$bypass_confirm"
    start_nodered
}

main "$@"
