init(){
    apt-get update && apt-get install firewalld sed -y
    systemctl enable --now firewalld
}

setup_firewalld(){
    firewall-cmd --permanent --add-masquerade
    firewall-cmd --permanent --zone=trusted --add-interface=enp7s2
    firewall-cmd --permanent --zone=trusted --add-interface=enp7s3

    sudo sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf
    sysctl net.ipv4.ip_forward
}

setup_interface(){
    read -p "set enp7s2 address" enp7s2
    read -p "set enp7s3 address" enp7s3

    mkdir /etc/net/iface/enp7s2 /etc/net/iface/enp7s3
    echo "$enp7s2" > /etc/net/iface/enp7s2/ipv4address
    echo "$enp7s3" > /etc/net/iface/enp7s3/ipv4address

    options='BOOTPROTO=static
    TYPE=eth
    DISABLED=no
    SYSTEMD_BOOTPROTO=static
    CONFIG_IPV4=yes'

    echo "$options" > /etc/net/iface/enp7s2/options
    echo "$options" > /etc/net/iface/enp7s3/options

    systemctl restart network && ip -c a
}

init
setup_firewalld
setup_interface
