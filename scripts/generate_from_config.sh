#!/bin/bash
set -e

BASE="/u01/ansible/rac26ai_ansible"
CFG="$BASE/config/rac_input.env"

[ -f "$CFG" ] || { echo "Missing $CFG. Run ./create_rac_ansible_project.sh first"; exit 1; }

source "$CFG"

mkdir -p "$BASE"/{inventory,group_vars,roles/00_common/tasks,roles/01_network/tasks,roles/02_asm_disks/tasks,roles/03_grid_install/tasks,roles/03_grid_install/templates,logs,backup}

cat > "$BASE/inventory/hosts.ini" <<EOT
[rac_primary]
$NODE1_HOST ansible_host=$NODE1_PUBLIC_IP public_ip=$NODE1_PUBLIC_IP private_ip=$NODE1_PRIV_IP vip_ip=$NODE1_VIP_IP node_fqdn=$NODE1_FQDN

[rac_secondary]
$NODE2_HOST ansible_host=$NODE2_PUBLIC_IP public_ip=$NODE2_PUBLIC_IP private_ip=$NODE2_PRIV_IP vip_ip=$NODE2_VIP_IP node_fqdn=$NODE2_FQDN

[rac_nodes:children]
rac_primary
rac_secondary

[rac_nodes:vars]
ansible_user=root
ansible_connection=ssh
ansible_python_interpreter=/usr/bin/python3.9
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
EOT

cat > "$BASE/group_vars/rac_nodes.yml" <<EOT
---
domain_name: "$DOMAIN"

node1_host: "$NODE1_HOST"
node1_fqdn: "$NODE1_FQDN"
node1_public_ip: "$NODE1_PUBLIC_IP"
node1_private_ip: "$NODE1_PRIV_IP"
node1_vip: "$NODE1_VIP"
node1_vip_fqdn: "$NODE1_VIP_FQDN"
node1_vip_ip: "$NODE1_VIP_IP"

node2_host: "$NODE2_HOST"
node2_fqdn: "$NODE2_FQDN"
node2_public_ip: "$NODE2_PUBLIC_IP"
node2_private_ip: "$NODE2_PRIV_IP"
node2_vip: "$NODE2_VIP"
node2_vip_fqdn: "$NODE2_VIP_FQDN"
node2_vip_ip: "$NODE2_VIP_IP"

scan_name: "$SCAN_NAME"
scan_fqdn: "$SCAN_FQDN"
scan_ip1: "$SCAN_IP1"
scan_ip2: "$SCAN_IP2"
scan_ip3: "$SCAN_IP3"

public_interface: "$PUBLIC_IFACE"
private_interface: "$PRIVATE_IFACE"
public_network: "$PUBLIC_NETWORK"
private_network: "$PRIVATE_NETWORK"

grid_base: "$GRID_BASE"
grid_home: "$GRID_HOME"
oracle_base: "$ORACLE_BASE"
db_home: "$DB_HOME"
ora_inventory: "$ORA_INVENTORY"
stage_dir: "$STAGE_DIR"

grid_zip: "$GRID_ZIP"
db_zip: "$DB_ZIP"

ocr_disk: "$OCR_DISK"
data_disk: "$DATA_DISK"
fra_disk: "$FRA_DISK"

cluster_name: "$CLUSTER_NAME"
db_name: "$DB_NAME"
pdb_name: "$PDB_NAME"
sys_password: "$SYS_PASSWORD"
system_password: "$SYSTEM_PASSWORD"
EOT

cat > "$BASE/site.yml" <<'EOT'
---
- name: 00_common
  hosts: rac_nodes
  roles:
    - role: 00_common
      tags: common

- name: 01_network
  hosts: rac_nodes
  roles:
    - role: 01_network
      tags: network

- name: 02_asm_disks
  hosts: rac_nodes
  roles:
    - role: 02_asm_disks
      tags: asm

- name: 03_grid_install
  hosts: rac_nodes
  roles:
    - role: 03_grid_install
      tags: grid
EOT

cat > "$BASE/roles/00_common/tasks/main.yml" <<'EOT'
---
- name: Create Oracle groups
  group:
    name: "{{ item.name }}"
    gid: "{{ item.gid }}"
    state: present
  loop:
    - { name: oinstall, gid: 54321 }
    - { name: dba, gid: 54322 }
    - { name: oper, gid: 54323 }
    - { name: backupdba, gid: 54324 }
    - { name: dgdba, gid: 54325 }
    - { name: kmdba, gid: 54326 }
    - { name: asmadmin, gid: 54327 }
    - { name: asmdba, gid: 54328 }
    - { name: asmoper, gid: 54329 }
    - { name: racdba, gid: 54330 }

- name: Create grid user
  user:
    name: grid
    uid: 54331
    group: oinstall
    groups: asmadmin,asmdba,asmoper,dba,racdba
    append: yes

- name: Create oracle user
  user:
    name: oracle
    uid: 54321
    group: oinstall
    groups: dba,oper,backupdba,dgdba,kmdba,racdba,asmdba
    append: yes

- name: Create Oracle directories
  file:
    path: "{{ item.path }}"
    owner: "{{ item.owner }}"
    group: oinstall
    mode: "0775"
    state: directory
  loop:
    - { path: "{{ grid_base }}", owner: grid }
    - { path: "{{ grid_home }}", owner: grid }
    - { path: "{{ oracle_base }}", owner: oracle }
    - { path: "{{ db_home }}", owner: oracle }
    - { path: "{{ ora_inventory }}", owner: grid }
    - { path: "{{ stage_dir }}", owner: root }

- name: Disable firewalld
  service:
    name: firewalld
    state: stopped
    enabled: no
  ignore_errors: yes

- name: Set SELinux permissive runtime
  command: setenforce 0
  ignore_errors: yes
  changed_when: false
EOT

cat > "$BASE/roles/01_network/tasks/main.yml" <<'EOT'
---
- name: Set hostname
  hostname:
    name: "{{ node_fqdn }}"

- name: Write RAC hosts file
  copy:
    dest: /etc/hosts
    content: |
      127.0.0.1 localhost localhost.localdomain

      {{ node1_public_ip }} {{ node1_fqdn }} {{ node1_host }}
      {{ node2_public_ip }} {{ node2_fqdn }} {{ node2_host }}

      {{ node1_private_ip }} {{ node1_host }}-priv.{{ domain_name }} {{ node1_host }}-priv
      {{ node2_private_ip }} {{ node2_host }}-priv.{{ domain_name }} {{ node2_host }}-priv

      {{ node1_vip_ip }} {{ node1_vip_fqdn }} {{ node1_vip }}
      {{ node2_vip_ip }} {{ node2_vip_fqdn }} {{ node2_vip }}

      {{ scan_ip1 }} {{ scan_fqdn }} {{ scan_name }}
      {{ scan_ip2 }} {{ scan_fqdn }} {{ scan_name }}
      {{ scan_ip3 }} {{ scan_fqdn }} {{ scan_name }}

- name: Validate public node pings
  command: "ping -c 2 {{ hostvars[item].public_ip }}"
  loop: "{{ groups['rac_nodes'] }}"
  changed_when: false

- name: Validate private node pings
  command: "ping -c 2 {{ hostvars[item].private_ip }}"
  loop: "{{ groups['rac_nodes'] }}"
  changed_when: false
EOT

cat > "$BASE/roles/02_asm_disks/tasks/main.yml" <<'EOT'
---
- name: Validate ASM disk variables
  assert:
    that:
      - ocr_disk is defined
      - data_disk is defined
      - fra_disk is defined

- name: Validate ASM candidate disks exist
  stat:
    path: "{{ item }}"
  loop:
    - "{{ ocr_disk }}"
    - "{{ data_disk }}"
    - "{{ fra_disk }}"
  register: asm_disk_stat

- name: Fail if ASM disk missing
  fail:
    msg: "ASM disk missing: {{ item.item }}"
  loop: "{{ asm_disk_stat.results }}"
  when: not item.stat.exists

- name: Check ASM disks signatures
  command: "wipefs -n {{ item }}"
  loop:
    - "{{ ocr_disk }}"
    - "{{ data_disk }}"
    - "{{ fra_disk }}"
  changed_when: false

- name: Set permissions on ASM candidate disks
  file:
    path: "{{ item }}"
    owner: grid
    group: asmadmin
    mode: "0660"
  loop:
    - "{{ ocr_disk }}"
    - "{{ data_disk }}"
    - "{{ fra_disk }}"

- name: Show ASM disk mapping
  shell: "hostname; ls -l {{ ocr_disk }} {{ data_disk }} {{ fra_disk }}; lsblk -o NAME,SIZE,MODEL,SERIAL"
  register: asm_map
  changed_when: false

- debug:
    var: asm_map.stdout_lines
EOT

cat > "$BASE/roles/03_grid_install/templates/gridsetup.rsp.j2" <<'EOT'
oracle.install.responseFileVersion=/oracle/install/rspfmt_crsinstall_response_schema_v23.0.0
INVENTORY_LOCATION={{ ora_inventory }}
oracle.install.option=CRS_CONFIG
ORACLE_BASE={{ grid_base }}
oracle.install.asm.OSDBA=asmdba
oracle.install.asm.OSOPER=asmoper
oracle.install.asm.OSASM=asmadmin
oracle.install.crs.config.scanType=LOCAL_SCAN
oracle.install.crs.config.gpnp.scanName={{ scan_fqdn }}
oracle.install.crs.config.gpnp.scanPort=1521
oracle.install.crs.config.clusterName={{ cluster_name }}
oracle.install.crs.config.clusterNodes={{ node1_host }}:{{ node1_vip }},{{ node2_host }}:{{ node2_vip }}
oracle.install.crs.config.networkInterfaceList={{ public_interface }}:{{ public_network }}:1,{{ private_interface }}:{{ private_network }}:5
oracle.install.crs.config.useIPMI=false
oracle.install.asm.SYSASMPassword={{ sys_password }}
oracle.install.asm.diskGroup.name=OCR
oracle.install.asm.diskGroup.redundancy=EXTERNAL
oracle.install.asm.diskGroup.AUSize=4
oracle.install.asm.diskGroup.disks={{ ocr_disk }}
oracle.install.asm.diskGroup.diskDiscoveryString=/dev/disk/by-id/ata-VBOX_HARDDISK_*
oracle.install.asm.monitorPassword={{ sys_password }}
oracle.install.crs.configureRHPS=false
oracle.install.crs.config.ignoreDownNodes=false
oracle.install.config.managementOption=NONE
EOT

cat > "$BASE/roles/03_grid_install/tasks/main.yml" <<'EOT'
---
- name: Unzip Grid home
  unarchive:
    src: "{{ stage_dir }}/{{ grid_zip }}"
    dest: "{{ grid_home }}"
    remote_src: true
    owner: grid
    group: oinstall
    creates: "{{ grid_home }}/gridSetup.sh"

- name: Create Grid response file on primary
  template:
    src: gridsetup.rsp.j2
    dest: "{{ stage_dir }}/gridsetup.rsp"
    owner: grid
    group: oinstall
    mode: "0600"
  when: inventory_hostname in groups['rac_primary']

- name: Run Grid setup on primary
  become_user: grid
  shell: "cd {{ grid_home }} && ./gridSetup.sh -silent -responseFile {{ stage_dir }}/gridsetup.rsp"
  register: grid_setup
  when: inventory_hostname in groups['rac_primary']
  changed_when: true
  failed_when: grid_setup.rc != 0

- name: Mark Grid setup success
  set_fact:
    grid_setup_success: true
  when:
    - inventory_hostname in groups['rac_primary']
    - grid_setup is defined
    - grid_setup.rc == 0

- name: Check primary Grid setup success
  set_fact:
    primary_grid_setup_success: "{{ hostvars[groups['rac_primary'][0]].grid_setup_success | default(false) }}"

- name: Stop if Grid setup failed
  fail:
    msg: "Grid setup failed on primary. Root scripts will not run."
  when: not primary_grid_setup_success

- name: Check oraInventory root script
  stat:
    path: "{{ ora_inventory }}/orainstRoot.sh"
  register: orainst_script

- name: Run oraInventory root script
  shell: "{{ ora_inventory }}/orainstRoot.sh"
  when: orainst_script.stat.exists
  changed_when: true

- name: Check Grid root.sh
  stat:
    path: "{{ grid_home }}/root.sh"
  register: grid_root_script

- name: Run Grid root.sh
  shell: "{{ grid_home }}/root.sh"
  when: grid_root_script.stat.exists
  register: rootsh
  failed_when: rootsh.rc not in [0,1]
  changed_when: true

- name: Run Grid config tools on primary
  become_user: grid
  shell: "cd {{ grid_home }} && ./gridSetup.sh -executeConfigTools -responseFile {{ stage_dir }}/gridsetup.rsp -silent"
  when: inventory_hostname in groups['rac_primary']
  register: grid_config_tools
  failed_when: grid_config_tools.rc not in [0,6]
  changed_when: true
EOT

echo "Generated Ansible project from $CFG"
echo "Test: ansible all -i inventory/hosts.ini -m ping"
