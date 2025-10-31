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
    vlan100_default="192.168.100.1/27"
    vlan200_default="192.168.200.1/28"

    if [[ "$auto" == "false" ]]; then
        read -p "set vlan100 address [$vlan100_default]: " vlan100
        vlan100=${vlan100:-$vlan100_default}
        read -p "set vlan200 address [$vlan200_default]: " vlan200
        vlan200=${vlan200:-$vlan200_default}
    else
        vlan100="$vlan100_default"
        vlan200="$vlan200_default"
    fi

    mkdir /etc/net/ifaces/enp7s2 /etc/net/ifaces/vlan100 /etc/net/ifaces/vlan200
    echo "$vlan100" > /etc/net/ifaces/vlan100/ipv4address
    echo "$vlan200" > /etc/net/ifaces/vlan200/ipv4address

    options_vlan='BOOTPROTO=static
    TYPE=vlan
    HOST=enp7s2'

    options_eth='BOOTPROTO=static
    TYPE=eth'

    echo "$options_vlan" > /etc/net/ifaces/vlan100/options
    echo "VID=100" >> /etc/net/ifaces/vlan100/options
    echo "$options_vlan" > /etc/net/ifaces/vlan200/options
    echo "VID=200" >> /etc/net/ifaces/vlan200/options
    echo "$options_eth" > /etc/net/ifaces/enp7s2/options
}

setup_gre(){
        gre_default="10.10.10.1/30 peer 10.10.10.2/30"
        local_default="172.16.1.2"
        remote_default="172.16.2.2"
        
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

    echo "TUNLOCAL=$_local" >> /etc/net/ifaces/gre1/options
    echo "TUNREMOTE=$_remote" >> /etc/net/ifaces/gre1/options
    echo "$options" >> /etc/net/ifaces/gre1/options
}

setup_ospf()
{
    curl -O "https://raw.githubusercontent.com/u006E10011/alt-linux-scripting/main/ospf.sh"
    chmod +x ospf.sh
    bash ospf.sh --hostname "hq-rtr"
}

setup_dhcp()
{
    curl -O "https://raw.githubusercontent.com/u006E10011/alt-linux-scripting/main/dhcpd.sh"
    chmod +x dhcpd.sh
    bash dhcpd.sh
}

setup_all_network(){
    setup_interface
    setup_gre
    systemctl restart network && ip -c a
}

dispose()
{
    rm -rf ospf.sh
    rm -rf dhcpd.sh
    rm -rf hq-rtr.sh
    history -c
}

init
setup_firewalld
setup_all_network
setup_ospf
setup_dhcp
dispose
