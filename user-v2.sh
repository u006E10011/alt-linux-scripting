#!/bin/bash

# Check root privileges
if [ "$EUID" -ne 0 ]; then
    echo "This script must be run as root"
    exit 1
fi

# Default port
DEFAULT_SSH_PORT="2026"
ssh_port="$DEFAULT_SSH_PORT"

# Banner settings
banner_enabled=false
banner_text="Authorized access only"
banner_file="/etc/openssh/banner"

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

# Function to get SSH port from user
get_ssh_port() {
    echo "=== SSH Port Configuration ==="
    
    while true; do
        read -p "Enter SSH port (default: $DEFAULT_SSH_PORT): " port_input
        
        if [ -z "$port_input" ]; then
            ssh_port="$DEFAULT_SSH_PORT"
            echo "Using default port: $ssh_port"
            break
        elif [[ ! "$port_input" =~ ^[0-9]+$ ]]; then
            echo "Port must be a number!"
        elif [ "$port_input" -lt 1 ] || [ "$port_input" -gt 65535 ]; then
            echo "Port must be between 1 and 65535!"
        elif [ "$port_input" -eq 22 ]; then
            echo "Warning: Using default SSH port (22). This is less secure."
            read -p "Are you sure you want to use port 22? (y/N): " confirm
            if [[ "$confirm" =~ ^[Yy]$ ]]; then
                ssh_port="$port_input"
                break
            fi
        else
            ssh_port="$port_input"
            break
        fi
    done
    
    echo "SSH port set to: $ssh_port"
}

# Function to configure banner
configure_banner() {
    echo "=== SSH Banner Configuration ==="
    
    read -p "Enable SSH banner? (y/N): " enable_banner
    if [[ "$enable_banner" =~ ^[Yy]$ ]]; then
        banner_enabled=true
        
        read -p "Enter banner text (default: '$banner_text'): " custom_banner
        if [ -n "$custom_banner" ]; then
            banner_text="$custom_banner"
        fi
        
        # Create banner file
        echo "Creating banner file at $banner_file..."
        echo "$banner_text" > "$banner_file"
        
        if [ $? -eq 0 ]; then
            echo "Banner file created successfully"
            chmod 644 "$banner_file"
        else
            echo "Error creating banner file"
            exit 1
        fi
    else
        echo "Banner disabled"
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
    
    local sshd_config="/etc/openssh/sshd_config"
    
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
    update_config "Port" "$ssh_port" "$sshd_config"
    update_config "AllowUsers" "$username" "$sshd_config"
    update_config "PermitRootLogin" "no" "$sshd_config"
    update_config "MaxAuthTries" "2" "$sshd_config"
    
    # Configure banner if enabled
    if [ "$banner_enabled" = true ]; then
        update_config "Banner" "$banner_file" "$sshd_config"
        echo "SSH banner enabled: $banner_file"
    else
        # Remove banner configuration if exists
        if grep -q "^Banner" "$sshd_config"; then
            sed -i '/^Banner/d' "$sshd_config"
        fi
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
            echo "SSH server now listening on port $ssh_port"
            if [ "$banner_enabled" = true ]; then
                echo "SSH banner enabled: $banner_file"
            fi
        else
            echo "Error restarting SSH service"
            exit 1
        fi
    else
        systemctl start sshd
        systemctl enable sshd
        if [ $? -eq 0 ]; then
            echo "SSH service started successfully"
            echo "SSH server now listening on port $ssh_port"
            if [ "$banner_enabled" = true ]; then
                echo "SSH banner enabled: $banner_file"
            fi
        else
            echo "Error starting SSH service"
            exit 1
        fi
    fi
}

# Function to check if port is available
check_port_availability() {
    if command -v netstat >/dev/null 2>&1; then
        if netstat -tuln | grep -q ":$ssh_port "; then
            echo "Warning: Port $ssh_port is already in use by another service!"
            read -p "Do you want to continue anyway? (y/N): " confirm
            if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
                echo "Please choose a different port and run the script again."
                exit 1
            fi
        fi
    fi
}

# Main function
main() {
    echo "SSH user setup script for Alt Linux 10.4"
    echo "========================================="
    
    check_and_install_packages
    get_ssh_port
    check_port_availability
    create_user
    configure_banner
    configure_sudo
    configure_ssh
    restart_ssh_service
    
    echo ""
    echo "=== Setup completed successfully! ==="
    echo "User: $username"
    echo "SSH Port: $ssh_port"
    if [ "$banner_enabled" = true ]; then
        echo "SSH Banner: Enabled ($banner_file)"
    else
        echo "SSH Banner: Disabled"
    fi
    echo "Connect: ssh -p $ssh_port $username@$(hostname -I | awk '{print $1}')"
    echo "================================"
    history -c
}

# Run main function
main
