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
    enp7s2_default="172.16.1.1/28"
    enp7s3_default="172.16.2.1/28"

    read -p "set enp7s2 address [$enp7s2_default]: " enp7s2
    enp7s2=${enp7s2:-$enp7s2_default}
    read -p "set enp7s3 address [$enp7s3_default]: " enp7s3
    enp7s3=${enp7s3:-$enp7s3_default}

    mkdir /etc/net/ifaces/enp7s2 /etc/net/ifaces/enp7s3
    echo "$enp7s2" > /etc/net/ifaces/enp7s2/ipv4address
    echo "$enp7s3" > /etc/net/ifaces/enp7s3/ipv4address

    options='BOOTPROTO=static
    TYPE=eth
    DISABLED=no
    SYSTEMD_BOOTPROTO=static
    CONFIG_IPV4=yes'

    echo "$options" > /etc/net/ifaces/enp7s2/options
    echo "$options" > /etc/net/ifaces/enp7s3/options

    systemctl restart network && ip -c a
}

init
setup_firewalld
setup_interface
