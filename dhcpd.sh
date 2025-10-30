#!/bin/bash

DHCPDARGS="vlan100"
hardware_ethernet="bc:24:11:e6:8e:e6"
domen="au-team.irpo"

init()
{
    apt-get install dhcpd sed -y
    systemctl enable --now dhcpd
}

input()
{
    read -p "domen [$domen]: " _domen
    domen=${_domen:-$domen}

    read -p "hardware ethernet [$hardware_ethernet]: " _hardware_ethernet
    hardware_ethernet=${_hardware_ethernet:-$hardware_ethernet}

    read -p "DHCPDARGS [$DHCPDARGS]: " _DHCPDARGS
    DHCPDARGS=${_DHCPDARGS:-$DHCPDARGS}
}

setup_dhcp()
{
    echo "DHCPDARGS=$DHCPDARGS" > /etc/sysconfig/dhcpd

    cat >> /etc/dhcp/dhcpd.conf << EOF 
subnet 192.168.200.0 netmask 255.255.255.240 {
    option routers 192.168.200.1;
    option subnet-mask 255.255.255.240;

    option nis-domain "$domen";
    option domain-name "$domen";
    option domain-name-servers 192.168.100.2;

    range dynamic-bootp 192.168.200.3 192.168.200.12;
    default-lease-time 21600;
    max-lease-time 43200;
}

host hq-cli {
    fixed-address 192.168.200.2;
    hardware ethernet $hardware_ethernet;
}
EOF
}

main()
{
    init
    input
    setup_dhcp
    
    systemctl restart dhcpd && systemctl status dhcpd
    echo "DHCPDARGS=$DHCPDARGS"
    echo "hardware_ethernet=$hardware_ethernet"
    echo "domen=$domen"
}

main
