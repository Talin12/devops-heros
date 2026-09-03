# Shell Scripting: Homework (Session 3)

**Name:** Talin Daga
**Enrollment No.:** 24BCS10321
**Email:** talin.24bcs10321@sst.scaler.com

**Task:** write a System Information Script that prints the date, hostname, username, disk usage and
running processes, uses variables, takes input with `read -p`, creates a directory with `mkdir`,
creates a file with `touch`, and stores the running processes in that file using `>` redirection.

Script: [`system_info.sh`](system_info.sh)

---

## Requirement checklist

| # | Requirement | Where it is done | ✔ |
|---|---|---|---|
| 1 | Prints the current date | `CURRENT_DATE=$(date)` -> `echo` | ✅ |
| 2 | Prints the hostname | `HOST_NAME=$(hostname)` | ✅ |
| 3 | Prints the username | `USER_NAME=$(whoami)` | ✅ |
| 4 | Prints the disk usage | `DISK_USAGE=$(df -h)` | ✅ |
| 5 | Prints the running processes | `ps aux \| head -n 10` | ✅ |
| 6 | Uses variables | `CURRENT_DATE`, `HOST_NAME`, `USER_NAME`, `DISK_USAGE`, `DIR_NAME`, `FILE_NAME` | ✅ |
| 7 | Takes user input with `read -p` | two `read -p` prompts | ✅ |
| 8 | Creates a directory with `mkdir` | `mkdir -p "$DIR_NAME"` | ✅ |
| 9 | Creates a file with `touch` | `touch "$DIR_NAME/$FILE_NAME"` | ✅ |
| 10 | Stores processes in the file with `>` | `ps aux > "$DIR_NAME/$FILE_NAME"` | ✅ |

---

## The script

```bash
#!/bin/bash
# ---------------------------------------------------------------
# System Information Script
# Session 3 - Shell Scripting Homework
# Author : Talin Daga
# ---------------------------------------------------------------
# Demonstrates: variables, read -p, mkdir, touch, echo, date,
#               hostname, whoami, df, ps and > output redirection
# ---------------------------------------------------------------

# ---------- Variables ----------
CURRENT_DATE=$(date)
HOST_NAME=$(hostname)
USER_NAME=$(whoami)
DISK_USAGE=$(df -h)

echo "==============================================="
echo "           SYSTEM INFORMATION REPORT           "
echo "==============================================="

echo ""
echo "1. Current Date : $CURRENT_DATE"
echo "2. Hostname     : $HOST_NAME"
echo "3. Username     : $USER_NAME"

echo ""
echo "4. Disk Usage:"
echo "-----------------------------------------------"
echo "$DISK_USAGE"

echo ""
echo "5. Running Processes (top 10):"
echo "-----------------------------------------------"
ps aux | head -n 10

# ---------- Take input from the user ----------
echo ""
read -p "Enter a directory name to create : " DIR_NAME
read -p "Enter a file name to create      : " FILE_NAME

# ---------- Create directory and file ----------
mkdir -p "$DIR_NAME"
echo "Directory '$DIR_NAME' created."

touch "$DIR_NAME/$FILE_NAME"
echo "File '$FILE_NAME' created inside '$DIR_NAME'."

# ---------- Store running processes in the file using > ----------
ps aux > "$DIR_NAME/$FILE_NAME"
echo "Running processes saved to '$DIR_NAME/$FILE_NAME' using > redirection."

# ---------- Also save the full report ----------
{
  echo "System Report generated on : $CURRENT_DATE"
  echo "Hostname : $HOST_NAME"
  echo "User     : $USER_NAME"
  echo ""
  echo "Disk Usage:"
  echo "$DISK_USAGE"
} > "$DIR_NAME/system_report.txt"

echo ""
echo "Preview of $DIR_NAME/$FILE_NAME (first 5 lines):"
echo "-----------------------------------------------"
head -n 5 "$DIR_NAME/$FILE_NAME"

echo ""
echo "Files created:"
ls -l "$DIR_NAME"
echo "==============================================="
echo "                 SCRIPT DONE                   "
echo "==============================================="
```

---

## How to run it

```bash
git clone https://github.com/Talin12/devops-heros.git
cd devops-heros/homework/02-shell-scripting

chmod +x system_info.sh      # make it executable
./system_info.sh             # run it
```

---

## Output (actually executed on Ubuntu 22.04)

```console
$ chmod +x system_info.sh
$ ./system_info.sh
===============================================
           SYSTEM INFORMATION REPORT           
===============================================

1. Current Date : Thu Sep  3 09:40:21 UTC 2026
2. Hostname     : 74c6c5ef2004
3. Username     : root

4. Disk Usage:
-----------------------------------------------
Filesystem            Size  Used Avail Use% Mounted on
overlay               224G   26G  187G  13% /
tmpfs                  64M     0   64M   0% /dev
shm                    64M     0   64M   0% /dev/shm
/run/host_mark/Users  229G  200G   29G  88% /opt/system_info.sh
/dev/vda1             224G   26G  187G  13% /etc/hosts
tmpfs                 3.9G     0  3.9G   0% /proc/scsi
tmpfs                 3.9G     0  3.9G   0% /sys/firmware

5. Running Processes (top 10):
-----------------------------------------------
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   3876  2724 pts/0    Ss+  09:40   0:00 /bin/bash ./system_info.sh
root          13  0.0  0.0   6444  2372 pts/0    R+   09:40   0:00 ps aux
root          14  0.0  0.0   2236   848 pts/0    S+   09:40   0:00 head -n 10

Enter a directory name to create : devops_reports
Enter a file name to create      : processes.txt
Directory 'devops_reports' created.
File 'processes.txt' created inside 'devops_reports'.
Running processes saved to 'devops_reports/processes.txt' using > redirection.

Preview of devops_reports/processes.txt (first 5 lines):
-----------------------------------------------
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   3876  2724 pts/0    Ss+  09:40   0:00 /bin/bash ./system_info.sh
root          17  0.0  0.0   6444  2360 pts/0    R+   09:40   0:00 ps aux

Files created:
total 8
-rw-r--r-- 1 root root 243 Sep  3 09:40 processes.txt
-rw-r--r-- 1 root root 546 Sep  3 09:40 system_report.txt
===============================================
                 SCRIPT DONE                   
===============================================
```

---

## Files the script produced

```console
$ ls -l devops_reports/
total 8
-rw-r--r-- 1 root root 243 Sep  3 09:40 processes.txt
-rw-r--r-- 1 root root 546 Sep  3 09:40 system_report.txt

$ cat devops_reports/processes.txt
USER         PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
root           1  0.0  0.0   3876  2724 pts/0    Ss+  09:40   0:00 /bin/bash ./system_info.sh
root          17  0.0  0.0   6444  2360 pts/0    R+   09:40   0:00 ps aux
```

---

## Commands used, and what each one does

| Command | Purpose | Used as |
|---|---|---|
| `date` | current date & time | `CURRENT_DATE=$(date)` |
| `hostname` | machine name | `HOST_NAME=$(hostname)` |
| `whoami` | current username | `USER_NAME=$(whoami)` |
| `df -h` | disk usage, human readable | `DISK_USAGE=$(df -h)` |
| `ps aux` | every running process | `ps aux \| head -n 10` |
| `echo` | print to stdout | throughout |
| `read -p` | prompt and read into a variable | `read -p "..." DIR_NAME` |
| `mkdir -p` | create a directory (`-p` = no error if it exists) | `mkdir -p "$DIR_NAME"` |
| `touch` | create an empty file / update its timestamp | `touch "$DIR_NAME/$FILE_NAME"` |
| `>` | overwrite redirection - send stdout into a file | `ps aux > file` |
| `>>` | append redirection | used in other examples |
| `head -n` | first N lines | `head -n 10` |
| `ls -l` | long listing | proof the files were created |

### Notes on the shell concepts used

* `$(command)` - command substitution. Runs the command and substitutes its *output*. Preferred over backticks because it nests cleanly.
* `"$VAR"` - always quote variables. Without quotes, a value containing spaces would be split into multiple arguments.
* `> file` vs `>> file`. `>` truncates the file and writes fresh; `>>` appends to the end. The task specifically asks for `>`.
* `{ ...; } > file` - group redirection. Sends the output of a whole block into one file, used here to build `system_report.txt`.
* `mkdir -p` creates parent directories as needed and does not fail if the directory already exists - which makes the script safe to re-run.
