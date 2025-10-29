#!/bin/bash

auto="true"

init(){
    read -p "is auto [true]: " input
    auto=${input:-true}
    
    local packages=("firewalld" "sed")
    local missing_packages=()
    
    for package in "${packages[@]}"; do
        if ! rpm -q "$package" &>/dev/null; then
            missing_packages+=("$package")
        fi
    done
    
    if [ ${#missing_packages[@]} -ne 0 ]; then
        echo "Installing missing packages: ${missing_packages[*]}"
        apt-get install -y "${missing_packages[@]}"
        if [ $? -ne 0 ]; then
            echo "Error installing packages"
            exit 1
        fi
    else
        echo "All required packages are already installed"
    fi
}

setup_firewalld(){
    systemctl enable --now firewalld
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --permanent --add-protocol=ospf
    firewall-cmd --permanent --add-service=dns
    firewall-cmd --permanent --add-port=53/tcp
    firewall-cmd --permanent --add-port=53/udp
    firewall-cmd --permanent --add-port=8080/tcp
    firewall-cmd --permanent --add-port=8080/udp
    firewall-cmd --permanent --add-port=2026/tcp
    firewall-cmd --permanent --add-port=2026/udp
    firewall-cmd --reload

    sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
    sysctl net.ipv4.ip_forward
}

setup_interface(){
    enp7s2_default="172.20.10.1/28"

    if [[ "$auto" == "false" ]]; then
        read -p "set enp7s2 address [$enp7s2_default]: " enp7s2
        enp7s2=${enp7s2:-$enp7s2_default}
    else
        enp7s2="$enp7s2_default"
    fi

    mkdir /etc/net/ifaces/enp7s2
    echo "$enp7s2" > /etc/net/ifaces/enp7s2/ipv4address

    options='BOOTPROTO=static
    TYPE=eth
    DISABLED=no
    SYSTEMD_BOOTPROTO=static
    CONFIG_IPV4=yes'

    echo "$options" > /etc/net/ifaces/enp7s2/options
    setup_gre

    systemctl restart network && ip -c a
}

setup_gre(){
        gre_default="10.10.10.2/30 peer 10.10.10.1/30"
        local_default="172.16.2.2"
        remote_default="172.16.1.2"
        
    if [[ "$auto" == "false" ]]; then
        read -p "set gre address [$gre_default]: " gre
        gre=${gre:-$gre_default}

        read -p "set local address [$local_default]: " _local
        _local=${_local:-$local_default}

        read -p "set remote address [$remote_default]: " _remote
        _remote=${_remote:-$remote_default}
    else
        gre="$gre_default"
        _local="$local_default"
        _remote="$remote_default"
    fi

    mkdir /etc/net/ifaces/gre1
    echo "$gre" > /etc/net/ifaces/gre1/ipv4address

    options='TUNTYPE=gre
    TYPE=iptun
    TUNTTL=64
    TUNOPTIONS='\''ttl 64'\''
    TUNMTU=1476
    DISABLE=no'

    echo "$_local" >> /etc/net/ifaces/gre1/options
    echo "$_remote" >> /etc/net/ifaces/gre1/options
    echo "$options" >> /etc/net/ifaces/gre1/options
}

init
setup_firewalld
setup_interface
