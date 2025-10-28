apt-get update && apt-get install firewalld -y
systemctl enable --now firewalld

firewall-cmd --permanent --add-masquerade
firewall-cmd --permanent --zone=trusted --add-interface=enp7s2
firewall-cmd --permanent --zone=trusted --add-interface=enp7s3

sudo sed -i 's/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/' /etc/net/sysctl.conf

sysctl -p
sysctl net.ipv4.ip_forward
