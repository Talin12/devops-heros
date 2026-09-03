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
