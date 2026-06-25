#!/bin/bash
set +e

NODES=("mzr1:192.168.56.60:192.168.57.60" "mzr2:192.168.56.61:192.168.57.61")

STAGE="/stage"
GRID_HOME="/u01/app/26ai/grid"
DB_HOME="/u01/app/oracle/product/26ai/dbhome_1"
GRID_BASE="/u01/app/grid"
ORACLE_BASE="/u01/app/oracle"
INV="/u01/app/oraInventory"

GRID_ZIPS=("LINUX.X64_260000_grid_home.zip" "LINUX.X64_2326100_grid_home.zip")
DB_ZIPS=("LINUX.X64_260000_db_home.zip" "LINUX.X64_2326100_db_home.zip")

SSHOPTS="-o BatchMode=yes -o StrictHostKeyChecking=no -o ConnectTimeout=5 -o ConnectionAttempts=1"

LOG="/root/rac26ai_validate_v2_$(date +%F_%H%M%S).log"
ISSUES="/root/rac26ai_manual_fix_v2_$(date +%F_%H%M%S).txt"

ok(){ echo "[PASS] $*" | tee -a "$LOG"; }
fix(){ echo "[FIXED] $*" | tee -a "$LOG"; }
warn(){ echo "[WARN] $*" | tee -a "$LOG"; }
bad(){ echo "[MANUAL FIX] $*" | tee -a "$LOG"; echo "$*" >> "$ISSUES"; }

rssh(){ ssh $SSHOPTS root@"$1" "$2"; }

check_zip_any(){
  IP="$1"
  LABEL="$2"
  shift 2
  FOUND="NO"

  for Z in "$@"; do
    rssh "$IP" "test -f $STAGE/$Z"
    if [ $? -eq 0 ]; then
      ok "$IP $LABEL media found: $STAGE/$Z"
      FOUND="YES"
      break
    fi
  done

  [ "$FOUND" = "YES" ] || bad "$IP missing $LABEL media in $STAGE"
}

check_node(){
  HOST="$1"
  PUB="$2"
  PRIV="$3"

  echo "============================================================" | tee -a "$LOG"
  echo "Checking $HOST / $PUB" | tee -a "$LOG"
  echo "============================================================" | tee -a "$LOG"

  ping -c 1 -W 2 "$PUB" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "$HOST public IP reachable" || { bad "$HOST $PUB not reachable"; return; }

  rssh "$PUB" "hostname" >/dev/null 2>&1
  [ $? -eq 0 ] && ok "$HOST root SSH OK" || { bad "$HOST root SSH failed"; return; }

  rssh "$PUB" "
mkdir -p $STAGE $GRID_BASE $GRID_HOME $ORACLE_BASE $DB_HOME $INV
chown root:oinstall $STAGE 2>/dev/null || true
chmod 775 $STAGE
chown -R grid:oinstall $GRID_BASE $GRID_HOME $INV 2>/dev/null || true
chown -R oracle:oinstall $ORACLE_BASE 2>/dev/null || true
chmod -R 775 /u01
"
  fix "$HOST filesystem/directories checked"

  rssh "$PUB" "test -d $STAGE -a -r $STAGE -a -w $STAGE -a -x $STAGE"
  [ $? -eq 0 ] && ok "$HOST /stage permission OK" || bad "$HOST /stage permission problem"

  rssh "$PUB" "ip -br addr | grep -q '$PRIV/24'"
  [ $? -eq 0 ] && ok "$HOST private IP OK" || bad "$HOST private IP missing: $PRIV"

  rssh "$PUB" "getent hosts mzr1 mzr2 mzr1-priv mzr2-priv mzr-scan >/dev/null"
  [ $? -eq 0 ] && ok "$HOST name resolution OK" || bad "$HOST DNS/hosts resolution failed"

  rssh "$PUB" "getent hosts mzr-scan | wc -l | grep -q '^3$'"
  [ $? -eq 0 ] && ok "$HOST SCAN resolves 3 IPs" || warn "$HOST SCAN does not show 3 lines; acceptable for lab if /etc/hosts has 3 SCAN entries"

  rssh "$PUB" "rpm -q oracle-ai-database-preinstall-26ai >/dev/null 2>&1 || dnf -y install oracle-ai-database-preinstall-26ai"
  [ $? -eq 0 ] && ok "$HOST preinstall RPM OK" || bad "$HOST preinstall RPM failed"

  rssh "$PUB" "dnf -y install bc binutils elfutils-libelf elfutils-libelf-devel fontconfig-devel glibc glibc-devel ksh libaio libaio-devel libX11 libXau libXi libXtst libgcc libnsl librdmacm libstdc++ libstdc++-devel libxcb libibverbs make policycoreutils policycoreutils-python-utils smartmontools sysstat unzip zip net-tools nfs-utils psmisc chrony >/tmp/rac26ai_rpm.log 2>&1"
  [ $? -eq 0 ] && ok "$HOST required RPMs OK" || bad "$HOST required RPM install failed; check /tmp/rac26ai_rpm.log"

  rssh "$PUB" "systemctl enable --now chronyd >/dev/null 2>&1"
  [ $? -eq 0 ] && ok "$HOST chronyd OK" || warn "$HOST chronyd issue"

  rssh "$PUB" "systemctl stop firewalld 2>/dev/null; systemctl disable firewalld 2>/dev/null; setenforce 0 2>/dev/null; sed -i 's/^SELINUX=.*/SELINUX=permissive/' /etc/selinux/config"
  fix "$HOST firewall/SELinux adjusted"

  check_zip_any "$PUB" "Grid" "${GRID_ZIPS[@]}"
  check_zip_any "$PUB" "DB" "${DB_ZIPS[@]}"

  rssh "$PUB" "lsblk | egrep 'sd[b-z]|xvd[b-z]|vd[b-z]' >/dev/null"
  [ $? -eq 0 ] && ok "$HOST shared/extra disks visible" || bad "$HOST ASM disks not visible"
}

for N in "${NODES[@]}"; do
  IFS=: read HOST PUB PRIV <<< "$N"
  check_node "$HOST" "$PUB" "$PRIV"
done

rssh 192.168.56.60 "ping -c 2 -W 2 192.168.57.61 >/dev/null"
[ $? -eq 0 ] && ok "mzr1 -> mzr2 private interconnect OK" || bad "mzr1 cannot ping mzr2 private"

rssh 192.168.56.61 "ping -c 2 -W 2 192.168.57.60 >/dev/null"
[ $? -eq 0 ] && ok "mzr2 -> mzr1 private interconnect OK" || bad "mzr2 cannot ping mzr1 private"

echo "============================================================" | tee -a "$LOG"
echo "SUMMARY" | tee -a "$LOG"
echo "============================================================" | tee -a "$LOG"

if [ -s "$ISSUES" ]; then
  cat "$ISSUES"
else
  echo "READY: both nodes are ready for Oracle RAC media/precheck stage."
fi

echo "Log: $LOG"
echo "Issues: $ISSUES"
