# Linux Fundamentals: Homework (Session 2)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

> Every command below was actually executed on Ubuntu 22.04 LTS and the output pasted verbatim.

---

## Table of Contents
1. [Task 1 - Soft Link vs Hard Link](#task-1-soft-link-vs-hard-link)
2. [Task 2 - `adduser` vs `useradd`](#task-2-adduser-vs-useradd)
3. [Task 3 - `journalctl`](#task-3-journalctl)
4. [Task 4 - Linux Command Cheat Sheet](#task-4-linux-command-cheat-sheet)
5. [Interview Questions & Answers](#interview-questions--answers)

---

## Task 1: Soft Link vs Hard Link

### Theory

A file on Linux is really two things:
* the inode - the actual metadata + pointers to the data blocks on disk
* the directory entry (filename) - a label that points at an inode

| | Hard Link | Soft Link (Symbolic Link) |
|---|---|---|
| Command | `ln target linkname` | `ln -s target linkname` |
| What it points to | the inode (the data itself) | the pathname (a string) |
| Inode number | same as the original | its own new inode |
| Link count (`ls -l` 2nd column) | increases (2, 3, ...) | stays 1 |
| If the original is deleted | link still works - data survives | link breaks (dangling) |
| Across filesystems / partitions | ❌ not allowed | ✅ allowed |
| Point to a directory | ❌ not allowed | ✅ allowed |
| Size shown by `ls -l` | size of the file | length of the target path string |
| File type in `ls -l` | `-` (regular file) | `l` (link) |

### Commands

```bash
# create a hard link
ln original.txt hardlink.txt

# create a soft/symbolic link
ln -s original.txt softlink.txt

# see inode numbers and link counts
ls -li
stat original.txt

# delete a link (never use rm -r on a symlinked directory)
rm hardlink.txt
rm softlink.txt
unlink softlink.txt
```

### Practical: commands and output

```console
########## TASK 1 : SOFT LINK (symlink) vs HARD LINK ##########

$ cat /etc/os-release | head -2
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"

$ echo 'Hello from the original file' > original.txt

$ cat original.txt
Hello from the original file

--- create a HARD link ---

$ ln original.txt hardlink.txt

--- create a SOFT link ---

$ ln -s original.txt softlink.txt

$ ls -li
total 8
1038958 -rw-r--r-- 2 root root 29 Sep  3 09:28 hardlink.txt
1038958 -rw-r--r-- 2 root root 29 Sep  3 09:28 original.txt
1038972 lrwxrwxrwx 1 root root 12 Sep  3 09:28 softlink.txt -> original.txt

NOTE: original.txt and hardlink.txt share the SAME inode number and link count 2.
      softlink.txt has its OWN inode and points to 'original.txt'.

$ stat -c '%n -> inode:%i links:%h size:%s type:%F' original.txt hardlink.txt softlink.txt
original.txt -> inode:1038958 links:2 size:29 type:regular file
hardlink.txt -> inode:1038958 links:2 size:29 type:regular file
softlink.txt -> inode:1038972 links:1 size:12 type:symbolic link

--- editing through one link changes the same data ---

$ echo 'A second line added via the hard link' >> hardlink.txt

$ cat original.txt
Hello from the original file
A second line added via the hard link

$ cat softlink.txt
Hello from the original file
A second line added via the hard link

--- DELETE the original file and see what happens ---

$ rm original.txt

$ ls -l
total 4
-rw-r--r-- 1 root root 67 Sep  3 09:28 hardlink.txt
lrwxrwxrwx 1 root root 12 Sep  3 09:28 softlink.txt -> original.txt

$ cat hardlink.txt
Hello from the original file
A second line added via the hard link

Hard link still works - the data is alive because a directory entry still points to the inode.

$ cat softlink.txt
cat: softlink.txt: No such file or directory

Soft link is now BROKEN (dangling) - it pointed to a NAME that no longer exists.

$ ls -l softlink.txt
lrwxrwxrwx 1 root root 12 Sep  3 09:28 softlink.txt -> original.txt

--- soft link across filesystems / to a directory (hard links cannot do this) ---

$ mkdir -p /root/mydir

$ ln -s /root/mydir dirlink

$ ls -ld dirlink
lrwxrwxrwx 1 root root 11 Sep  3 09:28 dirlink -> /root/mydir

$ ln /root/mydir dirhardlink
ln: /root/mydir: hard link not allowed for directory

^ hard link to a directory is NOT permitted.

--- cleanup ---

$ rm -f softlink.txt dirlink hardlink.txt; rmdir mydir; ls -l
total 0
```

### What the output proves

* `original.txt` and `hardlink.txt` both show inode 1038958 and link count 2 - they are two names for one file.
* `softlink.txt` has its own inode 1038972, type `symbolic link`, and size 12 (= the number of characters in the string `original.txt`).
* Appending through `hardlink.txt` changed what `original.txt` shows - same data, same inode.
* After `rm original.txt`: `cat hardlink.txt` still works, `cat softlink.txt` gives No such file or directory - the soft link is now dangling.
* `ln /root/mydir dirhardlink` -> hard link not allowed for directory, while `ln -s` on a directory works fine.

---

## Task 2: `adduser` vs `useradd`

### Theory

| | `useradd` | `adduser` |
|---|---|---|
| Type | low-level binary (`/usr/sbin/useradd`, part of `shadow-utils`) | high-level Perl script that wraps `useradd` |
| Available on | every Linux distro (RHEL, CentOS, Ubuntu, Debian, Alpine...) | Debian / Ubuntu family |
| Home directory | not created unless you pass `-m` | created automatically |
| `/etc/skel` dotfiles copied | only with `-m` | automatically |
| Shell | distro default (often `/bin/sh`) unless `-s` is passed | `/bin/bash` |
| Password | not set (account locked) | prompts interactively |
| User group | needs flags | creates a matching group automatically |
| Interactive | no | yes (asks for password, full name, phone...) |
| Config file | `/etc/default/useradd`, `/etc/login.defs` | `/etc/adduser.conf` |

### Which one is preferred on Ubuntu, and why

`adduser` is preferred on Ubuntu/Debian. It is the friendly, interactive front-end that does all the right things in one step - creates the home directory, copies the `/etc/skel` skeleton files (`.bashrc`, `.profile`, `.bash_logout`), sets `/bin/bash` as the login shell, creates a matching user-private group, and prompts for a password. With plain `useradd` you get a half-configured account unless you remember every flag, which is a very common source of "why can't the new user log in?" tickets.

`useradd` is still the right choice inside scripts and Dockerfiles, and on RHEL/CentOS where `adduser` may not exist (there it is often just a symlink to `useradd`).

### Commands

```bash
# recommended way on Ubuntu
sudo adduser testuser

# non-interactive variant (used below, for scripting)
sudo adduser --disabled-password --gecos '' testuser3

# low-level equivalent, done properly
sudo useradd -m -s /bin/bash -c "Full Name" testuser2

# verify
grep testuser /etc/passwd
id testuser
ls -ld /home/testuser

# delete
sudo deluser --remove-home testuser      # Debian/Ubuntu
sudo userdel -r testuser                 # portable
```

### Practical: commands and output

```console
########## TASK 2 : adduser vs useradd ##########

$ which adduser useradd
/usr/sbin/adduser
/usr/sbin/useradd

$ ls -l /usr/sbin/adduser /usr/sbin/useradd
-rwxr-xr-x 1 root root  38247 Jan  6  2021 /usr/sbin/adduser
-rwxr-xr-x 1 root root 126152 Feb  6  2024 /usr/sbin/useradd

$ head -1 /usr/sbin/adduser
#!/usr/bin/perl

--- 1) useradd : LOW-LEVEL binary. Bare minimum, no home dir, no password, no shell ---

$ useradd testuser1

$ grep testuser1 /etc/passwd
testuser1:x:1000:1000::/home/testuser1:/bin/sh

$ ls /home

^ NOTE: no /home/testuser1 was created, shell is empty, account has no password (locked).

$ passwd -S testuser1
testuser1 L 09/03/2026 0 99999 7 -1

--- useradd done properly needs many flags ---

$ useradd -m -s /bin/bash -c 'Manual user' testuser2

$ grep testuser2 /etc/passwd
testuser2:x:1001:1001:Manual user:/home/testuser2:/bin/bash

$ ls -ld /home/testuser2
drwxr-x--- 2 testuser2 testuser2 4096 Sep  3 09:28 /home/testuser2

--- 2) adduser : HIGH-LEVEL Perl script (RECOMMENDED on Ubuntu/Debian) ---

$ head -5 /usr/sbin/adduser
#!/usr/bin/perl

# adduser: a utility to add users to the system
# addgroup: a utility to add groups to the system


$ adduser --disabled-password --gecos '' testuser3
Adding user `testuser3' ...
Adding new group `testuser3' (1002) ...
Adding new user `testuser3' (1002) with group `testuser3' ...
Creating home directory `/home/testuser3' ...
Copying files from `/etc/skel' ...

$ grep testuser3 /etc/passwd
testuser3:x:1002:1002:,,,:/home/testuser3:/bin/bash

$ ls -ld /home/testuser3
drwxr-x--- 2 testuser3 testuser3 4096 Sep  3 09:28 /home/testuser3

$ ls -a /home/testuser3
.
..
.bash_logout
.bashrc
.profile

$ groups testuser3
testuser3 : testuser3

^ adduser automatically: created /home/testuser3, copied /etc/skel dotfiles,
  set /bin/bash as shell and created a matching user group.

--- compare the three users ---

$ tail -3 /etc/passwd
testuser1:x:1000:1000::/home/testuser1:/bin/sh
testuser2:x:1001:1001:Manual user:/home/testuser2:/bin/bash
testuser3:x:1002:1002:,,,:/home/testuser3:/bin/bash

--- deleting users ---

$ userdel -r testuser3
userdel: testuser3 mail spool (/var/mail/testuser3) not found

$ userdel -r testuser2
userdel: testuser2 mail spool (/var/mail/testuser2) not found

$ userdel testuser1

$ tail -3 /etc/passwd
gnats:x:41:41:Gnats Bug-Reporting System (admin):/var/lib/gnats:/usr/sbin/nologin
nobody:x:65534:65534:nobody:/nonexistent:/usr/sbin/nologin
_apt:x:100:65534::/nonexistent:/usr/sbin/nologin
```

### What the output proves

* `useradd testuser1` -> the account exists in `/etc/passwd` but `/home` is empty, the shell is `/bin/sh`, and `passwd -S` reports `L` (locked, no password).
* `useradd -m -s /bin/bash` -> now the home directory exists, but every behaviour had to be requested with a flag.
* `adduser` -> printed exactly what it did: created the group, created the user, created the home directory, and copied files from `/etc/skel` (`ls -a` shows `.bashrc`, `.profile`, `.bash_logout`). Shell is `/bin/bash` with zero extra flags.
* `head -1 /usr/sbin/adduser` shows `#!/usr/bin/perl` - proof that `adduser` is a script, whereas `useradd` is a compiled binary (126 KB vs 38 KB in `ls -l`).

---

## Task 3: `journalctl`

### What journalctl is used for

`journalctl` is the query tool for the systemd journal. On a systemd machine, `systemd-journald` collects logs from *everything* in one indexed, binary store:

* kernel messages (what `dmesg` shows)
* boot messages from early boot onwards
* stdout / stderr of every systemd service
* anything sent to syslog
* structured audit records

Instead of hunting through `/var/log/syslog`, `/var/log/nginx/error.log`, `/var/log/auth.log` etc., you ask one tool and filter by unit, time, priority or boot. That is why it is the first command you reach for when a service fails to start.

### The commands that matter

| Command | What it does |
|---|---|
| `journalctl` | all logs, oldest first |
| `journalctl -n 50` | last 50 lines |
| `journalctl -f` | follow live, like `tail -f` |
| `journalctl -u nginx` | logs of one service/unit |
| `journalctl -u nginx -f` | live logs of one service ← the everyday one |
| `journalctl -u nginx --since "1 hour ago"` | time-window filter |
| `journalctl -p err` | only priority *error* and worse |
| `journalctl -p warning..err` | a priority range |
| `journalctl -b` | logs of the current boot only |
| `journalctl -b -1` | logs of the previous boot (why did it crash?) |
| `journalctl --list-boots` | all recorded boots |
| `journalctl -k` | kernel messages only (`dmesg` equivalent) |
| `journalctl --since today` / `--since "2026-09-03 09:00"` | time filters |
| `journalctl -o json-pretty` | structured output for scripts / log shippers |
| `journalctl --disk-usage` | how much disk the journal eats |
| `journalctl --vacuum-time=2d` / `--vacuum-size=500M` | prune old journals |
| `journalctl _PID=1234` | filter by any journal field |

**Priority levels:** `0 emerg, 1 alert, 2 crit, 3 err, 4 warning, 5 notice, 6 info, 7 debug`

### Practical: commands and output

Run on a real systemd system (systemd is PID 1), checking the logs of the nginx service:

```console
########## TASK 3 : journalctl ##########

(running on a real systemd system - Ubuntu 22.04 with systemd as PID 1)

$ systemctl is-system-running
running

$ ps -p 1 -o pid,comm
    PID COMMAND
      1 systemd

===== 1. What journalctl is: the query tool for the systemd journal =====

$ journalctl --version | head -1
systemd 249 (249.11-0ubuntu3.22)

===== 2. Show the most recent log lines ====== 

$ journalctl -n 10 --no-pager
Sep 03 09:30:16 c737b4436fd2 kernel: vetha094e98 (unregistering): left allmulticast mode
Sep 03 09:30:16 c737b4436fd2 kernel: vetha094e98 (unregistering): left promiscuous mode
Sep 03 09:30:16 c737b4436fd2 kernel: docker0: port 1(vetha094e98) entered disabled state
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered blocking state
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered disabled state
Sep 03 09:30:24 c737b4436fd2 kernel: vethf633f08: entered allmulticast mode
Sep 03 09:30:24 c737b4436fd2 kernel: vethf633f08: entered promiscuous mode
Sep 03 09:30:24 c737b4436fd2 kernel: eth0: renamed from veth9f6a0a4
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered blocking state
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered forwarding state

===== 3. Logs for ONE specific service (nginx) =====

$ systemctl restart nginx

$ systemctl status nginx --no-pager | head -12
● nginx.service - A high performance web server and a reverse proxy server
     Loaded: loaded (/lib/systemd/system/nginx.service; enabled; vendor preset: enabled)
     Active: active (running) since Thu 2026-09-03 09:30:27 UTC; 2ms ago
       Docs: man:nginx(8)
    Process: 102 ExecStartPre=/usr/sbin/nginx -t -q -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
    Process: 103 ExecStart=/usr/sbin/nginx -g daemon on; master_process on; (code=exited, status=0/SUCCESS)
   Main PID: 104 (nginx)
      Tasks: 11 (limit: 9397)
     Memory: 10.2M
        CPU: 23ms
     CGroup: /docker/c737b4436fd2cc66c297a0ff38f2ea64511ba30e45d775ba310cd2ee801e2bf1/system.slice/nginx.service
             ├─104 "nginx: master process /usr/sbin/nginx -g daemon on; master_process on;"

$ journalctl -u nginx --no-pager
Sep 03 09:30:09 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:09 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopping A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: nginx.service: Deactivated successfully.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.

===== 4. Only the errors (priority filter) =====

$ journalctl -p err --no-pager -n 10
-- No entries --

$ journalctl -p warning..err --no-pager -n 5
-- No entries --

===== 5. Time based filtering =====

$ journalctl --since '10 minutes ago' --no-pager -n 5
Sep 03 09:30:09 c737b4436fd2 systemd-journald[24]: Missed 19398 kernel messages
Sep 03 09:30:09 c737b4436fd2 kernel: br-4db74f7747dc: port 1(veth974330a) entered blocking state
Sep 03 09:30:09 c737b4436fd2 kernel: br-4db74f7747dc: port 1(veth974330a) entered disabled state
Sep 03 09:30:09 c737b4436fd2 kernel: veth974330a: entered allmulticast mode
Sep 03 09:30:09 c737b4436fd2 kernel: veth974330a: entered promiscuous mode

$ journalctl --since today --no-pager -n 3
Sep 03 09:30:09 c737b4436fd2 systemd-journald[24]: Missed 19398 kernel messages
Sep 03 09:30:09 c737b4436fd2 kernel: br-4db74f7747dc: port 1(veth974330a) entered blocking state
Sep 03 09:30:09 c737b4436fd2 kernel: br-4db74f7747dc: port 1(veth974330a) entered disabled state

===== 6. Current boot only =====

$ journalctl -b --no-pager -n 5
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopping A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: nginx.service: Deactivated successfully.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.

$ journalctl --list-boots --no-pager
 0 a1331b1218234644a3ccb7e3e1dbc7ad Thu 2026-09-03 09:30:09 UTC—Thu 2026-09-03 09:30:27 UTC

===== 7. Kernel messages only (like dmesg) =====

$ journalctl -k --no-pager -n 5
Sep 03 09:30:24 c737b4436fd2 kernel: vethf633f08: entered allmulticast mode
Sep 03 09:30:24 c737b4436fd2 kernel: vethf633f08: entered promiscuous mode
Sep 03 09:30:24 c737b4436fd2 kernel: eth0: renamed from veth9f6a0a4
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered blocking state
Sep 03 09:30:24 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered forwarding state

===== 8. Output formats (useful for scripting / log shipping) =====

$ journalctl -u nginx -n 1 -o json-pretty --no-pager
{
	"MESSAGE" : "Started A high performance web server and a reverse proxy server.",
	"_UID" : "0",
	"SYSLOG_FACILITY" : "3",
	"JOB_ID" : "84",
	"_PID" : "1",
	"_SYSTEMD_CGROUP" : "/init.scope",
	"__MONOTONIC_TIMESTAMP" : "47587643702",
	"_SOURCE_REALTIME_TIMESTAMP" : "1788427827719572",
	"_SYSTEMD_UNIT" : "init.scope",
	"_EXE" : "/usr/lib/systemd/systemd",
	"_TRANSPORT" : "journal",
	"SYSLOG_IDENTIFIER" : "systemd",
	"_COMM" : "systemd",
	"MESSAGE_ID" : "39f53479d3a045ac8e11786248231fbf",
	"_CAP_EFFECTIVE" : "1ffffffffff",
	"_BOOT_ID" : "a1331b1218234644a3ccb7e3e1dbc7ad",
	"TID" : "1",
	"INVOCATION_ID" : "773931b0c2f64761a3ba771a68807aa8",
	"_GID" : "0",
	"JOB_RESULT" : "done",
	"PRIORITY" : "6",
	"__CURSOR" : "s=4ecb48376cbb4be59fa9d05d88ab0c8c;i=8b2;b=a1331b1218234644a3ccb7e3e1dbc7ad;m=b1471d136;t=65a90cd60aded;x=57a176b82ae96de8",
	"JOB_TYPE" : "start",
	"_HOSTNAME" : "c737b4436fd2",
	"CODE_LINE" : "713",
	"__REALTIME_TIMESTAMP" : "1788427827719661",
	"CODE_FUNC" : "job_emit_done_message",
	"_MACHINE_ID" : "2e931a01e1e242179a9c3dc6872d091d",
	"_CMDLINE" : "/sbin/init",
	"_SYSTEMD_SLICE" : "-.slice",
	"UNIT" : "nginx.service",
	"CODE_FILE" : "src/core/job.c"
}

$ journalctl -u nginx -n 3 -o short-iso --no-pager
2026-09-03T09:30:27+0000 c737b4436fd2 systemd[1]: Stopped A high performance web server and a reverse proxy server.
2026-09-03T09:30:27+0000 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
2026-09-03T09:30:27+0000 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.

===== 9. How much disk the journal is using + cleanup =====

$ journalctl --disk-usage
Archived and active journals take up 8.0M in the file system.

$ journalctl --vacuum-time=2d
Vacuuming done, freed 0B of archived journals from /var/log/journal.
Vacuuming done, freed 0B of archived journals from /var/log/journal/2e931a01e1e242179a9c3dc6872d091d.
Vacuuming done, freed 0B of archived journals from /run/log/journal.

===== 10. Live follow (tail -f equivalent) =====

$ journalctl -u nginx -f      # runs forever, Ctrl+C to stop
Sep 03 09:30:09 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:09 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopping A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: nginx.service: Deactivated successfully.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.

$ journalctl -f --no-pager -n 3 & sleep 2; systemctl restart nginx; sleep 2; kill %1
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:27 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.
Sep 03 09:30:31 c737b4436fd2 systemd-resolved[45]: Clock change detected. Flushing caches.
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered disabled state
Sep 03 09:30:32 c737b4436fd2 kernel: veth9f6a0a4: renamed from eth0
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered disabled state
Sep 03 09:30:32 c737b4436fd2 kernel: vethf633f08 (unregistering): left allmulticast mode
Sep 03 09:30:32 c737b4436fd2 kernel: vethf633f08 (unregistering): left promiscuous mode
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethf633f08) entered disabled state
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered blocking state
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered disabled state
Sep 03 09:30:32 c737b4436fd2 kernel: vethdc9e733: entered allmulticast mode
Sep 03 09:30:32 c737b4436fd2 kernel: vethdc9e733: entered promiscuous mode
Sep 03 09:30:32 c737b4436fd2 kernel: eth0: renamed from vetha2e8328
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered blocking state
Sep 03 09:30:32 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered forwarding state
Sep 03 09:30:33 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered disabled state
Sep 03 09:30:33 c737b4436fd2 kernel: vetha2e8328: renamed from eth0
Sep 03 09:30:33 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered disabled state
Sep 03 09:30:33 c737b4436fd2 kernel: vethdc9e733 (unregistering): left allmulticast mode
Sep 03 09:30:33 c737b4436fd2 kernel: vethdc9e733 (unregistering): left promiscuous mode
Sep 03 09:30:33 c737b4436fd2 kernel: docker0: port 1(vethdc9e733) entered disabled state
Sep 03 09:30:33 c737b4436fd2 systemd[1]: Stopping A high performance web server and a reverse proxy server...
Sep 03 09:30:33 c737b4436fd2 systemd[1]: nginx.service: Deactivated successfully.
Sep 03 09:30:33 c737b4436fd2 systemd[1]: Stopped A high performance web server and a reverse proxy server.
Sep 03 09:30:33 c737b4436fd2 systemd[1]: Starting A high performance web server and a reverse proxy server...
Sep 03 09:30:33 c737b4436fd2 systemd[1]: Started A high performance web server and a reverse proxy server.
```

### What the output proves

* `ps -p 1 -o comm` -> systemd is PID 1, so the journal is live.
* `journalctl -u nginx` shows the full lifecycle of one service - *Starting -> Started -> Stopping -> Deactivated successfully -> Stopped -> Starting -> Started* - which is exactly how you confirm a restart actually happened.
* `journalctl -p err` returned `-- No entries --`: no errors on the box, which is itself a useful answer.
* `--list-boots` shows the current boot ID and its time window.
* `-o json-pretty` shows the journal is structured: every entry carries `_SYSTEMD_UNIT`, `_PID`, `PRIORITY`, `_HOSTNAME`, `MESSAGE_ID` etc. - that is what makes filtering fast and what log shippers consume.
* `journalctl -f` streamed the nginx restart live while it was happening.

---

## Task 4: Linux Command Cheat Sheet

### Reference table

| Category | Command | Purpose |
|---|---|---|
| Identity | `whoami`, `id`, `who`, `w` | current user, UID/GID, who is logged in |
| System | `uname -a`, `cat /etc/os-release`, `uptime`, `hostname` | kernel, distro, uptime, hostname |
| Navigation | `pwd`, `cd`, `ls -la`, `tree` | where am I, list files with permissions |
| Files | `touch`, `cp`, `mv`, `rm`, `mkdir -p`, `rmdir` | create / copy / move / delete |
| Reading | `cat`, `less`, `head -n`, `tail -n`, `tail -f`, `wc -l` | view file contents |
| Search | `grep -rn`, `find / -name`, `which`, `locate` | find text and find files |
| Permissions | `chmod`, `chown`, `chgrp`, `umask` | who can read/write/execute |
| Processes | `ps aux`, `ps -ef`, `top`, `htop`, `kill -9`, `pkill`, `jobs`, `bg`, `fg` | inspect and control processes |
| Disk / memory | `df -h`, `du -sh`, `free -h`, `lsblk`, `mount` | space and RAM |
| Archives | `tar -czf`, `tar -xzf`, `tar -tzf`, `zip`, `unzip`, `gzip` | pack and unpack |
| Text processing | `cut`, `sort`, `uniq -c`, `awk`, `sed`, `tr`, `xargs` | the classic pipeline toolkit |
| Networking | `ip a`, `ping`, `curl`, `ss -tuln`, `dig`, `netstat` | see the [Networking homework](../03-networking/README.md) |
| Users | `adduser`, `useradd`, `passwd`, `usermod -aG`, `groups`, `su`, `sudo` | account management |
| Services | `systemctl status/start/stop/restart/enable`, `journalctl -u` | manage daemons |
| Packages | `apt update`, `apt install`, `dpkg -l`, `apt list --installed` | software on Debian/Ubuntu |
| Environment | `echo $PATH`, `export VAR=x`, `env`, `history`, `alias` | shell environment |
| Redirection | `>`, `>>`, `2>`, `&>`, `\|`, `tee` | send output where you want it |

### Permission numbers (asked in almost every interview)

```
r = 4 (read)   w = 2 (write)   x = 1 (execute)

chmod 754 file
       │││
       ││└── others : 4 = r--
       │└─── group  : 5 = r-x
       └──── owner  : 7 = rwx
```

### Practical: commands and output

```console
########## TASK 4 : LINUX COMMAND CHEAT SHEET - PRACTICE ##########

===== A. Where am I / who am I =====

$ whoami
root

$ id
uid=0(root) gid=0(root) groups=0(root)

$ hostname
70daeb4cf098

$ uname -a
Linux 70daeb4cf098 6.10.14-linuxkit #1 SMP Wed Sep 10 06:47:45 UTC 2025 aarch64 aarch64 aarch64 GNU/Linux

$ cat /etc/os-release | head -3
PRETTY_NAME="Ubuntu 22.04.5 LTS"
NAME="Ubuntu"
VERSION_ID="22.04"

$ pwd
/

$ date
Thu Sep  3 09:29:15 UTC 2026

$ uptime
 09:29:15 up 13:11,  0 users,  load average: 1.73, 1.00, 0.69

===== B. Files & directories =====

$ mkdir -p demo/project/logs

$ touch demo/a.txt demo/b.txt demo/c.log && ls -l demo
total 4
-rw-r--r-- 1 root root    0 Sep  3 09:29 a.txt
-rw-r--r-- 1 root root    0 Sep  3 09:29 b.txt
-rw-r--r-- 1 root root    0 Sep  3 09:29 c.log
drwxr-xr-x 3 root root 4096 Sep  3 09:29 project

$ ls -la demo
total 12
drwxr-xr-x 3 root root 4096 Sep  3 09:29 .
drwxr-xr-x 1 root root 4096 Sep  3 09:29 ..
-rw-r--r-- 1 root root    0 Sep  3 09:29 a.txt
-rw-r--r-- 1 root root    0 Sep  3 09:29 b.txt
-rw-r--r-- 1 root root    0 Sep  3 09:29 c.log
drwxr-xr-x 3 root root 4096 Sep  3 09:29 project

$ find demo -print
demo
demo/a.txt
demo/project
demo/project/logs
demo/b.txt
demo/c.log

$ echo 'DevOps Hero - Talin Daga' > demo/a.txt

$ cat demo/a.txt
DevOps Hero - Talin Daga

$ cp demo/a.txt demo/a_copy.txt && ls demo
a.txt
a_copy.txt
b.txt
c.log
project

$ mv demo/b.txt demo/renamed.txt && ls demo
a.txt
a_copy.txt
c.log
project
renamed.txt

$ rm demo/c.log && ls demo
a.txt
a_copy.txt
project
renamed.txt

===== C. Viewing file content =====

$ seq 1 20 > demo/numbers.txt

$ head -5 demo/numbers.txt
1
2
3
4
5

$ tail -5 demo/numbers.txt
16
17
18
19
20

$ wc -l demo/numbers.txt
20 demo/numbers.txt

$ cat -n demo/a.txt
     1	DevOps Hero - Talin Daga

===== D. Searching =====

$ grep -n 'DevOps' demo/a.txt
1:DevOps Hero - Talin Daga

$ grep -rn 'Hero' demo/
demo/a.txt:1:DevOps Hero - Talin Daga
demo/a_copy.txt:1:DevOps Hero - Talin Daga

$ find / -name 'passwd' -maxdepth 3 2>/dev/null
/usr/bin/passwd
/etc/passwd
/etc/pam.d/passwd

$ which bash ls grep
/usr/bin/bash
/usr/bin/ls
/usr/bin/grep

===== E. Permissions & ownership =====

$ ls -l demo/a.txt
-rw-r--r-- 1 root root 25 Sep  3 09:29 demo/a.txt

$ chmod 754 demo/a.txt && ls -l demo/a.txt
-rwxr-xr-- 1 root root 25 Sep  3 09:29 demo/a.txt

$ chmod u+x,g-r demo/a.txt && ls -l demo/a.txt
-rwx--xr-- 1 root root 25 Sep  3 09:29 demo/a.txt

$ chown root:root demo/a.txt && ls -l demo/a.txt
-rwx--xr-- 1 root root 25 Sep  3 09:29 demo/a.txt

  rwx = 4(read)+2(write)+1(execute) ; 754 => owner rwx, group r-x, others r--

===== F. Processes =====

$ ps aux | head -5
USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root         1  0.0  0.0   3876  2608 ?        Ss   09:29   0:00 bash /linux4.sh
root        42  0.0  0.0   6444  2372 ?        R    09:29   0:00 ps aux
root        43  0.0  0.0   2236   840 ?        S    09:29   0:00 head -5

$ ps -ef | head -5
UID        PID  PPID  C STIME TTY          TIME CMD
root         1     0  0 09:29 ?        00:00:00 bash /linux4.sh
root        44     1  0 09:29 ?        00:00:00 ps -ef
root        45     1  0 09:29 ?        00:00:00 head -5

$ sleep 300 & echo 'started background job with PID:' $!
started background job with PID: 46

$ ps -ef | grep sleep | grep -v grep
root        46     1  0 09:29 ?        00:00:00 sleep 300

$ pkill sleep ; echo 'sleep killed'
sleep killed

===== G. Disk & memory =====

$ df -h
Filesystem              Size  Used Avail Use% Mounted on
overlay                 224G   25G  188G  12% /
tmpfs                    64M     0   64M   0% /dev
shm                      64M     0   64M   0% /dev/shm
/run/host_mark/private  229G  198G   31G  87% /linux4.sh
/dev/vda1               224G   25G  188G  12% /etc/hosts
tmpfs                   3.9G     0  3.9G   0% /proc/scsi
tmpfs                   3.9G     0  3.9G   0% /sys/firmware

$ du -sh demo
24K	demo

$ free -h
               total        used        free      shared  buff/cache   available
Mem:           7.7Gi       924Mi       3.2Gi        45Mi       3.5Gi       6.5Gi
Swap:          1.0Gi          0B       1.0Gi

===== H. Networking (quick) =====

$ cat /etc/hosts
127.0.0.1	localhost
::1	localhost ip6-localhost ip6-loopback
fe00::	ip6-localnet
ff00::	ip6-mcastprefix
ff02::1	ip6-allnodes
ff02::2	ip6-allrouters
172.17.0.3	70daeb4cf098

$ cat /etc/resolv.conf
# Generated by Docker Engine.
# This file can be edited; Docker Engine will not make further changes once it
# has been modified.

nameserver 192.168.65.7

# Based on host file: '/etc/resolv.conf' (legacy)
# Overrides: []

===== I. Archiving & compression =====

$ tar -czf demo.tar.gz demo && ls -lh demo.tar.gz
-rw-r--r-- 1 root root 319 Sep  3 09:29 demo.tar.gz

$ tar -tzf demo.tar.gz | head -5
demo/
demo/a.txt
demo/project/
demo/project/logs/
demo/numbers.txt

$ mkdir -p restored && tar -xzf demo.tar.gz -C restored && ls restored/demo
a.txt
a_copy.txt
numbers.txt
project
renamed.txt

===== J. Text processing =====

$ cut -d: -f1,3 /etc/passwd | head -5
root:0
daemon:1
bin:2
sys:3
sync:4

$ sort -r demo/numbers.txt | head -3
9
8
7

$ awk -F: '{print $1" has UID "$3}' /etc/passwd | head -5
root has UID 0
daemon has UID 1
bin has UID 2
sys has UID 3
sync has UID 4

$ sed 's/DevOps/CloudOps/' demo/a.txt
CloudOps Hero - Talin Daga

$ echo 'apple banana apple cherry banana apple' | tr ' ' '\n' | sort | uniq -c | sort -nr
      3 apple
      2 banana
      1 cherry

===== K. Environment & history =====

$ echo $HOME
/root

$ echo $PATH
/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin

$ export MY_VAR='hello devops' && echo $MY_VAR
hello devops

$ env | head -5
HOSTNAME=70daeb4cf098
PWD=/
HOME=/root
MY_VAR=hello devops
SHLVL=0

===== L. Package management (Debian/Ubuntu) =====

$ dpkg -l | head -6
Desired=Unknown/Install/Remove/Purge/Hold
| Status=Not/Inst/Conf-files/Unpacked/halF-conf/Half-inst/trig-aWait/Trig-pend
|/ Err?=(none)/Reinst-required (Status,Err: uppercase=bad)
||/ Name                    Version                                 Architecture Description
+++-=======================-=======================================-============-========================================================================
ii  adduser                 3.118ubuntu5                            all          add and remove users and groups

$ apt list --installed 2>/dev/null | head -5
Listing...
adduser/now 3.118ubuntu5 all [installed,local]
apt/now 2.4.14 arm64 [installed,local]
base-files/now 12ubuntu4.7 arm64 [installed,local]
base-passwd/now 3.5.52build1 arm64 [installed,local]

===== cleanup =====

$ rm -rf demo demo.tar.gz restored && ls
bin
boot
dev
etc
home
lib
linux4.sh
media
mnt
opt
proc
root
run
sbin
srv
sys
tmp
usr
var
```

---

## Interview Questions & Answers

Q1. What is the difference between a soft link and a hard link?
A hard link is a second directory entry pointing at the same inode, so it is indistinguishable from the original file - same inode number, same data, and the file's link count goes up. The data is only freed when the last hard link is removed, so deleting the "original" does not break the other name. A soft link is a tiny separate file whose *content is a path string*; it has its own inode and simply redirects to that path. If the target is renamed or deleted, the soft link dangles. Hard links cannot cross filesystems and cannot point at directories; soft links can do both.

Q2. Why can't a hard link cross a filesystem?
Because inode numbers are only unique *within* one filesystem. A directory entry stores an inode number, and that number is meaningless on another filesystem, so the kernel refuses (`Invalid cross-device link`).

Q3. Why are hard links to directories forbidden?
They would let you create loops in the directory tree (a directory reachable from inside itself), which would break `find`, `rm -r`, and filesystem-consistency tools. Only the kernel makes directory hard links, for `.` and `..`.

Q4. `adduser` or `useradd` - which should I use on Ubuntu and why?
`adduser`, because it is the Debian/Ubuntu policy-compliant front-end: it creates the home directory, copies `/etc/skel`, sets `/bin/bash`, creates the user-private group, and prompts for a password in one step. `useradd` is the low-level binary - portable to every distro and the right choice inside scripts and Dockerfiles, but it silently creates a half-usable account unless you pass `-m -s ...` yourself.

Q5. Where do I look when a service fails to start?
`systemctl status <service>` for the summary, then `journalctl -u <service> -n 100 --no-pager` for the detail, `journalctl -u <service> -f` to watch a restart live, and `journalctl -p err -b` for every error since boot.

Q6. How do you see logs from the boot before the machine crashed?
`journalctl -b -1` (`--list-boots` to see what is available). This requires a *persistent* journal - `/var/log/journal` must exist, i.e. `Storage=persistent` in `/etc/systemd/journald.conf`.

Q7. What does `chmod 754` mean?
Owner `rwx` (7), group `r-x` (5), others `r--` (4).
