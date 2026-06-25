#!/bin/bash
set -e

BASE="/u01/ansible/rac26ai_ansible"
TS=$(date +%F_%H%M%S)

NODE1_HOST="mzr1"
NODE1_FQDN="mzr1.lab.maz"
NODE1_PUBLIC_IP="192.168.56.60"
NODE1_PRIV_IP="192.168.57.60"

NODE2_HOST="mzr2"
NODE2_FQDN="mzr2.lab.maz"
NODE2_PUBLIC_IP="192.168.56.61"
NODE2_PRIV_IP="192.168.57.61"

NODE1_VIP_IP="192.168.56.62"
NODE2_VIP_IP="192.168.56.63"

SCAN_NAME="mzr-scan"
SCAN_FQDN="mzr-scan.lab.maz"
SCAN_IP1="192.168.56.64"
SCAN_IP2="192.168.56.65"
SCAN_IP3="192.168.56.66"

DOMAIN="lab.maz"

mkdir -p "$BASE/backup" "$BASE/inventory" "$BASE/group_vars" "$BASE/config"

backup_file() {
  [ -f "$1" ] && cp "$1" "$BASE/backup/$(basename $1).$TS.bak"
}

backup_file "$BASE/inventory/hosts.ini"
backup_file "$BASE/group_vars/all.yml"
backup_file "$BASE/config/rac26ai.env"

cat > "$BASE/inventory/hosts.ini" <<EOT
[rac_nodes]
$NODE1_HOST ansible_host=$NODE1_PUBLIC_IP
$NODE2_HOST ansible_host=$NODE2_PUBLIC_IP

[rac_nodes:vars]
ansible_user=root
ansible_connection=ssh
EOT

cat > "$BASE/group_vars/all.yml" <<EOT
---
domain_name: "$DOMAIN"

node1_host: "$NODE1_HOST"
node1_fqdn: "$NODE1_FQDN"
node1_public_ip: "$NODE1_PUBLIC_IP"
node1_private_ip: "$NODE1_PRIV_IP"
node1_vip_ip: "$NODE1_VIP_IP"

node2_host: "$NODE2_HOST"
node2_fqdn: "$NODE2_FQDN"
node2_public_ip: "$NODE2_PUBLIC_IP"
node2_private_ip: "$NODE2_PRIV_IP"
node2_vip_ip: "$NODE2_VIP_IP"

scan_name: "$SCAN_NAME"
scan_fqdn: "$SCAN_FQDN"
scan_ips:
  - "$SCAN_IP1"
  - "$SCAN_IP2"
  - "$SCAN_IP3"

public_iface: "enp0s3"
private_iface: "enp0s8"

grid_base: "/u01/app/grid"
grid_home: "/u01/app/26ai/grid"
oracle_base: "/u01/app/oracle"
db_home: "/u01/app/oracle/product/26ai/dbhome_1"
ora_inventory: "/u01/app/oraInventory"
stage_dir: "/stage"

db_name: "TESTCDB"
pdb_name: "TESTPDB"

data_dg: "DATA"
fra_dg: "FRA"
ocr_dg: "OCR"
EOT

cat > "$BASE/config/rac26ai.env" <<EOT
DOMAIN="$DOMAIN"

NODE1_HOST="$NODE1_HOST"
NODE1_FQDN="$NODE1_FQDN"
NODE1_PUBLIC_IP="$NODE1_PUBLIC_IP"
NODE1_PRIV_IP="$NODE1_PRIV_IP"
NODE1_VIP_IP="$NODE1_VIP_IP"

NODE2_HOST="$NODE2_HOST"
NODE2_FQDN="$NODE2_FQDN"
NODE2_PUBLIC_IP="$NODE2_PUBLIC_IP"
NODE2_PRIV_IP="$NODE2_PRIV_IP"
NODE2_VIP_IP="$NODE2_VIP_IP"

SCAN_NAME="$SCAN_NAME"
SCAN_FQDN="$SCAN_FQDN"
SCAN_IP1="$SCAN_IP1"
SCAN_IP2="$SCAN_IP2"
SCAN_IP3="$SCAN_IP3"
EOT

HOSTS_FILE="/tmp/rac26ai_hosts.$$"

cat > "$HOSTS_FILE" <<EOT
127.0.0.1 localhost localhost.localdomain

# ===== Oracle 26ai RAC lab.maz =====
$NODE1_PUBLIC_IP   $NODE1_FQDN $NODE1_HOST
$NODE2_PUBLIC_IP   $NODE2_FQDN $NODE2_HOST

$NODE1_PRIV_IP     $NODE1_HOST-priv.$DOMAIN $NODE1_HOST-priv
$NODE2_PRIV_IP     $NODE2_HOST-priv.$DOMAIN $NODE2_HOST-priv

$NODE1_VIP_IP      $NODE1_HOST-vip.$DOMAIN $NODE1_HOST-vip
$NODE2_VIP_IP      $NODE2_HOST-vip.$DOMAIN $NODE2_HOST-vip

$SCAN_IP1          $SCAN_FQDN $SCAN_NAME
$SCAN_IP2          $SCAN_FQDN $SCAN_NAME
$SCAN_IP3          $SCAN_FQDN $SCAN_NAME
# ===== End Oracle 26ai RAC =====
EOT

for IP in "$NODE1_PUBLIC_IP" "$NODE2_PUBLIC_IP"; do
  echo "Updating /etc/hosts on $IP"
  scp -q -o StrictHostKeyChecking=no "$HOSTS_FILE" root@$IP:/tmp/rac26ai_hosts
  ssh -o StrictHostKeyChecking=no root@$IP "
    cp /etc/hosts /etc/hosts.bkp_$TS
    cp /tmp/rac26ai_hosts /etc/hosts
  "
done

rm -f "$HOSTS_FILE"

echo "Validating Ansible ping..."
cd "$BASE"
ansible all -i inventory/hosts.ini -m ping

echo
echo "DONE. Updated:"
echo "$BASE/inventory/hosts.ini"
echo "$BASE/group_vars/all.yml"
echo "$BASE/config/rac26ai.env"
echo "/etc/hosts on both nodes"
