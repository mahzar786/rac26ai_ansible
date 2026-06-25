#!/bin/bash
set -euo pipefail

OUT="config/rac26ai_env.ini"
TMP="$(mktemp)"
mkdir -p config scripts

declare -A CFG

trim() {
  local s="$1"
  s="${s#"${s%%[![:space:]]*}"}"
  s="${s%"${s##*[![:space:]]}"}"
  printf '%s' "$s"
}

prompt() {
  local key="$1"
  local text="$2"
  local default="${3:-}"
  local value

  if [[ -n "$default" ]]; then
    read -r -p "$text [$default]: " value
    value="${value:-$default}"
  else
    read -r -p "$text: " value
  fi

  value="$(trim "$value")"

  if [[ -z "$value" ]]; then
    echo "ERROR: $key cannot be empty." >&2
    exit 1
  fi

  CFG["$key"]="$value"
}

prompt_secret() {
  local key="$1"
  local text="$2"
  local default="${3:-}"
  local value

  if [[ -n "$default" ]]; then
    read -r -s -p "$text [$default]: " value
    echo
    value="${value:-$default}"
  else
    read -r -s -p "$text: " value
    echo
  fi

  value="$(trim "$value")"

  if [[ -z "$value" ]]; then
    echo "ERROR: $key cannot be empty." >&2
    exit 1
  fi

  CFG["$key"]="$value"
}

is_ipv4() {
  local ip="$1"
  [[ "$ip" =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]] || return 1
  IFS='.' read -r o1 o2 o3 o4 <<< "$ip"
  for o in "$o1" "$o2" "$o3" "$o4"; do
    (( o >= 0 && o <= 255 )) || return 1
  done
  return 0
}

require_ipv4() {
  local key="$1"
  local ip="${CFG[$key]}"
  if ! is_ipv4 "$ip"; then
    echo "ERROR: $key has invalid IPv4 address: $ip" >&2
    exit 1
  fi
}

require_unique_values() {
  local label="$1"
  shift
  local -A seen=()
  local key value
  for key in "$@"; do
    value="${CFG[$key]}"
    if [[ -n "${seen[$value]:-}" ]]; then
      echo "ERROR: duplicate $label detected: '$value' used for both ${seen[$value]} and $key" >&2
      exit 1
    fi
    seen["$value"]="$key"
  done
}

to_lower() {
  printf '%s' "$1" | tr '[:upper:]' '[:lower:]'
}

derive_defaults() {
  CFG["RAC1_FQDN"]="${CFG[RAC1_HOST]}.${CFG[DOMAIN]}"
  CFG["RAC2_FQDN"]="${CFG[RAC2_HOST]}.${CFG[DOMAIN]}"

  CFG["RAC1_VIP"]="${CFG[RAC1_HOST]}-vip"
  CFG["RAC2_VIP"]="${CFG[RAC2_HOST]}-vip"
  CFG["RAC1_VIP_FQDN"]="${CFG[RAC1_VIP]}.${CFG[DOMAIN]}"
  CFG["RAC2_VIP_FQDN"]="${CFG[RAC2_VIP]}.${CFG[DOMAIN]}"

  CFG["SCAN_NAME"]="mzr-scan"
  CFG["SCAN_FQDN"]="${CFG[SCAN_NAME]}.${CFG[DOMAIN]}"

  CFG["SERVICE_NAME"]="$(to_lower "${CFG[PDB_NAME]}")_service"
}

validate_all() {
  # IPv4 checks
  require_ipv4 RAC1_PUBLIC_IP
  require_ipv4 RAC1_PRIV_IP
  require_ipv4 RAC1_VIP_IP
  require_ipv4 RAC2_PUBLIC_IP
  require_ipv4 RAC2_PRIV_IP
  require_ipv4 RAC2_VIP_IP
  require_ipv4 SCAN_IP1
  require_ipv4 SCAN_IP2
  require_ipv4 SCAN_IP3

  # Unique hostnames
  require_unique_values "hostname" \
    RAC1_HOST RAC2_HOST RAC1_VIP RAC2_VIP SCAN_NAME \
    RAC1_FQDN RAC2_FQDN RAC1_VIP_FQDN RAC2_VIP_FQDN SCAN_FQDN

  # Unique IP addresses
  require_unique_values "IP address" \
    RAC1_PUBLIC_IP RAC1_PRIV_IP RAC1_VIP_IP \
    RAC2_PUBLIC_IP RAC2_PRIV_IP RAC2_VIP_IP \
    SCAN_IP1 SCAN_IP2 SCAN_IP3

  # Interface sanity
  if [[ "${CFG[PUBLIC_IFACE]}" == "${CFG[PRIVATE_IFACE]}" ]]; then
    echo "ERROR: PUBLIC_IFACE and PRIVATE_IFACE cannot be the same." >&2
    exit 1
  fi

  # DB/PDB distinct
  if [[ "${CFG[DB_NAME]}" == "${CFG[PDB_NAME]}" ]]; then
    echo "ERROR: DB_NAME and PDB_NAME must be different." >&2
    exit 1
  fi

  # Diskgroups distinct
  require_unique_values "diskgroup" DATA_DG FRA_DG OCR_DG
}

write_ini() {
  cat > "$TMP" <<EOF
DOMAIN=${CFG[DOMAIN]}

RAC1_HOST=${CFG[RAC1_HOST]}
RAC1_FQDN=${CFG[RAC1_FQDN]}
RAC1_PUBLIC_IP=${CFG[RAC1_PUBLIC_IP]}
RAC1_PRIV_IP=${CFG[RAC1_PRIV_IP]}
RAC1_VIP=${CFG[RAC1_VIP]}
RAC1_VIP_FQDN=${CFG[RAC1_VIP_FQDN]}
RAC1_VIP_IP=${CFG[RAC1_VIP_IP]}

RAC2_HOST=${CFG[RAC2_HOST]}
RAC2_FQDN=${CFG[RAC2_FQDN]}
RAC2_PUBLIC_IP=${CFG[RAC2_PUBLIC_IP]}
RAC2_PRIV_IP=${CFG[RAC2_PRIV_IP]}
RAC2_VIP=${CFG[RAC2_VIP]}
RAC2_VIP_FQDN=${CFG[RAC2_VIP_FQDN]}
RAC2_VIP_IP=${CFG[RAC2_VIP_IP]}

SCAN_NAME=${CFG[SCAN_NAME]}
SCAN_FQDN=${CFG[SCAN_FQDN]}
SCAN_IP1=${CFG[SCAN_IP1]}
SCAN_IP2=${CFG[SCAN_IP2]}
SCAN_IP3=${CFG[SCAN_IP3]}

PUBLIC_IFACE=${CFG[PUBLIC_IFACE]}
PRIVATE_IFACE=${CFG[PRIVATE_IFACE]}

GRID_BASE=${CFG[GRID_BASE]}
GRID_HOME=${CFG[GRID_HOME]}
ORACLE_BASE=${CFG[ORACLE_BASE]}
DB_HOME=${CFG[DB_HOME]}
ORA_INVENTORY=${CFG[ORA_INVENTORY]}
STAGE_DIR=${CFG[STAGE_DIR]}

DB_ZIP=${CFG[DB_ZIP]}
GRID_ZIP=${CFG[GRID_ZIP]}

DB_NAME=${CFG[DB_NAME]}
PDB_NAME=${CFG[PDB_NAME]}
SERVICE_NAME=${CFG[SERVICE_NAME]}
SYS_PASSWORD=${CFG[SYS_PASSWORD]}
SYSTEM_PASSWORD=${CFG[SYSTEM_PASSWORD]}

DATA_DG=${CFG[DATA_DG]}
FRA_DG=${CFG[FRA_DG]}
OCR_DG=${CFG[OCR_DG]}
FRA_SIZE_MB=${CFG[FRA_SIZE_MB]}
DB_TOTAL_MEMORY_MB=${CFG[DB_TOTAL_MEMORY_MB]}
EOF

  mv "$TMP" "$OUT"
  chmod 600 "$OUT"
}

echo "Creating RAC 26ai environment input file: $OUT"
echo "Only unique inputs are requested; repeated values are derived automatically."
echo

prompt DOMAIN             "Domain name"                       "lab.maz"

prompt RAC1_HOST          "RAC1 hostname short"               "mzr1"
prompt RAC1_PUBLIC_IP     "RAC1 public IP"                    "192.168.56.60"
prompt RAC1_PRIV_IP       "RAC1 private IP"                   "192.168.57.60"
prompt RAC1_VIP_IP        "RAC1 VIP IP"                       "192.168.56.82"

prompt RAC2_HOST          "RAC2 hostname short"               "mzr2"
prompt RAC2_PUBLIC_IP     "RAC2 public IP"                    "192.168.56.61"
prompt RAC2_PRIV_IP       "RAC2 private IP"                   "192.168.57.61"
prompt RAC2_VIP_IP        "RAC2 VIP IP"                       "192.168.56.83"

prompt SCAN_IP1           "SCAN IP1"                          "192.168.56.84"
prompt SCAN_IP2           "SCAN IP2"                          "192.168.56.85"
prompt SCAN_IP3           "SCAN IP3"                          "192.168.56.86"

prompt PUBLIC_IFACE       "Public interface"                  "enp0s3"
prompt PRIVATE_IFACE      "Private interface"                 "enp0s8"

prompt GRID_BASE          "Grid base"                         "/u01/app/grid"
prompt GRID_HOME          "Grid home"                         "/u01/app/26ai/grid"
prompt ORACLE_BASE        "Oracle base"                       "/u01/app/oracle"
prompt DB_HOME            "DB home"                           "/u01/app/oracle/product/26ai/dbhome_1"
prompt ORA_INVENTORY      "OraInventory"                      "/u01/app/oraInventory"
prompt STAGE_DIR          "Stage dir"                         "/stage"

prompt DB_ZIP             "DB zip file name"                  "LINUX.X64_260000_db_home.zip"
prompt GRID_ZIP           "Grid zip file name"                "LINUX.X64_260000_grid_home.zip"

prompt DB_NAME            "CDB name"                          "TESTCDB"
prompt PDB_NAME           "PDB name"                          "TESTPDB"
prompt_secret SYS_PASSWORD    "SYS password"                  "RacAttack123"
prompt_secret SYSTEM_PASSWORD "SYSTEM/PDB password"           "RacAttack123"

prompt DATA_DG            "DATA diskgroup"                    "DATA"
prompt FRA_DG             "FRA diskgroup"                     "FRA"
prompt OCR_DG             "OCR diskgroup"                     "OCR"
prompt FRA_SIZE_MB        "FRA size MB for DBCA"              "8000"
prompt DB_TOTAL_MEMORY_MB "DB memory MB"                      "1024"

derive_defaults
validate_all
write_ini

echo
echo "Created: $OUT"
echo "Derived values:"
echo "  RAC1_FQDN=${CFG[RAC1_FQDN]}"
echo "  RAC2_FQDN=${CFG[RAC2_FQDN]}"
echo "  RAC1_VIP_FQDN=${CFG[RAC1_VIP_FQDN]}"
echo "  RAC2_VIP_FQDN=${CFG[RAC2_VIP_FQDN]}"
echo "  SCAN_FQDN=${CFG[SCAN_FQDN]}"
echo "  SERVICE_NAME=${CFG[SERVICE_NAME]}"
echo
echo "Validation passed: no duplicate hostnames/IPs detected."
