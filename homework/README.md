# DevOps Homework — Talin Daga

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com
**Repository:** <https://github.com/Talin12/devops-heros>

All homework from the DevOps Heroes sessions, one folder per topic. Every command in every
README was **actually executed** and the output pasted verbatim — no invented output.

---

## Submissions (Section B — Google Form)

| # | Topic | Session | README to submit |
|---|---|---|---|
| 1 | **Linux Fundamentals** | Session 2 | [`01-linux-fundamentals/README.md`](01-linux-fundamentals/README.md) |
| 2 | **Shell Scripting** | Session 3 | [`02-shell-scripting/README.md`](02-shell-scripting/README.md) |
| 3 | **Networking** | Session 4 | [`03-networking/README.md`](03-networking/README.md) |
| 4 | **Git and GitHub** | Session 5 | [`04-git-github/README.md`](04-git-github/README.md) |
| 5 | **Docker Fundamentals** | Sessions 6–7 | [`05-docker-fundamentals/README.md`](05-docker-fundamentals/README.md) |
| 6 | **Docker Images / Dockerfiles** | Sessions 6–7 | [`06-dockerfiles-and-images/README.md`](06-dockerfiles-and-images/README.md) |
| 7 | **Docker Networking** | Session 8 | [`07-docker-networking-volumes/README.md`](07-docker-networking-volumes/README.md) |

---

## What each folder contains

### [01 — Linux Fundamentals](01-linux-fundamentals/)
Soft links vs hard links (inodes, link counts, what breaks when the original is deleted),
`adduser` vs `useradd` and which one Ubuntu prefers, `journalctl` run against a real systemd
system, and a worked Linux command cheat sheet. Plus interview Q&A.

### [02 — Shell Scripting](02-shell-scripting/)
`system_info.sh` — prints date, hostname, username, disk usage and processes, uses variables,
takes input with `read -p`, creates a directory and file, and saves `ps aux` into it with `>`.

### [03 — Networking](03-networking/)
Thirteen networking commands (`ip a`, `ip route`, `ping`, `traceroute`, `dig`, `ss`, `curl`,
`nc`, `arp`, `whois`, `tcpdump`, …) each with real output and an explanation of what it means,
plus IP classes, private ranges, subnetting and a troubleshooting order.

### [04 — Git and GitHub](04-git-github/)
`git commit -m` vs `git commit -a -m` demonstrated to the point where `-a` visibly refuses an
untracked file, and a full cherry-pick walkthrough with before/after proof.

### [05 — Docker Fundamentals](05-docker-fundamentals/)
Six Hello World web apps, each in its own folder with its own Dockerfile — `nodejs-app`,
`python-app`, `java-app`, `Apache-app`, `React-app`, `nginx-app`. All six built, run and verified.

### [06 — Dockerfiles & Images](06-dockerfiles-and-images/)
The multi-stage Dockerfile built and running on **port 8080**, `docker ps` evidence, and a
measured size comparison: the same React app is **411 MB** single-stage vs **102 MB** multi-stage.

### [07 — Docker Networking & Volumes](07-docker-networking-volumes/)
Three containers across three networks with the backend on two of them (and proof the frontend
**cannot** reach the database), Apache on the host network, a live bind mount, and a real
overlay network on a temporary swarm.

---

## Environment used

| | |
|---|---|
| Docker | 28.4.0 |
| Linux used for Linux/networking tasks | Ubuntu 22.04.5 LTS |
| Node.js | 20 (alpine) / 24 (alpine) |
| Python | 3.12 |
| Java | Eclipse Temurin 21 |
