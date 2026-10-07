# DevOps Homework: Talin Daga

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com
**Repository:** <https://github.com/Talin12/devops-heros>

All homework from the DevOps Heroes sessions, one folder per topic. Every command in every
README was actually executed and the output pasted verbatim - no invented output.

---

## Submissions (Section B: Google Form)

| # | Topic | Session | README to submit |
|---|---|---|---|
| 1 | Linux Fundamentals | Session 2 | [`01-linux-fundamentals/README.md`](01-linux-fundamentals/README.md) |
| 2 | Shell Scripting | Session 3 | [`02-shell-scripting/README.md`](02-shell-scripting/README.md) |
| 3 | Networking | Session 4 | [`03-networking/README.md`](03-networking/README.md) |
| 4 | Git and GitHub | Session 5 | [`04-git-github/README.md`](04-git-github/README.md) |
| 5 | Docker Fundamentals | Sessions 6-7 | [`05-docker-fundamentals/README.md`](05-docker-fundamentals/README.md) |
| 6 | Docker Images / Dockerfiles | Sessions 6-7 | [`06-dockerfiles-and-images/README.md`](06-dockerfiles-and-images/README.md) |
| 7 | Docker Networking | Session 8 | [`07-docker-networking-volumes/README.md`](07-docker-networking-volumes/README.md) |
| 8 | Kubernetes Ingress, ConfigMaps & Secrets | Session 12 | [`08-k8s-ingress-configmaps-secrets/README.md`](08-k8s-ingress-configmaps-secrets/README.md) |
| 9 | Kubernetes Fundamentals | Session 9 | [`09-k8s-fundamentals/README.md`](09-k8s-fundamentals/README.md) |
| 10 | Kubernetes Pods, ReplicaSets & Deployments | Session 10 | [`10-k8s-core-objects/README.md`](10-k8s-core-objects/README.md) |
| 11 | Kubernetes Networking & Services | Session 11 | [`11-k8s-services/README.md`](11-k8s-services/README.md) |

---

## What each folder contains

### [01: Linux Fundamentals](01-linux-fundamentals/)
Soft links vs hard links (inodes, link counts, what breaks when the original is deleted),
`adduser` vs `useradd` and which one Ubuntu prefers, `journalctl` run against a real systemd
system, and a worked Linux command cheat sheet. Plus interview Q&A.

### [02: Shell Scripting](02-shell-scripting/)
`system_info.sh` - prints date, hostname, username, disk usage and processes, uses variables,
takes input with `read -p`, creates a directory and file, and saves `ps aux` into it with `>`.

### [03: Networking](03-networking/)
Thirteen networking commands (`ip a`, `ip route`, `ping`, `traceroute`, `dig`, `ss`, `curl`,
`nc`, `arp`, `whois`, `tcpdump`, ...) each with real output and an explanation of what it means,
plus IP classes, private ranges, subnetting and a troubleshooting order.

### [04: Git and GitHub](04-git-github/)
`git commit -m` vs `git commit -a -m` demonstrated to the point where `-a` visibly refuses an
untracked file, and a full cherry-pick walkthrough with before/after proof.

### [05: Docker Fundamentals](05-docker-fundamentals/)
Six Hello World web apps, each in its own folder with its own Dockerfile - `nodejs-app`,
`python-app`, `java-app`, `Apache-app`, `React-app`, `nginx-app`. All six built, run and verified.

### [06: Dockerfiles & Images](06-dockerfiles-and-images/)
The multi-stage Dockerfile built and running on port 8080, `docker ps` evidence, and a
measured size comparison: the same React app is **411 MB** single-stage vs **102 MB** multi-stage.

### [07: Docker Networking & Volumes](07-docker-networking-volumes/)
Three containers across three networks with the backend on two of them (and proof the frontend
cannot reach the database), Apache on the host network, a live bind mount, and a real
overlay network on a temporary swarm.

### [08: Kubernetes Ingress, ConfigMaps & Secrets](08-k8s-ingress-configmaps-secrets/)
The full Session 12 lab on minikube: ConfigMap and Secret injected into the same pod via `envFrom`
and `secretKeyRef`, two `ClusterIP` services exposed through one NGINX Ingress with path-based
routing, the `echo` vs `echo -n` newline bug shown byte-for-byte with `od -c`, and a rolling
restart proving env vars are frozen at container start. Plus the bonus host-based routing + TLS
task - including the self-signed cert that silently fails because it has no SAN.

### [09: Kubernetes Fundamentals](09-k8s-fundamentals/)
The minikube cluster and what every control-plane component in `kube-system` actually does, traced
through a single pod's Events block (scheduler assigns, kubelet pulls/creates/starts). Then the
contrast that explains the rest of Kubernetes: a bare Pod deleted is gone, a Deployment's Pod comes
back as a **new** pod - and the Deployment → ReplicaSet → Pod ownership chain that makes it happen.

### [10: Kubernetes Pods, ReplicaSets & Deployments](10-k8s-core-objects/)
All 12 pod lifecycle states reproduced and diagnosed, ReplicaSet vs Deployment (`rollout history`
fails outright on a ReplicaSet), DaemonSet, and a StatefulSet proving stable identity by surviving
pod deletion with its data intact. Plus all four rollout strategies with the numbers measured:
Recreate's outage caught at `running=0`, and canary's real split at **16/200 requests**.

### [11: Kubernetes Networking & Services](11-k8s-services/)
All five service types. ClusterIP resolving to one VIP vs headless resolving to all three pod IPs,
NodePort as a superset of ClusterIP, LoadBalancer correctly stuck at `<pending>` with no cloud
controller, ExternalName as a pure CNAME with no endpoints at all - and the empty-endpoints
selector bug that Kubernetes accepts without a word of complaint.

---

## Environment used

| | |
|---|---|
| Docker | 28.4.0 |
| Linux used for Linux/networking tasks | Ubuntu 22.04.5 LTS |
| Node.js | 20 (alpine) / 24 (alpine) |
| Python | 3.12 |
| Java | Eclipse Temurin 21 |
| minikube / Kubernetes | v1.39.0 / v1.37.0 (docker driver) |
| kubectl | 1.37.0 |
