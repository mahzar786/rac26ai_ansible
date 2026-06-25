#!/bin/bash
set -e

BASE="/u01/ansible/rac26ai_ansible"
INV="$BASE/inventory/hosts.ini"
GRID_HOME="/u01/app/26ai/grid"
ORA_INVENTORY="/u01/app/oraInventory"
STAGE="/stage"

OCR_DISK="/dev/disk/by-id/ata-VBOX_HARDDISK_VB53696b04-02299818"
DATA_DISK="/dev/disk/by-id/ata-VBOX_HARDDISK_VBc638bb07-b5cd2cd8"
FRA_DISK="/dev/disk/by-id/ata-VBOX_HARDDISK_VB26c4115d-f19154d9"

cd "$BASE"

echo "This will clean failed Grid install state on mzr1/mzr2."
read -p "Type CLEAN to continue: " A
[ "$A" = "CLEAN" ] || { echo "Cancelled."; exit 1; }

ansible all -i "$INV" -m shell -a "systemctl stop oracle-ohasd 2>/dev/null || true; systemctl disable oracle-ohasd 2>/dev/null || true; pkill -9 -f gridSetup 2>/dev/null || true; pkill -9 -f runInstaller 2>/dev/null || true; pkill -9 -f ohasd 2>/dev/null || true; pkill -9 -f crsd.bin 2>/dev/null || true; pkill -9 -f cssd.bin 2>/dev/null || true; pkill -9 -f evmd.bin 2>/dev/null || true; pkill -9 -f asm_pmon 2>/dev/null || true; true"

ansible all -i "$INV" -m shell -a "rm -rf /tmp/GridSetupActions* /tmp/OraInstall* /tmp/CVU* /tmp/cvu* /tmp/.oracle /var/tmp/.oracle /var/tmp/ansible-* /tmp/ansible-* 2>/dev/null || true; rm -rf /etc/oracle /etc/init.d/init.ohasd /etc/systemd/system/oracle-ohasd.service /etc/systemd/system/multi-user.target.wants/oracle-ohasd.service 2>/dev/null || true; rm -f /etc/oraInst.loc 2>/dev/null || true; rm -rf ${ORA_INVENTORY}/logs/GridSetupActions* ${ORA_INVENTORY}/logs/installActions* 2>/dev/null || true; rm -f ${STAGE}/gridsetup.rsp 2>/dev/null || true; true"

read -p "Delete and re-extract Grid Home? Type YES: " B
if [ "$B" = "YES" ]; then
  ansible all -i "$INV" -m shell -a "rm -rf ${GRID_HOME}/*; mkdir -p ${GRID_HOME}; chown -R grid:oinstall ${GRID_HOME}; chmod -R 775 ${GRID_HOME}"
fi

read -p "Wipe ASM disk signatures OCR/DATA/FRA? Type WIPE: " C
if [ "$C" = "WIPE" ]; then
  ansible all -i "$INV" -m shell -a "for X in '${OCR_DISK}' '${DATA_DISK}' '${FRA_DISK}'; do echo Cleaning \$X; wipefs -a \$X || true; dd if=/dev/zero of=\$X bs=1M count=100 conv=notrunc status=none || true; chown grid:asmadmin \$X || true; chmod 660 \$X || true; done; partprobe || true; udevadm settle || true"
fi

ansible all -i "$INV" -m shell -a "hostname; df -h /; ls -ld /tmp /var/tmp ${GRID_HOME} ${ORA_INVENTORY} ${STAGE}; ls -l '${OCR_DISK}' '${DATA_DISK}' '${FRA_DISK}'; ps -ef | egrep 'gridSetup|runInstaller|ohasd|crsd|cssd|asm_pmon' | grep -v grep || true"

echo "Cleanup complete."
echo "Next:"
echo "cd $BASE && ansible-playbook -i inventory/hosts.ini site.yml --tags grid"
