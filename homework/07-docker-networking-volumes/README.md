# Docker Networking & Volumes — Homework (Session 8)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed and the output pasted verbatim.

---

## Contents
1. [Task 1 — Container networking (3 containers, 3 networks)](#task-1--container-networking)
2. [Task 2 — Host network](#task-2--host-network)
3. [Task 3 — Bind mount](#task-3--bind-mount)
4. [Task 4 — Overlay network](#task-4--overlay-network)
5. [Docker network drivers — summary](#docker-network-drivers--summary)

---

## Task 1 — Container Networking

**Goal:** three containers (frontend, backend, database), three networks, the **backend attached to two** of them, and connectivity checked between all of them.

### Topology built

```
       frontend-net (172.24.0.0/16)          backend-net (172.25.0.0/16)        database-net (172.26.0.0/16)
    ┌──────────────────────────────┐   ┌──────────────────────────────────┐   ┌────────────────────────┐
    │  hw-frontend   172.24.0.2    │   │   hw-backend    172.25.0.3       │   │ hw-database 172.26.0.2 │
    │  (nginx:alpine)              │   │   hw-database   172.25.0.2       │   │                        │
    │  hw-backend    172.24.0.3 ───┼───┼──▶ on BOTH networks              │   │                        │
    └──────────────────────────────┘   └──────────────────────────────────┘   └────────────────────────┘

    hw-frontend ──✅──▶ hw-backend      (share frontend-net)
    hw-backend  ──✅──▶ hw-database     (share backend-net)
    hw-frontend ──❌──▶ hw-database     (share NO network → isolated)
```

`hw-backend` is the only container on **two** networks — it is the bridge between the frontend tier and the database tier. That is exactly how a real 3-tier app is wired: the web tier must never be able to reach the database directly.

### Commands

```bash
# 3 networks
docker network create frontend-net
docker network create backend-net
docker network create database-net

# 3 containers
docker run -d --name hw-frontend --network frontend-net nginx:alpine
docker run -d --name hw-backend  --network frontend-net alpine:3.20 sleep 3600
docker run -d --name hw-database --network backend-net \
  -e MYSQL_ROOT_PASSWORD=root123 -e MYSQL_DATABASE=devops mysql:8.0

# put the backend on a SECOND network
docker network connect backend-net hw-backend

# connectivity
docker exec hw-backend  ping -c 3 hw-frontend     # works
docker exec hw-backend  ping -c 3 hw-database     # works
docker exec hw-frontend ping -c 2 hw-database     # fails — isolated
docker exec hw-backend  nc -zv hw-database 3306   # port-level check
```

### Output

```console
########## SESSION 8 - TASK 1 : DOCKER CONTAINER NETWORKING ##########

===== Step 1: create 3 user-defined bridge networks =====

$ docker network create frontend-net
588cb35a01843fdb4cc019568f2fcb22c4eadaeedc670e12e0a072661eab7ecf

$ docker network create backend-net
7a6e3db5257e85bb7756de3f0ebd580bfff1de0a2fee85c9697d9f1fe533d4dc

$ docker network create database-net
a8dfceb5d7c24042a2c204ad107f9c069944efd491c45744bf0801369ea9f89c

$ docker network ls | grep -E 'NETWORK|frontend-net|backend-net|database-net'
NETWORK ID     NAME                                                             DRIVER    SCOPE
7a6e3db5257e   backend-net                                                      bridge    local
a8dfceb5d7c2   database-net                                                     bridge    local
588cb35a0184   frontend-net                                                     bridge    local

===== Step 2: create the 3 containers =====

$ docker run -d --name hw-frontend --network frontend-net nginx:alpine
27ea653ca1cb10490e6e80e2e617f167115e7df21584fd6c210da9b0acb99269

$ docker run -d --name hw-backend  --network frontend-net alpine:3.20 sleep 3600
ab8484093700da61fcc9df421f70784d92dc567e23b5364e149e073cb0aa99c0

$ docker run -d --name hw-database --network backend-net -e MYSQL_ROOT_PASSWORD=root123 -e MYSQL_DATABASE=devops mysql:8.0
fe8a89dc9b632f7151dffcff371bb7eb5e24c802989ef1151a5d87b41cb19b9b

===== Step 3: attach the BACKEND container to a 2nd network =====

$ docker network connect backend-net hw-backend

$ docker inspect hw-backend --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} => {{$v.IPAddress}}{{"
"}}{{end}}'
backend-net => 172.25.0.3
frontend-net => 172.24.0.3


$ docker inspect hw-frontend --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} => {{$v.IPAddress}}{{"
"}}{{end}}'
frontend-net => 172.24.0.2


$ docker inspect hw-database --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} => {{$v.IPAddress}}{{"
"}}{{end}}'
backend-net => 172.25.0.2


===== Step 4: which containers are on which network =====

$ docker network inspect frontend-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
frontend-net: hw-frontend hw-backend 

$ docker network inspect backend-net  --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
backend-net: hw-backend hw-database 

$ docker network inspect database-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
database-net: 

===== Step 5: CONNECTIVITY TESTS =====

--- backend -> frontend (SAME network frontend-net) : should WORK ---

$ docker exec hw-backend ping -c 3 hw-frontend
PING hw-frontend (172.24.0.2): 56 data bytes
64 bytes from 172.24.0.2: seq=0 ttl=64 time=0.187 ms
64 bytes from 172.24.0.2: seq=1 ttl=64 time=0.105 ms
64 bytes from 172.24.0.2: seq=2 ttl=64 time=0.190 ms

--- hw-frontend ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.105/0.160/0.190 ms

--- backend -> database (SAME network backend-net) : should WORK ---

$ docker exec hw-backend ping -c 3 hw-database
PING hw-database (172.25.0.2): 56 data bytes
64 bytes from 172.25.0.2: seq=0 ttl=64 time=0.787 ms
64 bytes from 172.25.0.2: seq=1 ttl=64 time=0.086 ms
64 bytes from 172.25.0.2: seq=2 ttl=64 time=0.033 ms

--- hw-database ping statistics ---
3 packets transmitted, 3 packets received, 0% packet loss
round-trip min/avg/max = 0.033/0.302/0.787 ms

--- frontend -> database (NO shared network) : should FAIL ---

$ docker exec hw-frontend ping -c 2 hw-database
ping: bad address 'hw-database'

^ DNS resolution fails because they share no network. This is network ISOLATION.

--- port level check : backend can reach MySQL on 3306 ---

$ docker exec hw-backend nc -zv hw-database 3306
hw-database (172.25.0.2:3306) open

$ docker exec hw-backend nc -zv hw-frontend 80
hw-frontend (172.24.0.2:80) open

$ docker exec hw-frontend nc -zv hw-database 3306
nc: bad address 'hw-database'

--- built-in DNS: docker resolves container NAMES on user-defined networks ---

$ docker exec hw-backend cat /etc/resolv.conf
# Generated by Docker Engine.
# This file can be edited; Docker Engine will not make further changes once it
# has been modified.

nameserver 127.0.0.11
options ndots:0

# Based on host file: '/etc/resolv.conf' (internal resolver)
# ExtServers: [host(192.168.65.7)]
# Overrides: []
# Option ndots from: internal

$ docker exec hw-backend nslookup hw-database
Server:		127.0.0.11
Address:	127.0.0.11:53

Non-authoritative answer:

Non-authoritative answer:
Name:	hw-database
Address: 172.25.0.2


===== Step 6: put the database on the 3rd network too =====

$ docker network connect database-net hw-database

$ docker inspect hw-database --format '{{range $k,$v := .NetworkSettings.Networks}}{{$k}} => {{$v.IPAddress}}{{"
"}}{{end}}'
backend-net => 172.25.0.2
database-net => 172.26.0.2


$ docker network inspect database-net --format '{{.Name}}: {{range .Containers}}{{.Name}} {{end}}'
database-net: hw-database 

Final topology:
  frontend-net : hw-frontend , hw-backend
  backend-net  : hw-backend  , hw-database   <-- hw-backend is on 2 networks
  database-net : hw-database
```

### What the output proves

* **Two IPs on one container.** `docker inspect hw-backend` lists `backend-net => 172.25.0.3` *and* `frontend-net => 172.24.0.3`. A container gets one virtual interface and one IP **per network** it joins.
* **DNS by container name works** on user-defined networks. `ping hw-database` resolved automatically — Docker runs an embedded DNS server at `127.0.0.11` (visible in `/etc/resolv.conf`) that resolves container names. This does **not** happen on the legacy default `bridge` network, which is the main reason to always create your own network.
* **Isolation is real.** `docker exec hw-frontend ping hw-database` → `bad address 'hw-database'`. The name doesn't even resolve, because the two containers share no network. This is the security property you rely on to keep a web tier away from a database.
* **Port-level reachability.** `nc -zv hw-database 3306` → `open` from the backend, `bad address` from the frontend.

---

## Task 2 — Host Network

**Goal:** pull the Apache2 image, run it with the **host network**, and access the site on port 80.

### Commands

```bash
docker pull httpd:2.4
docker run -d --name hw-apache-host --network host httpd:2.4
curl http://localhost:80
```

### Output

```console
########## SESSION 8 - TASK 2 : HOST NETWORK ##########

===== Step 1: pull the Apache2 (httpd) image from Docker Hub =====

$ docker pull httpd:2.4
2.4: Pulling from library/httpd
Digest: sha256:979c38c2228d28c2edfd45c6e27dcee1c7b4a101a5526721ae8ece454e89e99e
Status: Image is up to date for httpd:2.4
docker.io/library/httpd:2.4

$ docker images httpd
REPOSITORY   TAG       IMAGE ID       CREATED      SIZE
httpd        2.4       979c38c2228d   9 days ago   205MB

===== Step 2: run the container with --network host =====

$ docker run -d --name hw-apache-host --network host httpd:2.4
ddf05515274aa7832021ecd114dd78c4e16c8a649dd34488d82e492477dc15c4

$ docker ps --filter name=hw-apache-host --format 'table {{.Names}}	{{.Image}}	{{.Status}}	{{.Ports}}'
NAMES            IMAGE       STATUS         PORTS
hw-apache-host   httpd:2.4   Up 3 seconds   

NOTE the PORTS column is EMPTY - with --network host there is NO port mapping.
     The container shares the HOST's network namespace and binds port 80 directly.

$ docker inspect hw-apache-host --format 'NetworkMode = {{.HostConfig.NetworkMode}}'
NetworkMode = host

$ docker inspect hw-apache-host --format 'Networks = {{range $k,$v := .NetworkSettings.Networks}}{{$k}}{{end}} | ContainerIP = "{{.NetworkSettings.IPAddress}}"'
Networks = host | ContainerIP = ""

^ the container has NO IP of its own - it IS the host, network-wise.

===== Step 3: access the Apache website on port 80 =====

$ docker run --rm --network host alpine:3.20 wget -qO- http://localhost:80
<!DOCTYPE HTML PUBLIC "-//W3C//DTD HTML 4.01//EN" "http://www.w3.org/TR/html4/strict.dtd">
<html>
<head>
<title>It works! Apache httpd</title>
</head>
<body>
<p>It works!</p>
</body>
</html>

$ docker run --rm --network host alpine:3.20 wget -S -qO /dev/null http://127.0.0.1:80 2>&1 | head -8
  HTTP/1.1 200 OK
  Date: Thu, 03 Sep 2026 09:33:39 GMT
  Server: Apache/2.4.68 (Unix)
  Last-Modified: Fri, 07 Nov 2025 08:23:08 GMT
  ETag: "bf-642fce432f300"
  Accept-Ranges: bytes
  Content-Length: 191
  Connection: close

===== Proof that port 80 is bound in the HOST network namespace =====

$ docker run --rm --network host alpine:3.20 sh -c 'apk add -q --no-cache busybox-extras >/dev/null 2>&1; netstat -tln | grep -E "Local Address|:80 "'
Proto Recv-Q Send-Q Local Address           Foreign Address         State       
tcp        0      0 :::80                   :::*                    LISTEN

===== bridge vs host, side by side =====

$ docker run -d --name hw-apache-bridge -p 8085:80 httpd:2.4
ee06773040eac30d128ff598706b9072e2b14c7590ac30aa0488e2279f4df2d2

$ docker ps --filter name=hw-apache --format 'table {{.Names}}	{{.Ports}}'
NAMES              PORTS
hw-apache-bridge   0.0.0.0:8085->80/tcp, [::]:8085->80/tcp
hw-apache-host     
hw-apache          0.0.0.0:8082->80/tcp, [::]:8082->80/tcp

$ curl -sI http://localhost:8085 | head -3
HTTP/1.1 200 OK
Date: Thu, 03 Sep 2026 09:33:43 GMT
Server: Apache/2.4.68 (Unix)

  hw-apache-bridge -> bridge network, needs -p 8085:80 to be reachable
  hw-apache-host   -> host network, port 80 taken directly, no -p needed

$ docker rm -f hw-apache-bridge
hw-apache-bridge
```

### What the output proves

* **`PORTS` is empty in `docker ps`.** With `--network host` there is no port mapping, because there is no separate network namespace to map *from*. The container binds port 80 on the host directly.
* **The container has no IP of its own** — `ContainerIP = ""` and the only "network" is `host`. Network-wise, the container *is* the host.
* **`netstat` in the host namespace shows `:::80 LISTEN`** — Apache is genuinely holding host port 80.
* Side by side: `hw-apache-bridge` needed `-p 8085:80` to be reachable; `hw-apache-host` needed nothing.

### Bridge vs host

| | bridge (default) | host |
|---|---|---|
| Network namespace | its own | **shares the host's** |
| Container IP | yes (e.g. `172.17.0.2`) | none |
| Port publishing | required (`-p 8080:80`) | not used — binds host ports directly |
| Port conflicts | impossible between containers | **possible** — two containers can't both take :80 |
| Performance | slight NAT overhead | no NAT, marginally faster |
| Isolation | good | **weak** — the container sees every host interface |
| Typical use | almost everything | high-throughput proxies, monitoring agents that must see host interfaces |

> **Note on macOS/Windows:** Docker Desktop runs the engine inside a Linux VM, so "the host" for `--network host` is that VM, not macOS itself. The `wget` / `netstat` checks above were therefore run **from inside that same host namespace**, which is the accurate way to verify it on Docker Desktop. On a native Linux machine the identical `docker run --network host` command makes the site available at `http://localhost:80` on the machine itself, and `curl http://localhost` from a normal terminal works directly. (Docker Desktop ≥ 4.34 can also forward it to the Mac if *Settings → Resources → Network → Enable host networking* is switched on.)

---

## Task 3 — Bind Mount

**Goal:** create a folder with an `index.html` containing "Hello students", bind-mount it into Nginx, verify the page, then edit the file and confirm the change appears **without restarting the container**.

Folder used: [`bind-mount-demo/`](bind-mount-demo/)

### Commands

```bash
mkdir -p bind-mount-demo
echo '<h1>Hello students</h1>' > bind-mount-demo/index.html

docker run -d --name hw-bindmount -p 8084:80 \
  -v "$(pwd)/bind-mount-demo":/usr/share/nginx/html:ro nginx:alpine

curl http://localhost:8084                     # -> Hello students

# edit the file on the HOST, container untouched
echo '<h1>Hello students - edited on the host</h1>' > bind-mount-demo/index.html
curl http://localhost:8084                     # -> the new content, instantly
```

### Output

```console
########## SESSION 8 - TASK 3 : BIND MOUNT ##########

===== Step 1: create a folder on the local machine =====

$ mkdir -p /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo && cd /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo && pwd
/Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo

===== Step 2: create index.html with 'Hello students' =====

$ echo '<h1>Hello students</h1>' > /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo/index.html

$ cat /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo/index.html
<h1>Hello students</h1>

===== Step 3: bind mount that folder into an Nginx container =====

$ docker run -d --name hw-bindmount -p 8084:80 -v /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo:/usr/share/nginx/html:ro nginx:alpine
3507af5dff78229c6e13cbbd089918158cae74ed2c5e2b3755c0f58574b064e9

$ docker ps --filter name=hw-bindmount --format 'table {{.Names}}	{{.Status}}	{{.Ports}}'
NAMES          STATUS         PORTS
hw-bindmount   Up 3 seconds   0.0.0.0:8084->80/tcp, [::]:8084->80/tcp

$ docker inspect hw-bindmount --format '{{range .Mounts}}Type={{.Type}}  Source={{.Source}}  Destination={{.Destination}}  RW={{.RW}}{{end}}'
Type=bind  Source=/Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo  Destination=/usr/share/nginx/html  RW=false

===== Step 4: access the Nginx website and verify the content =====

$ curl -s http://localhost:8084
<h1>Hello students</h1>

$ docker exec hw-bindmount ls -l /usr/share/nginx/html
total 4
-rw-r--r--    1 root     root            24 Sep  3 09:34 index.html

$ docker exec hw-bindmount cat /usr/share/nginx/html/index.html
<h1>Hello students</h1>

===== Step 5: MODIFY the file on the host (container NOT restarted) =====

$ echo '<h1>Hello students - file was edited on the HOST at '"$(date +%H:%M:%S)"'</h1>' > /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo/index.html

$ cat /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo/index.html
<h1>Hello students - file was edited on the HOST at 15:04:24</h1>

===== Step 6: re-request the page - change is live instantly =====

$ curl -s http://localhost:8084
<h1>Hello students - file was edited on the HOST at 15:04:24</h1>

$ docker ps --filter name=hw-bindmount --format '{{.Names}} -> {{.Status}}   (never restarted)'
hw-bindmount -> Up 3 seconds   (never restarted)

===== Step 7: add a NEW file on the host, instantly served too =====

$ echo '<h1>Second page created on the host</h1>' > /Users/talindaga/Desktop/Desktop/devops-heros/homework/07-docker-networking-volumes/bind-mount-demo/page2.html

$ curl -s http://localhost:8084/page2.html
<h1>Second page created on the host</h1>

===== Bind mount vs named VOLUME =====

$ docker volume create hw-demo-volume
hw-demo-volume

$ docker run -d --name hw-volume-demo -p 8086:80 -v hw-demo-volume:/usr/share/nginx/html nginx:alpine
31648ac21243ca73a63adbbb78a5401bda20fb6c56ea39c9833dc369bb4c9b75

$ docker volume inspect hw-demo-volume
[
    {
        "CreatedAt": "2026-09-03T09:34:24Z",
        "Driver": "local",
        "Labels": null,
        "Mountpoint": "/var/lib/docker/volumes/hw-demo-volume/_data",
        "Name": "hw-demo-volume",
        "Options": null,
        "Scope": "local"
    }
]

$ docker exec hw-volume-demo sh -c 'echo "<h1>Served from a NAMED VOLUME</h1>" > /usr/share/nginx/html/index.html'

$ curl -s http://localhost:8086
<h1>Served from a NAMED VOLUME</h1>

$ docker rm -f hw-volume-demo
hw-volume-demo

$ docker run -d --name hw-volume-demo2 -p 8086:80 -v hw-demo-volume:/usr/share/nginx/html nginx:alpine
95b94994c63e34ddd6b2051d0d6f82361313367b743661cbfc3c889949f764cb

$ curl -s http://localhost:8086
<h1>Served from a NAMED VOLUME</h1>

^ data SURVIVED the container being destroyed - that is what a volume is for.

$ docker rm -f hw-volume-demo2 && docker volume rm hw-demo-volume
hw-volume-demo2
hw-demo-volume
```

### What the output proves

* `docker inspect` shows `Type=bind`, the host `Source=` path and `Destination=/usr/share/nginx/html`, with `RW=false` because `:ro` was used — Nginx only needs to read.
* The very first request returned **`<h1>Hello students</h1>`** — the host file, served by Nginx.
* After editing the file **on the host**, the next request returned the new content, and `docker ps` shows the same `Up` status — the container was **never restarted**. That is the whole point of a bind mount: the host directory *is* the container directory, so changes are live. This is why bind mounts are the standard local-development setup (hot reload).
* A brand-new file `page2.html` created on the host was served immediately too.
* The extra **named-volume** section shows the contrast: a volume survived `docker rm -f` and reattached to a fresh container with the data intact.

### Bind mount vs named volume vs tmpfs

| | Bind mount | Named volume | tmpfs |
|---|---|---|---|
| Syntax | `-v /host/path:/container/path` | `-v myvol:/container/path` | `--tmpfs /path` |
| Where the data lives | anywhere on the host you choose | Docker-managed (`/var/lib/docker/volumes/`) | RAM only |
| Host path dependency | yes — breaks on another machine | no — portable | n/a |
| Survives `docker rm` | yes (it's your folder) | yes | ❌ gone |
| Managed by `docker volume` cmds | no | yes (`ls`, `inspect`, `prune`) | no |
| Backup | ordinary file copy | `docker run --rm -v myvol:/data … tar` | n/a |
| Best for | **local development** (live source, hot reload), config files | **production data** — databases, uploads | secrets, scratch space |

---

## Task 4 — Overlay Network

### Research

An **overlay network** connects containers running on **different Docker hosts** as if they were on one flat LAN.

**How it works**

1. Overlay is a **swarm-scope** driver, so it needs a cluster — `docker swarm init` / `docker swarm join`.
2. When a container on node A sends a packet to a container on node B, Docker wraps the original Ethernet frame inside a **VXLAN** packet (UDP port **4789**) and sends it over the physical network to node B, which unwraps it and delivers it. The containers never know they were on different machines.
3. Each overlay network is a separate **VXLAN segment** (VNI). The output below shows `vxlanid_list:4097` for the network created.
4. The network definition and the IP allocations are stored in the swarm's **raft store** on the manager nodes, so every node that joins automatically knows about the network. Its `Scope` is `swarm`, not `local`.
5. **Service discovery** is built in: `nslookup <service>` returns a single **VIP** (virtual IP) that load-balances across replicas, while `tasks.<service>` returns the individual replica IPs.
6. The **routing mesh** means a published port is reachable on **every** node in the swarm, even nodes not running a replica — they forward the request internally.

**Ports required between nodes**

| Port | Protocol | Purpose |
|---|---|---|
| 2377 | TCP | swarm cluster management |
| 7946 | TCP + UDP | node-to-node gossip / service discovery |
| 4789 | UDP | VXLAN data plane (the actual container traffic) |

**Use cases**

* Multi-host container deployments in Docker Swarm.
* Microservices that must reach each other by name regardless of which node they land on.
* Any setup where a scheduler moves containers between hosts and the network must follow them.
* `--opt encrypted` adds IPsec encryption on the data plane for traffic crossing untrusted networks.

**Overlay vs bridge:** a bridge network is `local` — it only ever connects containers on **one** host. An overlay is `swarm`-scoped and spans **many** hosts. That is the whole difference.

### Practical demonstration

A single-node swarm was initialised purely to demonstrate the driver, then removed (`docker swarm leave --force`) so the machine was left exactly as it was found.

```bash
docker network create -d overlay will-fail-net     # fails: not a swarm manager
docker swarm init                                  # enable swarm mode
docker network create -d overlay --attachable hw-overlay-net
docker service create --name hw-web --network hw-overlay-net --replicas 2 -p 8087:80 nginx:alpine
docker run --rm --network hw-overlay-net alpine nslookup hw-web
docker service rm hw-web && docker network rm hw-overlay-net && docker swarm leave --force
```

### Output

```console
########## SESSION 8 - TASK 4 : OVERLAY NETWORK ##########

An overlay network needs SWARM MODE (a cluster), because it spans MULTIPLE Docker hosts.
Below: a single-node swarm is initialised only to demonstrate it, then removed.

===== Step 0: try creating an overlay network WITHOUT swarm =====

$ docker info --format 'Swarm state: {{.Swarm.LocalNodeState}}'
Swarm state: inactive

$ docker network create -d overlay will-fail-net
Error response from daemon: This node is not a swarm manager. Use "docker swarm init" or "docker swarm join" to connect this node to swarm and try again.

^ overlay networks are a SWARM feature - they cannot exist on a standalone Docker host.

===== Step 1: initialise swarm mode =====

$ docker swarm init
Swarm initialized: current node (cmvxrosjrr6iudrjpzizr83xe) is now a manager.

To add a worker to this swarm, run the following command:

    docker swarm join --token SWMTKN-1-2tt3muyelnxohffbfpxb01o9rggbhl71dmwrra11wxdwbrivxf-bwtnwbr55sm5835v5ff2j8jfm 192.168.65.3:2377

To add a manager to this swarm, run 'docker swarm join-token manager' and follow the instructions.

$ docker node ls
ID                            HOSTNAME         STATUS    AVAILABILITY   MANAGER STATUS   ENGINE VERSION
cmvxrosjrr6iudrjpzizr83xe *   docker-desktop   Ready     Active         Leader           28.4.0

$ docker info --format 'Swarm state: {{.Swarm.LocalNodeState}} | Nodes: {{.Swarm.Nodes}} | Managers: {{.Swarm.Managers}}'
Swarm state: active | Nodes: 1 | Managers: 1

===== Step 2: swarm automatically creates the ingress overlay network =====

$ docker network ls --filter driver=overlay
NETWORK ID     NAME      DRIVER    SCOPE
j934jgt9uqry   ingress   overlay   swarm

$ docker network inspect ingress --format 'Name={{.Name}} Driver={{.Driver}} Scope={{.Scope}} Subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}'
Name=ingress Driver=overlay Scope=swarm Subnet=10.0.0.0/24

===== Step 3: create our own attachable overlay network =====

$ docker network create -d overlay --attachable hw-overlay-net
kg4yx876yqm8nfr3bk7ja4d41

$ docker network ls --filter driver=overlay
NETWORK ID     NAME             DRIVER    SCOPE
kg4yx876yqm8   hw-overlay-net   overlay   swarm
j934jgt9uqry   ingress          overlay   swarm

$ docker network inspect hw-overlay-net --format 'Name={{.Name}} Driver={{.Driver}} Scope={{.Scope}} Attachable={{.Attachable}} Subnet={{range .IPAM.Config}}{{.Subnet}}{{end}}'
Name=hw-overlay-net Driver=overlay Scope=swarm Attachable=true Subnet=10.0.1.0/24

NOTE: Scope = swarm (not local). The network definition is stored in the swarm's
      raft store and is available on EVERY node that joins the cluster.

===== Step 4: deploy a service on the overlay network =====

$ docker service create --name hw-web --network hw-overlay-net --replicas 2 -p 8087:80 nginx:alpine
fr88gwdm0t8e73gqyjnu7q4eg
overall progress: 0 out of 2 tasks
1/2:  
2/2:  
overall progress: 0 out of 2 tasks
overall progress: 2 out of 2 tasks
verify: Waiting 5 seconds to verify that tasks are stable...
verify: Service fr88gwdm0t8e73gqyjnu7q4eg converged

$ docker service ls
ID             NAME      MODE         REPLICAS   IMAGE          PORTS
fr88gwdm0t8e   hw-web    replicated   2/2        nginx:alpine   *:8087->80/tcp

$ docker service ps hw-web --no-trunc --format 'table {{.Name}}	{{.Node}}	{{.CurrentState}}'
NAME       NODE             CURRENT STATE
hw-web.1   docker-desktop   Running 13 seconds ago
hw-web.2   docker-desktop   Running 13 seconds ago

===== Step 5: containers on the overlay talk by SERVICE NAME (VIP load balancing) =====

$ docker run --rm --network hw-overlay-net alpine:3.20 nslookup hw-web
Server:		127.0.0.11
Address:	127.0.0.11:53

Non-authoritative answer:

Non-authoritative answer:
Name:	hw-web
Address: 10.0.1.2


$ docker run --rm --network hw-overlay-net alpine:3.20 nslookup tasks.hw-web
Server:		127.0.0.11
Address:	127.0.0.11:53

Non-authoritative answer:

Non-authoritative answer:
Name:	tasks.hw-web
Address: 10.0.1.3
Name:	tasks.hw-web
Address: 10.0.1.4


  hw-web        -> one Virtual IP (VIP); swarm load-balances across replicas
  tasks.hw-web  -> the real IPs of every replica (DNS round robin)

$ docker run --rm --network hw-overlay-net alpine:3.20 wget -qO- http://hw-web | head -5
<!DOCTYPE html>
<html>
<head>
<title>Welcome to nginx!</title>
<style>

===== Step 6: routing mesh - the published port works on ANY node =====

$ curl -sI http://localhost:8087 | head -3
HTTP/1.1 200 OK
Server: nginx/1.31.5
Date: Thu, 03 Sep 2026 09:35:31 GMT

===== Step 7: how the overlay actually moves packets =====

$ docker network inspect hw-overlay-net --format 'Options: {{.Options}}'
Options: map[com.docker.network.driver.overlay.vxlanid_list:4097]

  driver = overlay -> traffic between nodes is encapsulated in VXLAN (UDP 4789)
  swarm control plane uses TCP/UDP 7946 (gossip) and TCP 2377 (cluster management)

===== Step 8: clean up - remove the service, network and leave swarm =====

$ docker service rm hw-web
hw-web

$ docker network rm hw-overlay-net
hw-overlay-net

$ docker swarm leave --force
Node left the swarm.

$ docker info --format 'Swarm state: {{.Swarm.LocalNodeState}}'
Swarm state: inactive
```

### What the output proves

* **Overlay requires swarm.** Before `swarm init`: *"This node is not a swarm manager."*
* **`Scope=swarm`, not `local`** — unlike a bridge network, the definition lives in the cluster, not on one host.
* Swarm automatically created the **`ingress`** overlay network (`10.0.0.0/24`) used by the routing mesh.
* `hw-overlay-net` got its own subnet `10.0.1.0/24` and its own **VXLAN id 4097**.
* **VIP load balancing:** `nslookup hw-web` → one address `10.0.1.2` (the virtual IP), while `nslookup tasks.hw-web` → `10.0.1.3` and `10.0.1.4`, the two actual replicas. Traffic to the VIP is spread across them by the kernel's IPVS.
* The service was reachable both **from inside the overlay** (`wget http://hw-web`) and **from outside via the routing mesh** (`curl http://localhost:8087` → `200 OK`).
* Cleanup confirmed: `Swarm state: inactive`.

---

## Docker network drivers — summary

| Driver | Scope | What it is for |
|---|---|---|
| `bridge` | local | **default.** Private network on a single host; use a *user-defined* bridge to get DNS by container name |
| `host` | local | container shares the host's network stack; no isolation, no port mapping |
| `overlay` | swarm | multi-host networking via VXLAN; the basis of Swarm services |
| `macvlan` | local | gives the container its own MAC and an IP **on the physical LAN** — it looks like a real machine to the network |
| `ipvlan` | local | like macvlan but shares the host's MAC; used where switches limit MACs per port |
| `none` | local | no networking at all — maximum isolation, for batch jobs that must not touch the network |

## Command reference

```bash
# networks
docker network ls
docker network create <name>
docker network create -d overlay --attachable <name>
docker network inspect <name>
docker network connect <net> <container>
docker network disconnect <net> <container>
docker network prune

# volumes and mounts
docker volume ls
docker volume create <name>
docker volume inspect <name>
docker volume rm <name>
docker volume prune
docker run -v /host/path:/container/path       # bind mount
docker run -v /host/path:/container/path:ro    # read-only bind mount
docker run -v myvol:/container/path            # named volume
docker run --tmpfs /container/path             # in-memory
docker inspect <container> --format '{{ .Mounts }}'
```

---

## Cleanup

```bash
docker rm -f hw-frontend hw-backend hw-database hw-bindmount hw-apache-host
docker network rm frontend-net backend-net database-net
```

---

## Screenshots (optional extras)

Real terminal output is already included above. To add screenshots, drop them in [`screenshots/`](screenshots/) and uncomment:

<!--
![3 networks and 3 containers](screenshots/01-networks.png)
![Connectivity tests](screenshots/02-connectivity.png)
![Apache on host network](screenshots/03-host-network.png)
![Bind mount before and after edit](screenshots/04-bind-mount.png)
![Overlay network and service](screenshots/05-overlay.png)
-->
