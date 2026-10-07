# Networking Fundamentals: Homework (Session 4)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

**Task 1:** practise the commands and repos shared in the devops-hero GitHub repo.
**Task 2:** create a Markdown file, run the networking commands, add the output, and explain what I understood about each command.

> Every command below was actually executed on Ubuntu 22.04 LTS and the output pasted verbatim.

---

## Contents

| # | Command | What it answers |
|---|---|---|
| 1 | `ip a` / `ifconfig` | What is my IP address? |
| 2 | `ip route` / `route -n` | Where do my packets go? |
| 3 | `ping` | Is the host alive? |
| 4 | `traceroute` | Which path do packets take? |
| 5 | `nslookup` / `dig` / `host` | What IP does this name resolve to? |
| 6 | `ss` / `netstat` | What is listening on this machine? |
| 7 | `curl` | Does the web service answer? |
| 8 | `nc` / `telnet` | Is that TCP port open? |
| 9 | `hostname`, `/etc/hosts`, `/etc/resolv.conf` | Who am I and who resolves my names? |
| 10 | `arp` / `ip neigh` | Which MAC belongs to which IP? |
| 11 | `whois` | Who owns this domain? |
| 12 | `tcpdump` | What is actually on the wire? |
| 13 | `/dev/tcp` | Port check with no tools installed |

Test machine:

```console
$ cat /etc/os-release | head -2
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
```

---

## 1. `ip a` / `ifconfig`: interfaces and IP addresses

**What it does:** lists every network interface and the IP addresses bound to them. `ip` (from `iproute2`) is the modern tool; `ifconfig` (from `net-tools`) is the older one you still meet on legacy boxes.

**What I understood from the output:**
* `lo` is the loopback interface, always `127.0.0.1/8` - traffic to yourself never leaves the machine.
* `eth0` is the real interface with `172.17.0.11/16`. The `/16` is the CIDR prefix: 16 network bits, 16 host bits, so the netmask is `255.255.0.0` and the network is `172.17.0.0` - a Class B private range.
* `link/ether 26:bc:ce:39:4f:d3` is the MAC address (layer 2), while the `inet` line is the IP address (layer 3).
* `<BROADCAST,MULTICAST,UP,LOWER_UP>` - `UP` means administratively enabled, `LOWER_UP` means the cable/link is actually live. If you ever see `UP` without `LOWER_UP`, the link is down.
* `mtu 65535` is the largest frame the interface will send in one piece.
* `ip -brief address show` is the version I actually use day to day - the same information in one line per interface.

### Output

```console
$ ip a
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: tunl0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
3: gre0@NONE: <NOARP> mtu 1476 qdisc noop state DOWN group default qlen 1000
    link/gre 0.0.0.0 brd 0.0.0.0
4: gretap0@NONE: <BROADCAST,MULTICAST> mtu 1462 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
5: erspan0@NONE: <BROADCAST,MULTICAST> mtu 1450 qdisc noop state DOWN group default qlen 1000
    link/ether 00:00:00:00:00:00 brd ff:ff:ff:ff:ff:ff
6: ip_vti0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/ipip 0.0.0.0 brd 0.0.0.0
7: ip6_vti0@NONE: <NOARP> mtu 1428 qdisc noop state DOWN group default qlen 1000
    link/tunnel6 :: brd :: permaddr ea71:bbec:d38f::
8: sit0@NONE: <NOARP> mtu 1480 qdisc noop state DOWN group default qlen 1000
    link/sit 0.0.0.0 brd 0.0.0.0
9: ip6tnl0@NONE: <NOARP> mtu 1452 qdisc noop state DOWN group default qlen 1000
    link/tunnel6 :: brd :: permaddr d2cb:2ebb:5fd1::
10: ip6gre0@NONE: <NOARP> mtu 1448 qdisc noop state DOWN group default qlen 1000
    link/gre6 :: brd :: permaddr ca05:5a3b:8853::
11: eth0@if3325: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 65535 qdisc noqueue state UP group default 
    link/ether 26:bc:ce:39:4f:d3 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.17.0.11/16 brd 172.17.255.255 scope global eth0
       valid_lft forever preferred_lft forever

$ ifconfig
eth0: flags=4163<UP,BROADCAST,RUNNING,MULTICAST>  mtu 65535
        inet 172.17.0.11  netmask 255.255.0.0  broadcast 172.17.255.255
        ether 26:bc:ce:39:4f:d3  txqueuelen 0  (Ethernet)
        RX packets 2397  bytes 66576791 (66.5 MB)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 907  bytes 71742 (71.7 KB)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0

lo: flags=73<UP,LOOPBACK,RUNNING>  mtu 65536
        inet 127.0.0.1  netmask 255.0.0.0
        inet6 ::1  prefixlen 128  scopeid 0x10<host>
        loop  txqueuelen 1000  (Local Loopback)
        RX packets 0  bytes 0 (0.0 B)
        RX errors 0  dropped 0  overruns 0  frame 0
        TX packets 0  bytes 0 (0.0 B)
        TX errors 0  dropped 0 overruns 0  carrier 0  collisions 0


$ ip -brief address show
lo               UNKNOWN        127.0.0.1/8 ::1/128 
tunl0@NONE       DOWN           
gre0@NONE        DOWN           
gretap0@NONE     DOWN           
erspan0@NONE     DOWN           
ip_vti0@NONE     DOWN           
ip6_vti0@NONE    DOWN           
sit0@NONE        DOWN           
ip6tnl0@NONE     DOWN           
ip6gre0@NONE     DOWN           
eth0@if3325      UP             172.17.0.11/16
```

## 2. `ip route` / `route -n`: the routing table

**What it does:** shows how the kernel decides where to send a packet. Every packet is matched against this table, most-specific route first.

**What I understood from the output:**
* `default via 172.17.0.1 dev eth0` - the default gateway. Anything that doesn't match a more specific route is handed to `172.17.0.1`. If this line is missing you can ping your LAN but not the internet, which is one of the most common "no internet" causes.
* `172.17.0.0/16 dev eth0 proto kernel scope link` - the directly connected network. `scope link` means these hosts are reachable without a router, by ARP.
* `route -n` is the old `net-tools` view of the same table; `0.0.0.0` destination with flag `UG` is the default route (Up, Gateway).
* `ip route get 8.8.8.8` is the debugging gem: instead of you reading the table, the kernel *tells you* exactly which route, interface and source IP it would use for that destination.

### Output

```console
$ ip route
default via 172.17.0.1 dev eth0 
172.17.0.0/16 dev eth0 proto kernel scope link src 172.17.0.11 

$ route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         172.17.0.1      0.0.0.0         UG    0      0        0 eth0
172.17.0.0      0.0.0.0         255.255.0.0     U     0      0        0 eth0

$ ip route get 8.8.8.8
8.8.8.8 via 172.17.0.1 dev eth0 src 172.17.0.11 uid 0 
    cache
```

## 3. `ping`: is the host reachable?

**What it does:** sends ICMP echo request packets and waits for echo replies. The first thing to run when "the server is down".

**What I understood from the output:**
* `0% packet loss` = the path works in both directions. Loss > 0% points at congestion or a flaky link.
* `time=31.9 ms` is the round-trip time (RTT); the summary line `rtt min/avg/max/mdev` gives the spread. A high `mdev` (jitter) is bad for calls and video even when the average looks fine.
* `ttl=63` - packets start at TTL 64 and each router decrements it by one, so `63` means one hop away. TTL also stops routing loops: at 0 the packet is dropped.
* `ping google.com` printing `PING google.com (142.251.106.138)` proves DNS resolved first - so a failing `ping google.com` that works as `ping 8.8.8.8` is a *DNS* problem, not a connectivity problem. That single test is the fastest way to split the two.

### Output

```console
$ ping -c 4 8.8.8.8
PING 8.8.8.8 (8.8.8.8) 56(84) bytes of data.
64 bytes from 8.8.8.8: icmp_seq=1 ttl=63 time=31.9 ms
64 bytes from 8.8.8.8: icmp_seq=2 ttl=63 time=28.9 ms
64 bytes from 8.8.8.8: icmp_seq=3 ttl=63 time=56.8 ms
64 bytes from 8.8.8.8: icmp_seq=4 ttl=63 time=37.6 ms

--- 8.8.8.8 ping statistics ---
4 packets transmitted, 4 received, 0% packet loss, time 3008ms
rtt min/avg/max/mdev = 28.922/38.806/56.847/10.870 ms

$ ping -c 3 google.com
PING google.com (142.251.106.138) 56(84) bytes of data.
64 bytes from cm-in-f138.1e100.net (142.251.106.138): icmp_seq=1 ttl=63 time=33.7 ms
64 bytes from cm-in-f138.1e100.net (142.251.106.138): icmp_seq=2 ttl=63 time=36.3 ms
64 bytes from cm-in-f138.1e100.net (142.251.106.138): icmp_seq=3 ttl=63 time=33.0 ms

--- google.com ping statistics ---
3 packets transmitted, 3 received, 0% packet loss, time 2012ms
rtt min/avg/max/mdev = 32.997/34.340/36.334/1.437 ms
```

## 4. `traceroute`: the path packets take

**What it does:** shows the route to a destination hop by hop, by sending packets with deliberately small TTLs (1, 2, 3...) and recording who sends back the "time exceeded" message.

**What I understood from the output:**
* Hop 1 is `172.17.0.1` - my gateway, sub-millisecond, as expected.
* Hops 2-8 show `* * *`. That does not mean the network is broken (the `ping` above succeeded): it means those routers are configured not to reply to the probes, or a NAT/firewall in between drops them. Reading `* * *` as "the internet is down" is a classic beginner mistake.
* Where traceroute genuinely helps is spotting where latency jumps - if hop 4 is 20 ms and hop 5 is 300 ms, that link is your problem.

### Output

```console
$ traceroute -m 8 8.8.8.8
traceroute to 8.8.8.8 (8.8.8.8), 8 hops max, 60 byte packets
 1  172.17.0.1 (172.17.0.1)  0.704 ms  0.019 ms  0.008 ms
 2  * * *
 3  * * *
 4  * * *
 5  * * *
 6  * * *
 7  * * *
 8  * * *
```

## 5. `nslookup` / `dig` / `host`: DNS resolution

**What it does:** turns names into IP addresses. `dig` is the detailed one, `nslookup` the simple one, `host` the quick one.

**What I understood from the output:**
* `nslookup google.com` shows `Server: 192.168.65.7` - which resolver answered, then the addresses. Multiple A records for one name = DNS-level load balancing.
* `Non-authoritative answer` means this came from a cache, not from Google's own authoritative nameserver.
* `dig google.com +short` gives just the addresses - perfect inside scripts.
* Full `dig` output has the sections that matter for debugging: `QUESTION` (what was asked), `ANSWER` (the records, with the TTL = how long they may be cached), `flags`, and `Query time`.
* `dig -x 8.8.8.8` is a reverse lookup (IP -> name, via the PTR record).
* `dig MX google.com` returns the mail exchangers - the record type matters: `A` (IPv4), `AAAA` (IPv6), `CNAME` (alias), `MX` (mail), `NS` (nameservers), `TXT` (SPF/verification).

### Output

```console
$ nslookup google.com
Server:		192.168.65.7
Address:	192.168.65.7#53

Non-authoritative answer:
Name:	google.com
Address: 142.251.106.138
Name:	google.com
Address: 142.251.106.101
Name:	google.com
Address: 142.251.106.139
Name:	google.com
Address: 142.251.106.113
Name:	google.com
Address: 142.251.106.100
Name:	google.com
Address: 142.251.106.102


$ dig google.com +short
142.251.106.138
142.251.106.101
142.251.106.139
142.251.106.113
142.251.106.100
142.251.106.102

$ dig google.com

; <<>> DiG 9.18.39-0ubuntu0.22.04.6-Ubuntu <<>> google.com
;; global options: +cmd
;; Got answer:
;; ->>HEADER<<- opcode: QUERY, status: NOERROR, id: 56623
;; flags: qr rd ra; QUERY: 1, ANSWER: 6, AUTHORITY: 0, ADDITIONAL: 0

;; QUESTION SECTION:
;google.com.			IN	A

;; ANSWER SECTION:
google.com.		218	IN	A	142.251.106.138
google.com.		218	IN	A	142.251.106.101
google.com.		218	IN	A	142.251.106.139
google.com.		218	IN	A	142.251.106.113
google.com.		218	IN	A	142.251.106.100
google.com.		218	IN	A	142.251.106.102

;; Query time: 2 msec
;; SERVER: 192.168.65.7#53(192.168.65.7) (UDP)
;; WHEN: Thu Sep 03 09:36:52 UTC 2026
;; MSG SIZE  rcvd: 184


$ dig -x 8.8.8.8 +short
dns.google.

$ dig MX google.com +short
10 smtp.google.com.

$ host github.com
github.com has address 20.207.73.82
github.com mail is handled by 0 github-com.mail.protection.outlook.com.
```

## 6. `ss` / `netstat`: sockets and listening ports

**What it does:** lists sockets - what is listening, and what is connected. `ss` is the modern replacement for `netstat` and is much faster on busy machines.

**What I understood from the output:**
* Flag by flag: `-t` TCP, `-u` UDP, `-l` only listening sockets, `-n` numeric (don't resolve names - much faster), `-p` show the owning process.
* `0.0.0.0:80` means listening on every interface; `127.0.0.1:80` means loopback only - reachable from the machine itself but not from outside. That single distinction explains a huge share of "my service is up but I can't reach it" cases.
* `ss -s` gives the socket summary - a quick look at how many connections are open and in which states.
* State machine words worth knowing: `LISTEN` (waiting), `ESTABLISHED` (live connection), `TIME-WAIT` (recently closed, held briefly by the kernel so late packets are not misdelivered) - all visible in the `ss -tan` output below.
* Everyday one-liner: `ss -tulnp | grep 8080` - "who has my port?"

### Output

> Run on a box with nginx actually listening, so the output is meaningful.

```console
$ ss -tuln
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*          
tcp   LISTEN 0      511             [::]:80           [::]:*          

$ ss -tulnp
Netid State  Recv-Q Send-Q Local Address:Port Peer Address:PortProcess                         
tcp   LISTEN 0      511          0.0.0.0:80        0.0.0.0:*    users:(("nginx",pid=3050,fd=6))
tcp   LISTEN 0      511             [::]:80           [::]:*    users:(("nginx",pid=3050,fd=7))

$ netstat -tulnp
Active Internet connections (only servers)
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name    
tcp        0      0 0.0.0.0:80              0.0.0.0:*               LISTEN      3050/nginx: master  
tcp6       0      0 :::80                   :::*                    LISTEN      3050/nginx: master  

$ ss -tan | head -6
State     Recv-Q Send-Q Local Address:Port  Peer Address:PortProcess
LISTEN    0      511          0.0.0.0:80         0.0.0.0:*          
TIME-WAIT 0      0        172.17.0.12:44510 91.189.92.19:80         
TIME-WAIT 0      0        172.17.0.12:43712 91.189.92.19:80         
TIME-WAIT 0      0          127.0.0.1:40988    127.0.0.1:80         
LISTEN    0      511             [::]:80            [::]:*          

$ ss -s
Total: 28
TCP:   87 (estab 0, closed 85, orphaned 0, timewait 3)

Transport Total     IP        IPv6
RAW	  0         0         0        
UDP	  0         0         0        
TCP	  2         1         1        
INET	  2         1         1        
FRAG	  0         0         0
```

## 7. `curl`: speak HTTP from the command line

**What it does:** makes an HTTP request from the terminal. The universal way to test an API or a web server without a browser.

**What I understood from the output:**
* `curl -I` fetches headers only (a `HEAD` request) - enough to see the status code, the server, and the content type.
* `HTTP/2 200` is the status line: `2xx` success, `3xx` redirect, `4xx` your fault, `5xx` the server's fault.
* `-s` silences the progress meter, `-o /dev/null` throws the body away, and `-w` prints exactly the fields I want - the timing breakdown (`time_namelookup`, `time_connect`, `time_total`) tells me which phase is slow: DNS, TCP handshake, TLS, or the application.
* Other flags I use constantly: `-L` (follow redirects), `-X POST`, `-d '{{...}}'`, `-H 'Content-Type: application/json'`, `-v` (full request/response trace).

### Output

```console
$ curl -sI https://www.google.com | head -6
HTTP/2 200 
content-type: text/html; charset=ISO-8859-1
content-security-policy-report-only: object-src 'none';base-uri 'self';script-src 'nonce-Do2TJsGnThArafmxvIkiXA' 'strict-dynamic' 'report-sample' 'unsafe-eval' 'unsafe-inline' https: http:;report-uri https://csp.withgoogle.com/csp/gws/other-hp
accept-ch: Sec-CH-Prefers-Color-Scheme
p3p: CP="This is not a P3P policy! See g.co/p3phelp for more info."
date: Thu, 03 Sep 2026 09:36:53 GMT

$ curl -s https://api.github.com/zen
Approachable is better than simple.
$ curl -s -o /dev/null -w 'http_code=%{http_code} dns=%{time_namelookup}s connect=%{time_connect}s total=%{time_total}s\n' https://github.com
http_code=200 dns=0.003596s connect=0.034247s total=0.315295s
```

## 8. `nc` / `telnet`: is a TCP port open?

**What it does:** answers "is this TCP port reachable?" - one layer above `ping`. A host can answer ping and still refuse the port you need.

**What I understood from the output:**
* `nc -zv google.com 443` -> open. `-z` just scans (sends no data), `-v` prints the result.
* `nc -zv google.com 81 -w 3` -> times out. `-w 3` caps the wait, otherwise a filtered port hangs for a long time.
* The distinction that matters: connection refused = something answered and said no (the host is up, nothing is listening) versus timeout = a firewall silently dropped the packets.
* `telnet host port` is the old-school equivalent and is still handy because you can then type raw protocol commands by hand.
* Debug ladder I follow: `ping` (is the host alive) -> `nc -zv` (is the port open) -> `curl` (does the application answer).

### Output

```console
$ nc -zv google.com 443
Connection to google.com (142.251.106.138) 443 port [tcp/https] succeeded!

$ nc -zv google.com 81 -w 3
nc: connect to google.com (142.251.106.138) port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com (142.251.106.101) port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com (142.251.106.139) port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com (142.251.106.113) port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com (142.251.106.100) port 81 (tcp) timed out: Operation now in progress
nc: connect to google.com (142.251.106.102) port 81 (tcp) timed out: Operation now in progress

$ timeout 5 telnet google.com 80 </dev/null
Trying 142.251.106.138...
Connected to google.com.
Escape character is '^]'.
Connection closed by foreign host.
```

## 9. `hostname`, `/etc/hosts`, `/etc/resolv.conf`

**What it does:** shows the machine's own name and how it resolves names.

**What I understood from the output:**
* `hostname -I` prints the machine's IP addresses - quicker than reading `ip a`.
* `/etc/hosts` is consulted before DNS. Adding a line here overrides the whole internet for that name - the standard trick for local testing, and the standard reason a name resolves "wrongly" on one machine.
* `/etc/resolv.conf` lists the nameservers the resolver will ask. If DNS is broken, this file is the first place to look. In containers, Docker writes `nameserver 127.0.0.11` here - Docker's own embedded DNS server, which is what makes container-name resolution work.

### Output

```console
$ hostname
65360d27fc77

$ hostname -I
172.17.0.11 

$ cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::	ip6-localnet
ff00::	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
172.17.0.11	65360d27fc77

$ cat /etc/resolv.conf
# Generated by Docker Engine.
# This file can be edited; Docker Engine will not make further changes once it
# has been modified.

nameserver 192.168.65.7

# Based on host file: '/etc/resolv.conf' (legacy)
# Overrides: []
```

## 10. `arp` / `ip neigh`: MAC ↔ IP on the local segment

**What it does:** shows the ARP table, the mapping between IP addresses (layer 3) and MAC addresses (layer 2) for hosts on the same segment.

**What I understood from the output:**
* Before a packet can leave, the kernel needs the destination's MAC. If it isn't cached, the host broadcasts *"who has 172.17.0.1?"* and caches the reply - that's ARP.
* ARP only works inside one broadcast domain. For anything off-subnet, the machine ARPs for the gateway instead, which is why the gateway is almost always in the table.
* `ip neigh` is the modern equivalent and shows the state (`REACHABLE`, `STALE`, `DELAY`), which tells you whether the entry has been confirmed recently.

### Output

```console
$ ping -c 1 -W 2 $(ip route | awk '/default/ {print $3}') >/dev/null; arp -n
Address                  HWtype  HWaddress           Flags Mask            Iface
172.17.0.1               ether   1e:e4:99:28:0d:3d   C                     eth0

$ ip neigh
172.17.0.1 dev eth0 lladdr 1e:e4:99:28:0d:3d DELAY
```

## 11. `whois`: who owns a domain

**What it does:** queries the registry for the ownership and registration details of a domain.

**What I understood from the output:** it returns the registrar (`MarkMonitor Inc.`), the creation date (2007-10-09), the registry expiry date (2026-10-09), the abuse contact, and the domain status locks such as `clientDeleteProhibited`. In practice I use it for two things: checking when a domain expires - a surprising number of outages are just an expired domain - and (further down the full output) reading the authoritative nameservers, which is the starting point for any DNS delegation problem.

### Output

```console
$ whois github.com | head -12
   Domain Name: GITHUB.COM
   Registry Domain ID: 1264983250_DOMAIN_COM-VRSN
   Registrar WHOIS Server: whois.markmonitor.com
   Registrar URL: http://www.markmonitor.com
   Updated Date: 2024-09-07T09:16:32Z
   Creation Date: 2007-10-09T18:20:50Z
   Registry Expiry Date: 2026-10-09T18:20:50Z
   Registrar: MarkMonitor Inc.
   Registrar IANA ID: 292
   Registrar Abuse Contact Email: abusecomplaints@markmonitor.com
   Registrar Abuse Contact Phone: +1.2086851750
   Domain Status: clientDeleteProhibited https://icann.org/epp#clientDeleteProhibited
```

## 12. `tcpdump`: capture packets on the wire

**What it does:** captures packets straight off the interface. The tool you reach for when everything "looks fine" but traffic still doesn't arrive.

**What I understood from the output:**
* `-i any` captures on all interfaces, `-c 6` stops after 6 packets, `-n` skips name resolution, and `icmp` is a BPF filter so only ping traffic is shown.
* Seeing `ICMP echo request` and `echo reply` proves traffic flows in both directions. Requests with no replies means the packets are leaving but nothing is coming back - a firewall or a routing problem on the far side, not on mine.
* Filters I use most: `port 80`, `host 8.8.8.8`, `tcp port 443`, and `-w capture.pcap` to save a capture and open it in Wireshark.

### Output

```console
$ timeout 6 tcpdump -i any -c 6 -n icmp & sleep 1; ping -c 3 8.8.8.8 >/dev/null; wait
tcpdump: data link type LINUX_SLL2
tcpdump: verbose output suppressed, use -v[v]... for full protocol decode
listening on any, link-type LINUX_SLL2 (Linux cooked v2), snapshot length 262144 bytes
09:37:15.220824 eth0  Out IP 172.17.0.11 > 8.8.8.8: ICMP echo request, id 4, seq 1, length 64
09:37:15.249034 eth0  In  IP 8.8.8.8 > 172.17.0.11: ICMP echo reply, id 4, seq 1, length 64
09:37:16.228183 eth0  Out IP 172.17.0.11 > 8.8.8.8: ICMP echo request, id 4, seq 2, length 64
09:37:16.256940 eth0  In  IP 8.8.8.8 > 172.17.0.11: ICMP echo reply, id 4, seq 2, length 64
09:37:17.233848 eth0  Out IP 172.17.0.11 > 8.8.8.8: ICMP echo request, id 4, seq 3, length 64
09:37:17.262557 eth0  In  IP 8.8.8.8 > 172.17.0.11: ICMP echo reply, id 4, seq 3, length 64
6 packets captured
6 packets received by filter
0 packets dropped by kernel
```

## 13. `/dev/tcp`: a port check with nothing but bash

**What it does:** bash exposes `/dev/tcp/host/port` as a pseudo-device, so opening it *is* a TCP connect. Useful on stripped-down containers where `nc`, `telnet` and `curl` are all missing - which is most production images.

**What I understood from the output:** `timeout 2 bash -c '</dev/tcp/google.com/443'` succeeded, so the port is open. The exit status is the whole answer, which makes it ideal inside health-check scripts and Dockerfile `HEALTHCHECK` lines.

### Output

```console
$ timeout 2 bash -c '</dev/tcp/google.com/443' && echo 'port 443 OPEN' || echo 'port 443 CLOSED'
port 443 OPEN
```

---

## Theory recap (from `session4-networking/ip.md`)

### IP address classes

| Class | First octet range | Default subnet mask | Network / host bits | Usable hosts |
|---|---|---|---|---|
| A | 1 - 126 | `255.0.0.0` (`/8`) | 8 / 24 | 2²⁴ − 2 = 16,777,214 |
| B | 128 - 191 | `255.255.0.0` (`/16`) | 16 / 16 | 2¹⁶ − 2 = 65,534 |
| C | 192 - 223 | `255.255.255.0` (`/24`) | 24 / 8 | 2⁸ − 2 = 254 |
| D | 224 - 239 | - | multicast | - |
| E | 240 - 255 | - | experimental | - |

`127.0.0.0/8` is reserved for loopback. Two addresses are subtracted from every range because the all-zeros address is the network address and the all-ones address is the broadcast address - neither can be given to a host.

### Private IP ranges (RFC 1918: never routed on the internet)

| Class | Range | CIDR |
|---|---|---|
| A | 10.0.0.0 - 10.255.255.255 | `10.0.0.0/8` |
| B | 172.16.0.0 - 172.31.255.255 | `172.16.0.0/12` |
| C | 192.168.0.0 - 192.168.255.255 | `192.168.0.0/16` |

The interface in the output above (`172.17.0.11/16`) sits inside the Class B private range - that is the range Docker uses for its default bridge network.

### Worked example

```
197.23.45.10  with mask 255.255.255.0   (Class C, /24)

network bits = 24, host bits = 8
network address   = 197.23.45.0
broadcast address = 197.23.45.255
usable host range = 197.23.45.1 - 197.23.45.254
usable hosts      = 2^8 - 2 = 254
```

### The OSI model, and which command lives where

| Layer | Name | Example | Command that inspects it |
|---|---|---|---|
| 7 | Application | HTTP, DNS, SSH | `curl`, `dig` |
| 4 | Transport | TCP, UDP (ports) | `ss`, `netstat`, `nc` |
| 3 | Network | IP, ICMP, routing | `ip a`, `ip route`, `ping`, `traceroute` |
| 2 | Data link | Ethernet, MAC, ARP | `arp`, `ip neigh`, `ip link` |
| 1 | Physical | cables, NICs | link state in `ip a` (`LOWER_UP`) |

### My troubleshooting order

```
1. ip a                 → do I even have an IP?
2. ip route             → do I have a default gateway?
3. ping 8.8.8.8         → is the network up?          (no DNS involved)
4. ping google.com      → is DNS working?             (works above but fails here = DNS)
5. cat /etc/resolv.conf → which resolver am I asking?
6. nc -zv host port     → is the port open?
7. curl -v http://host  → does the application answer?
8. ss -tulnp            → is my own service actually listening, and on which address?
9. tcpdump -i any port X → is the traffic even arriving?
```

---

## Reference repos practised (Task 1)

* <https://github.com/Nency-Ravaliya/Network-Troubleshooting>
* <https://github.com/Nency-Ravaliya/OSI-Network-devices>
* <https://github.com/Nency-Ravaliya/Networking>
* <https://github.com/Nency-Ravaliya/Subnetting>
* <https://github.com/Nency-Ravaliya/IP-quest>
* <https://github.com/Nency-Ravaliya/IPFIX-NETFLOW-NTP>
* <https://github.com/Nency-Ravaliya/How-DHCP-Works>
