#!/bin/bash

# Script for configuring users and SSH on ALT Linux 10.4
# Check if script is running with root privileges
if [[ $EUID -ne 0 ]]; then
   echo "This script must be run as root" 
   exit 1
fi

# Function to install SSH
install_ssh() {
    if ! command -v sshd &> /dev/null && ! command -v ssh &> /dev/null; then
        echo "SSH is not installed. Installing..."
        apt-get update
        apt-get install -y openssh-server
        if [[ $? -ne 0 ]]; then
            echo "Error installing SSH"
            return 1
        fi
        
        # Enable and start SSH service
        if systemctl enable sshd 2>/dev/null; then
            systemctl start sshd
        elif systemctl enable ssh 2>/dev/null; then
            systemctl start ssh
        fi
        echo "SSH installed and service started"
    else
        echo "SSH is already installed"
    fi
    return 0
}

# Function to install sudo
install_sudo() {
    if ! command -v sudo &> /dev/null; then
        echo "Installing sudo..."
        apt-get update
        apt-get install -y sudo
        if [[ $? -ne 0 ]]; then
            echo "Error installing sudo"
            return 1
        fi
    fi
    
    # Check if sudoers.d directory exists
    if [[ ! -d /etc/sudoers.d ]]; then
        mkdir -p /etc/sudoers.d
    fi
    return 0
}

# Function to detect device type
detect_device_type() {
    # Check hostname to determine device type
    local hostname=$(hostname | tr '[:upper:]' '[:lower:]')
    
    case $hostname in
        *srv*)
            echo "server"
            ;;
        *rtr*)
            echo "router"
            ;;
        *)
            echo "unknown"
            ;;
    esac
}

# Function to create sshuser (for servers)
setup_sshuser() {
    echo "Configuring sshuser..."
    
    # Create user with specified UID and add to wheel group
    useradd -m -u 2026 -s /bin/bash -G wheel sshuser
    if [[ $? -eq 0 ]]; then
        echo "User sshuser created and added to wheel group"
    else
        # If wheel group doesn't exist, create it
        groupadd wheel
        useradd -m -u 2026 -s /bin/bash -G wheel sshuser
        if [[ $? -eq 0 ]]; then
            echo "User sshuser created and added to wheel group"
        else
            echo "Error creating sshuser"
            return 1
        fi
    fi
    
    # Set password
    echo "sshuser:P@ssw0rd" | chpasswd
    if [[ $? -eq 0 ]]; then
        echo "Password for sshuser set"
    else
        echo "Error setting password for sshuser"
        return 1
    fi
    
    # Install sudo if needed
    install_sudo
    
    # Also create separate file for reliability
    echo "sshuser ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/sshuser
    chmod 440 /etc/sudoers.d/sshuser
    
    echo "Sudo settings for sshuser applied"
}

# Function to create net_admin user (for routers)
setup_net_admin() {
    echo "Configuring net_admin user..."
    
    # Create user and add to wheel group
    useradd -m -s /bin/bash -G wheel net_admin
    echo "net_admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin
    chmod 440 /etc/sudoers.d/sshuser
    
    # Set password
    echo "net_admin:P@ssw0rd" | chpasswd
    if [[ $? -eq 0 ]]; then
        echo "Password for net_admin set"
    else
        echo "Error setting password for net_admin"
        return 1
    fi
    
    # Install sudo if needed
    install_sudo
    
    # Configure passwordless sudo for wheel group
    if ! grep -q "^%wheel" /etc/sudoers; then
        echo "%wheel ALL=(ALL) NOPASSWD: ALL" >> /etc/sudoers
    fi
    
    # Also create separate file for reliability
    echo "net_admin ALL=(ALL) NOPASSWD: ALL" > /etc/sudoers.d/net_admin
    chmod 440 /etc/sudoers.d/net_admin
    
    echo "Sudo settings for net_admin applied"
}

# Function to configure SSH for servers
setup_ssh_server() {
    echo "Configuring SSH for server..."
    
    # Install SSH if not present
    install_ssh
    
    # Create backup of original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
    
    # Configure SSH with banner
    cat > /etc/ssh/sshd_config << 'EOF'
# Basic settings
Port 2026
Protocol 2
PermitRootLogin no
MaxAuthTries 2
ClientAliveInterval 300
ClientAliveCountMax 2

# Authentication
PubkeyAuthentication yes
AuthorizedKeysFile .ssh/authorized_keys
PasswordAuthentication yes
PermitEmptyPasswords no

# Security
AllowUsers sshuser
Banner /etc/ssh/banner
EOF

    # Create banner only for servers
    mkdir -p /etc/ssh
    echo "Authorized access only" > /etc/ssh/banner
    chmod 644 /etc/ssh/banner
    echo "Banner 'Authorized access only' set"
    
    # Restart SSH service
    if systemctl restart sshd 2>/dev/null; then
        echo "SSH service restarted (sshd)"
    elif systemctl restart ssh 2>/dev/null; then
        echo "SSH service restarted (ssh)"
    else
        echo "Warning: Could not restart SSH service automatically"
        echo "Please restart SSH service manually"
    fi
    
    echo "SSH configuration for server completed"
}

# Function to configure SSH for routers (without banner)
setup_ssh_router() {
    echo "Configuring SSH for router..."
    
    # Install SSH if not present
    install_ssh
    
    # Create backup of original config
    cp /etc/ssh/sshd_config /etc/ssh/sshd_config.backup 2>/dev/null || true
    
    # Configure SSH without banner
    cat > /etc/ssh/sshd_config << 'EOF'
# Basic settings
Port 22
AllowUsers net_admin
PermitRootLogin no
MaxAuthTries 2

Subsystem sftp /usr/lib/openssh/sftp-server

AcceptEnv LANG LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE
AcceptEnv LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES LC_MONETARY
AcceptEnv LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TiME
EOF

    # Remove banner if it exists
    if [[ -f /etc/ssh/banner ]]; then
        rm -f /etc/ssh/banner
        echo "Banner removed"
    fi
    
    # Restart SSH service
    if systemctl restart sshd 2>/dev/null; then
        echo "SSH service restarted (sshd)"
    elif systemctl restart ssh 2>/dev/null; then
        echo "SSH service restarted (ssh)"
    else
        echo "Warning: Could not restart SSH service automatically"
        echo "Please restart SSH service manually"
    fi
    
    echo "SSH configuration for router completed"
}

# Main script logic
main() {
    echo "Detecting device type..."
    local device_type=$(detect_device_type)
    
    case $device_type in
        "server")
            echo "Server detected. Configuring sshuser and SSH..."
            setup_sshuser
            setup_ssh_server
            ;;
        "router")
            echo "Router detected. Configuring net_admin..."
            setup_net_admin
            setup_ssh_router
            ;;
        "unknown")
            echo "Device type not determined. Asking user..."
            read -p "Enter device type (server/router): " user_input
            case $(echo "$user_input" | tr '[:upper:]' '[:lower:]') in
                "server")
                    setup_sshuser
                    setup_ssh_server
                    ;;
                "router")
                    setup_net_admin
                    setup_ssh_router
                    ;;
                *)
                    echo "Invalid device type. Use 'server' or 'router'"
                    exit 1
                    ;;
            esac
            ;;
    esac
    
    echo "Configuration completed!"
    
    # Display configuration summary
    echo ""
    echo "=== CONFIGURATION SUMMARY ==="
    if [[ $device_type == "server" ]] || [[ $(echo "$user_input" | tr '[:upper:]' '[:lower:]') == "server" ]]; then
        echo "Server configured:"
        echo "- User: sshuser (UID: 2026)"
        echo "- Group: wheel"
        echo "- Password: P@ssw0rd"
        echo "- SSH port: 2026"
        echo "- Sudo without password: enabled"
        echo "- Root login: disabled"
        echo "- Banner: 'Authorized access only'"
    elif [[ $device_type == "router" ]] || [[ $(echo "$user_input" | tr '[:upper:]' '[:lower:]') == "router" ]]; then
        echo "Router configured:"
        echo "- User: net_admin"
        echo "- Group: wheel"
        echo "- Password: P@ssw0rd" 
        echo "- SSH port: 22 (standard)"
        echo "- Sudo without password: enabled"
        echo "- Banner: none"
    fi
    echo "============================="
}

# Run main function
main
