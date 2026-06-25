#!/usr/bin/env python3
from pathlib import Path
from datetime import datetime
import sys

ROOT = Path.cwd()
INTAKE = ROOT / "config" / "rac_input.env"
INV_DIR = ROOT / "inventory"
GV_DIR = ROOT / "group_vars"
BAK_DIR = ROOT / "backup"
HOSTS = INV_DIR / "hosts.ini"
GV = GV_DIR / "rac_nodes.yml"


def parse_env(path: Path):
    if not path.exists():
        print(f"ERROR: Intake file not found: {path}")
        print("First run portal and save config/rac_input.env")
        sys.exit(1)
    data = {}
    for line in path.read_text(encoding="utf-8").splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        k, v = line.split("=", 1)
        data[k.strip()] = v.strip().strip('"').strip("'")
    return data


def val(d, key, default=""):
    return d.get(key, default)


def backup_file(path: Path):
    if path.exists():
        BAK_DIR.mkdir(exist_ok=True)
        ts = datetime.now().strftime("%Y%m%d_%H%M%S")
        target = BAK_DIR / f"{path.name}.{ts}.bak"
        target.write_text(path.read_text(encoding="utf-8"), encoding="utf-8")
        print(f"Backup created: {target}")


def main():
    d = parse_env(INTAKE)
    INV_DIR.mkdir(exist_ok=True)
    GV_DIR.mkdir(exist_ok=True)

    node1 = val(d,"NODE1_NAME","rac1")
    node2 = val(d,"NODE2_NAME","rac2")
    n1_pub = val(d,"NODE1_PUBLIC_IP")
    n2_pub = val(d,"NODE2_PUBLIC_IP")
    n1_priv = val(d,"NODE1_PRIVATE_IP")
    n2_priv = val(d,"NODE2_PRIVATE_IP")
    n1_vip = val(d,"NODE1_VIP_IP")
    n2_vip = val(d,"NODE2_VIP_IP")
    n1_fqdn = val(d,"NODE1_FQDN",f"{node1}.{val(d,'DOMAIN','lab.local')}")
    n2_fqdn = val(d,"NODE2_FQDN",f"{node2}.{val(d,'DOMAIN','lab.local')}")
    ansible_user = val(d,"ANSIBLE_USER","root")
    python = val(d,"PYTHON","/usr/bin/python3")

    required = ["NODE1_PUBLIC_IP","NODE2_PUBLIC_IP","NODE1_PRIVATE_IP","NODE2_PRIVATE_IP","NODE1_VIP_IP","NODE2_VIP_IP"]
    missing = [k for k in required if not val(d,k)]
    if missing:
        print("ERROR: Missing required values in config/rac_input.env:")
        for k in missing:
            print(f"  - {k}")
        sys.exit(1)

    backup_file(HOSTS)
    backup_file(GV)

    HOSTS.write_text(f"""[rac_primary]
{node1} ansible_host={n1_pub} public_ip={n1_pub} private_ip={n1_priv} vip_ip={n1_vip} node_fqdn={n1_fqdn}

[rac_secondary]
{node2} ansible_host={n2_pub} public_ip={n2_pub} private_ip={n2_priv} vip_ip={n2_vip} node_fqdn={n2_fqdn}

[rac_nodes:children]
rac_primary
rac_secondary

[rac_nodes:vars]
ansible_user={ansible_user}
ansible_connection=ssh
ansible_python_interpreter={python}
ansible_ssh_common_args='-o StrictHostKeyChecking=no'
""", encoding="utf-8")

    GV.write_text(f"""---
cluster_name: {val(d,'CLUSTER_NAME','rac-cluster')}
domain_name: {val(d,'DOMAIN','lab.local')}

scan_name: {val(d,'SCAN_NAME','rac-scan')}
scan_ips:
  - {val(d,'SCAN_IP1')}
  - {val(d,'SCAN_IP2')}
  - {val(d,'SCAN_IP3')}

rac_nodes:
  - name: {node1}
    fqdn: {n1_fqdn}
    public_ip: {n1_pub}
    private_ip: {n1_priv}
    vip_name: {val(d,'NODE1_VIP_NAME',node1+'-vip')}
    vip_ip: {n1_vip}
  - name: {node2}
    fqdn: {n2_fqdn}
    public_ip: {n2_pub}
    private_ip: {n2_priv}
    vip_name: {val(d,'NODE2_VIP_NAME',node2+'-vip')}
    vip_ip: {n2_vip}

public_interface: {val(d,'PUBLIC_IFACE','enp0s3')}
private_interface: {val(d,'PRIVATE_IFACE','enp0s8')}

grid_base: {val(d,'GRID_BASE','/u01/app/grid')}
grid_home: {val(d,'GRID_HOME','/u01/app/26ai/grid')}
oracle_base: {val(d,'ORACLE_BASE','/u01/app/oracle')}
db_home: {val(d,'DB_HOME','/u01/app/oracle/product/26ai/dbhome_1')}
ora_inventory: {val(d,'ORA_INVENTORY','/u01/app/oraInventory')}
stage_dir: {val(d,'STAGE_DIR','/stage')}

grid_zip: {val(d,'GRID_ZIP')}
db_zip: {val(d,'DB_ZIP')}

asm_discovery_string: {val(d,'ASM_DISCOVERY_STRING','/dev/disk/by-id/*')}
asm_disks:
  ocr: {val(d,'OCR_DISK')}
  data: {val(d,'DATA_DISK')}
  fra: {val(d,'FRA_DISK')}

db_name: {val(d,'DB_NAME','TESTCDB')}
pdb_name: {val(d,'PDB_NAME','TESTPDB')}
db_memory_mb: {val(d,'DB_MEMORY_MB','2048')}
""", encoding="utf-8")

    print("SUCCESS: Generated Ansible files from intake:")
    print(f"  {HOSTS}")
    print(f"  {GV}")

if __name__ == "__main__":
    main()
