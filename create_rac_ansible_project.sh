#!/bin/bash
set -e

BASE="/u01/ansible/rac26ai_ansible"
CFG="$BASE/config/rac_input.env"

mkdir -p "$BASE"/{config,inventory,group_vars,roles,logs,backup,scripts}

ask() {
  VAR="$1"
  MSG="$2"
  DEF="$3"
  read -p "$MSG [$DEF]: " VAL
  VAL="${VAL:-$DEF}"
  echo "$VAR=\"$VAL\"" >> "$CFG"
}

echo "Creating RAC config: $CFG"
: > "$CFG"

ask DOMAIN "Domain name" "lab.maz"

ask NODE1_HOST "Node1 short hostname" "mzr1"
ask NODE1_FQDN "Node1 FQDN" "mzr1.lab.maz"
ask NODE1_PUBLIC_IP "Node1 public IP" "192.168.56.60"
ask NODE1_PRIV_IP "Node1 private IP" "192.168.57.60"
ask NODE1_VIP "Node1 VIP short" "mzr1-vip"
ask NODE1_VIP_FQDN "Node1 VIP FQDN" "mzr1-vip.lab.maz"
ask NODE1_VIP_IP "Node1 VIP IP" "192.168.56.62"

ask NODE2_HOST "Node2 short hostname" "mzr2"
ask NODE2_FQDN "Node2 FQDN" "mzr2.lab.maz"
ask NODE2_PUBLIC_IP "Node2 public IP" "192.168.56.61"
ask NODE2_PRIV_IP "Node2 private IP" "192.168.57.61"
ask NODE2_VIP "Node2 VIP short" "mzr2-vip"
ask NODE2_VIP_FQDN "Node2 VIP FQDN" "mzr2-vip.lab.maz"
ask NODE2_VIP_IP "Node2 VIP IP" "192.168.56.63"

ask SCAN_NAME "SCAN short name" "mzr-scan"
ask SCAN_FQDN "SCAN FQDN" "mzr-scan.lab.maz"
ask SCAN_IP1 "SCAN IP1" "192.168.56.64"
ask SCAN_IP2 "SCAN IP2" "192.168.56.65"
ask SCAN_IP3 "SCAN IP3" "192.168.56.66"

ask PUBLIC_IFACE "Public interface" "enp0s3"
ask PRIVATE_IFACE "Private interface" "enp0s8"
ask PUBLIC_NETWORK "Public network" "192.168.56.0"
ask PRIVATE_NETWORK "Private network" "192.168.57.0"

ask GRID_BASE "Grid base" "/u01/app/grid"
ask GRID_HOME "Grid home" "/u01/app/26ai/grid"
ask ORACLE_BASE "Oracle base" "/u01/app/oracle"
ask DB_HOME "DB home" "/u01/app/oracle/product/26ai/dbhome_1"
ask ORA_INVENTORY "OraInventory" "/u01/app/oraInventory"
ask STAGE_DIR "Stage dir" "/stage"

ask GRID_ZIP "Grid zip file" "LINUX.X64_2326100_grid_home.zip"
ask DB_ZIP "DB zip file" "LINUX.X64_2326100_db_home.zip"

ask OCR_DISK "OCR disk by-id path" "/dev/disk/by-id/ata-VBOX_HARDDISK_VB53696b04-02299818"
ask DATA_DISK "DATA disk by-id path" "/dev/disk/by-id/ata-VBOX_HARDDISK_VBc638bb07-b5cd2cd8"
ask FRA_DISK "FRA disk by-id path" "/dev/disk/by-id/ata-VBOX_HARDDISK_VB26c4115d-f19154d9"

ask CLUSTER_NAME "Cluster name" "mzr-cluster"
ask DB_NAME "CDB name" "TESTCDB"
ask PDB_NAME "PDB name" "TESTPDB"
ask SYS_PASSWORD "SYS password" "mzrAttack123"
ask SYSTEM_PASSWORD "SYSTEM password" "mzrAttack123"

echo "Config created: $CFG"
echo "Next run: ./scripts/generate_from_config.sh"
