apt-get update && apt-get install firewalld bash-completion

exec bash
systemctl enable --now firewalld

firewall-cmd --permanent --add-masquerade
firewall-cmd --permanent --zone=trusted --add-interface=enp7s2
firewall-cmd --permanent --zone=trusted --add-interface=enp7s3

firewall-cmd --reload
firewall-cmd --list-all

#forwarding
vim /etc/net/sysctl.conf
:%s/net.ipv4.ip_forward = 0/net.ipv4.ip_forward = 1/g
:wq!

sysctl -p
sysctl net.ipv4.ip_forward

