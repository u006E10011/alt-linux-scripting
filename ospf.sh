#!/bin/bash

HOSTNAME=""

while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--hostname)
            HOSTNAME="$2"
            shift 2
            ;;
        *)
            echo "Unknown option: $1"
            exit 1
            ;;
    esac
done

init()
{
    local packages=("frr" "sed")
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

setup_config()
{
    if [ -z "$HOSTNAME" ]; then
        read -p "Enter hostname (hq or br): " HOSTNAME
    fi

    case $HOSTNAME in
        *hq*)
            vtysh -c "configure terminal" \
              -c "router ospf" \
              -c "passive-interface default" \
              -c "network 10.10.10.0/30 area 0" \
              -c "network 192.168.100.0/27 area 0" \
              -c "network 192.168.200.0/28 area 0" \
              -c "exit" \
              -c "interface enp7s2.100" \
              -c "no ip ospf passive" \
              -c "interface gre1" \
              -c "no ip ospf passive" \
              -c "ip ospf authentication" \
              -c "ip ospf authentication-key P@ssw0rd" \
              -c "end" \
              -c "write"
            ;;
        *br*)
             vtysh -c "configure terminal" \
              -c "router ospf" \
              -c "passive-interface default" \
              -c "network 10.10.10.0/30 area 0" \
              -c "network 172.20.10.0/28 area 0" \
              -c "exit" \
              -c "interface gre1" \
              -c "no ip ospf passive" \
              -c "ip ospf authentication" \
              -c "ip ospf authentication-key P@ssw0rd" \
              -c "interface enp7s2" \
              -c "no ip ospf passive" \
              -c "end" \
              -c "write"
            ;;
        *)
            echo "Unknown hostname: $HOSTNAME"
            return 1
            ;;
    esac

    log "OSPF configuration completed for $machine_type"

    sed -i 's/ospfd=no/ospfd=yes/' /etc/frr/daemons
    echo "FRR configured for host: $HOSTNAME"
    systemctl restart network firewalld frr && systemctl status frr --no-pager
}

main()
{
    init
    setup_config
    history -c
}

main "$@"
