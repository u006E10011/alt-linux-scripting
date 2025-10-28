#!/bin/bash

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Function to check and install packages
check_and_install_packages() {
    echo "Checking for required packages..."
    
    local packages=("sudo" "openssh-server")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo "Installing missing packages: ${missing_packages[*]}"
        apt-get update
        apt-get install -y "${missing_packages[@]}"
        if [ $? -ne 0 ]; then
            echo "Error installing packages"
            exit 1
        fi
    else
        echo "All required packages are already installed"
    fi
}

# Function to create user
create_user() {
    echo "=== Creating SSH user ==="
    
    # Ask for username
    while true; do
        read -p "1. Enter username: " username
        if [ -z "$username" ]; then
            echo "Username cannot be empty!"
        elif id "$username" &>/dev/null; then
            echo "User '$username' already exists!"
        else
            break
        fi
    done
    
    # Ask for password
    read -p "2. Enter password (default: P@ssw0rd): " password
    if [ -z "$password" ]; then
        password="P@ssw0rd"
        echo "Using default password: P@ssw0rd"
    fi
    
    # Ask for UID
    read -p "3. Enter UID (press Enter for automatic): " uid_input
    
    # Create user
    echo "Creating user $username..."
    
    if [ -z "$uid_input" ]; then
        useradd -m -G wheel "$username"
    else
        useradd -m -G wheel -u "$uid_input" "$username"
    fi
    
    if [ $? -ne 0 ]; then
        echo "Error creating user"
        exit 1
    fi
    
    # Set password
    echo "$username:$password" | chpasswd
    if [ $? -ne 0 ]; then
        echo "Error setting password"
        exit 1
    fi
    
    echo "User $username created successfully"
}

# Function to configure sudo
configure_sudo() {
    echo "=== Configuring sudo ==="
    
    # Check if rule already exists for this user
    if ! grep -q "^$username.*NOPASSWD:ALL" /etc/sudoers; then
        # Add rule to sudoers
        echo "$username ALL=(ALL:ALL) NOPASSWD:ALL" >> /etc/sudoers
        if [ $? -eq 0 ]; then
            echo "Sudo rights configured for user $username"
        else
            echo "Error configuring sudo"
            exit 1
        fi
    else
        echo "Sudo rights for user $username already configured"
    fi
}

# Function to configure SSH
configure_ssh() {
    echo "=== Configuring SSH server ==="
    
    local sshd_config="/etc/ssh/sshd_config"
    local backup_file="${sshd_config}.backup.$(date +%Y%m%d_%H%M%S)"
    
    # Create backup
    cp "$sshd_config" "$backup_file"
    echo "Backup created: $backup_file"
    
    # Update or add settings
    echo "Updating SSH configuration..."
    
    # Function to update or add parameter
    update_config() {
        local param="$1"
        local value="$2"
        local file="$3"
        
        if grep -q "^$param" "$file"; then
            # Parameter exists - update
            sed -i "s|^$param.*|$param $value|" "$file"
        else
            # Parameter doesn't exist - add
            echo "$param $value" >> "$file"
        fi
    }
    
    # Update configuration
    update_config "Port" "2026" "$sshd_config"
    update_config "AllowUsers" "$username" "$sshd_config"
    update_config "PermitRootLogin" "no" "$sshd_config"
    update_config "MaxAuthTries" "2" "$sshd_config"
    
    # Check and add Subsystem sftp if needed
    if ! grep -q "^Subsystem sftp" "$sshd_config"; then
        echo "Subsystem sftp /usr/lib/ssh/sftp-server" >> "$sshd_config"
    fi
    
    # Check and add AcceptEnv if needed
    if ! grep -q "^AcceptEnv LANG LANGUAGE" "$sshd_config"; then
        cat >> "$sshd_config" << 'EOF'

AcceptEnv LANG LANGUAGE LC_ADDRESS LC_ALL LC_COLLATE LC_CTYPE
AcceptEnv LC_IDENTIFICATION LC_MEASUREMENT LC_MESSAGES LC_MONETARY
AcceptEnv LC_NAME LC_NUMERIC LC_PAPER LC_TELEPHONE LC_TIME
EOF
    fi
    
    echo "SSH configuration updated successfully"
}

# Function to restart SSH service
restart_ssh_service() {
    echo "=== Restarting SSH service ==="
    
    if systemctl is-active sshd &>/dev/null; then
        systemctl restart sshd
        if [ $? -eq 0 ]; then
            echo "SSH service restarted successfully"
            echo "SSH server now listening on port 2026"
        else
            echo "Error restarting SSH service"
            exit 1
        fi
    else
        systemctl start sshd
        systemctl enable sshd
        if [ $? -eq 0 ]; then
            echo "SSH service started successfully"
            echo "SSH server now listening on port 2026"
        else
            echo "Error starting SSH service"
            exit 1
        fi
    fi
}

# Main function
main() {
    echo "SSH user setup script for Alt Linux 10.4"
    echo "========================================="
    
    # Check and install packages
    check_and_install_packages
    
    # Create user
    create_user
    
    # Configure sudo
    configure_sudo
    
    # Configure SSH
    configure_ssh
    
    # Restart SSH service
    restart_ssh_service
    
    echo ""
    echo "=== Setup completed successfully! ==="
    echo "User: $username"
    echo "SSH Port: 2026"
    echo "Connect: ssh -p 2026 $username@$(hostname -I | awk '{print $1}')"
    echo "================================"
}

# Run main function
main
