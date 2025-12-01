samba-tool dns add 127.0.0.1 au.team r-dt A 192.168.33.89
samba-tool dns add 127.0.0.1 au.team fw-dt A 192.168.33.90
samba-tool dns add 127.0.0.1 au.team fw-dt A 192.168.33.1
samba-tool dns add 127.0.0.1 au.team fw-dt A 192.168.33.65
samba-tool dns add 127.0.0.1 au.team fw-dt A 192.168.33.81
samba-tool dns add 127.0.0.1 au.team admin-dt A 192.168.33.82
samba-tool dns add 127.0.0.1 au.team srv1-dt A 192.168.33.66
samba-tool dns add 127.0.0.1 au.team srv2-dt A 192.168.33.67
samba-tool dns add 127.0.0.1 au.team srv3-dt A 192.168.33.68
samba-tool dns add 127.0.0.1 au.team cli-dt A 192.168.33.2

samba-tool dns add 127.0.0.1 au.team r-hq A 192.168.11.1
samba-tool dns add 127.0.0.1 au.team r-hq A 192.168.11.65
samba-tool dns add 127.0.0.1 au.team r-hq A 192.168.11.81
samba-tool dns add 127.0.0.1 au.team sw1-hq A 192.168.11.82
samba-tool dns add 127.0.0.1 au.team sw2-hq A 192.168.11.83
samba-tool dns add 127.0.0.1 au.team sw3-hq A 192.168.11.84
samba-tool dns add 127.0.0.1 au.team admin-hq A 192.168.11.85
samba-tool dns add 127.0.0.1 au.team cli-hq A 192.168.11.2

samba-tool dns query 127.0.0.1 au.team @ A
samba-tool dns zonecreate 127.0.0.1 11.168.192.in-addr.arpa
samba-tool dns zonecreate 127.0.0.1 33.168.192.in-addr.arpa
samba-tool dns zonelist 127.0.0.1

samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 89 PTR r-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 90 PTR fw-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 1 PTR fw-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 65 PTR fw-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 81 PTR fw-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 82 PTR admin-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 66 PTR srv1-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 67 PTR srv2-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 68 PTR srv3-dt.au.team
samba-tool dns add 127.0.0.1 33.168.192.in-addr.arpa 2 PTR cli-dt.au.team

samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 1 PTR r-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 65 PTR r-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 66 PTR srv1-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 81 PTR r-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 82 PTR sw1-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 83 PTR sw2-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 84 PTR sw3-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 85 PTR admin-hq.au.team
samba-tool dns add 127.0.0.1 11.168.192.in-addr.arpa 2 PTR cli-hq.au.team

samba-tool dns add 127.0.0.1 au.team www CNAME srv1-dt.au.team -U administrator
samba-tool dns add 127.0.0.1 au.team zabbix CNAME srv1-dt.au.team -U administrator