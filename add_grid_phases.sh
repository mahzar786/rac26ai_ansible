#!/bin/bash
set -e

BASE=/u01/ansible/rac26ai_ansible

echo "Backup..."
mkdir -p $BASE/backup
cp site.yml $BASE/backup/site.yml.$(date +%F_%H%M%S)

##################################################
# ROLE 04 GRID ROOT
##################################################

mkdir -p roles/04_grid_root/tasks

cat > roles/04_grid_root/tasks/main.yml <<'EOT'
---
- name: Check oraInventory root script
  stat:
    path: "{{ ora_inventory }}/orainstRoot.sh"
  register: orainst

- name: Run oraInventory root script
  shell: "{{ ora_inventory }}/orainstRoot.sh"
  when: orainst.stat.exists
  tags:
    - grid_root

- name: Check Grid root.sh
  stat:
    path: "{{ grid_home }}/root.sh"
  register: gridroot

- name: Run Grid root.sh
  shell: "{{ grid_home }}/root.sh"
  when: gridroot.stat.exists
  tags:
    - grid_root

- name: Verify OHASD
  shell: "{{ grid_home }}/bin/crsctl check has"
  register: hascheck
  changed_when: false
  failed_when: false
  tags:
    - grid_root

- debug:
    var: hascheck.stdout_lines
  tags:
    - grid_root
EOT

##################################################
# ROLE 05 GRID CONFIG
##################################################

mkdir -p roles/05_grid_config/tasks

cat > roles/05_grid_config/tasks/main.yml <<'EOT'
---
- name: Execute Grid Config Tools
  become: yes
  become_user: grid

  shell: |
    cd {{ grid_home }}
    ./gridSetup.sh \
      -executeConfigTools \
      -responseFile {{ stage_dir }}/gridsetup.rsp \
      -silent

  register: cfgtools

  failed_when: cfgtools.rc not in [0,6]

  tags:
    - grid_cfg

- debug:
    var: cfgtools.stdout_lines

  tags:
    - grid_cfg
EOT

##################################################
# PLAYBOOK 04
##################################################

cat > 04_grid_root.yml <<'EOT'
---
- name: Grid Root Scripts
  hosts: rac_nodes
  become: yes

  roles:
    - role: 04_grid_root
EOT

##################################################
# PLAYBOOK 05
##################################################

cat > 05_grid_config.yml <<'EOT'
---
- name: Grid Configuration
  hosts: rac_primary

  roles:
    - role: 05_grid_config
EOT

##################################################
# DISPLAY
##################################################

echo
echo "======================================="
echo "NEW PLAYBOOKS CREATED"
echo "======================================="
echo "04_grid_root.yml"
echo "05_grid_config.yml"
echo
echo "Run:"
echo
echo "ansible-playbook -i inventory/hosts.ini 04_grid_root.yml"
echo
echo "ansible-playbook -i inventory/hosts.ini 05_grid_config.yml"
echo
echo "Or by tags:"
echo
echo "ansible-playbook -i inventory/hosts.ini site.yml --tags grid_root"
echo
echo "ansible-playbook -i inventory/hosts.ini site.yml --tags grid_cfg"
echo
