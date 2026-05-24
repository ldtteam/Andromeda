#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Safely expands Kubernetes worker VM disks via Ansible (one node at a time).
Each worker is drained, its Proxmox VM disk is grown, guest storage is expanded,
then the node is optionally rebooted and uncordoned once Ready again.

Options:
  -z, --size <size>             Disk growth amount (default: 10G)
  -l, --limit <pattern>         Limit to a subset of nodes (e.g. k8s_worker, 350-kubernetes)
  -s, --skip-nodes <n1,n2,...>  Comma-separated node names to skip
  -f, --force-reboot            Reboot after disk expansion
  -e, --extra-vars <vars>       Pass extra variables to ansible-playbook (key=value)
  -v, --verbose                 Increase Ansible verbosity (repeat for more: -vvv)
  -h, --help                    Show this help message
EOF
}

LIMIT=""
SKIP_NODES=""
EXTRA_VARS=()
VERBOSE=""
FORCE_REBOOT=false
SIZE="10G"

while [[ $# -gt 0 ]]; do
  case "$1" in
    -z|--size)         SIZE="$2";               shift 2 ;;
    -l|--limit)        LIMIT="$2";              shift 2 ;;
    -s|--skip-nodes)   SKIP_NODES="$2";         shift 2 ;;
    -f|--force-reboot) FORCE_REBOOT=true;        shift   ;;
    -e|--extra-vars)   EXTRA_VARS+=(-e "$2");   shift 2 ;;
    -v|--verbose)      VERBOSE="${VERBOSE}v";   shift   ;;
    -h|--help)         usage; exit 0                     ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1      ;;
  esac
done

build_limit() {
  local pattern="${LIMIT:-k8s_worker}"
  if [[ -n "$SKIP_NODES" ]]; then
    IFS=',' read -ra nodes <<< "$SKIP_NODES"
    for node in "${nodes[@]}"; do
      pattern="${pattern}:!${node}"
    done
  fi
  echo "$pattern"
}

ANSIBLE_ARGS=(--limit "$(build_limit)")

[[ -n "$VERBOSE" ]] && ANSIBLE_ARGS+=("-${VERBOSE}")
EXTRA_VARS+=(-e "k8s_worker_disk_expand_size=${SIZE}")
"${FORCE_REBOOT}" && EXTRA_VARS+=(-e "k8s_worker_disk_expand_force_reboot=true")

ANSIBLE_ARGS+=("${EXTRA_VARS[@]+"${EXTRA_VARS[@]}"}")

cd "${SYSTEM_DIR}"

echo "==> Running Kubernetes worker disk expansion playbook"
echo "    Working directory : ${SYSTEM_DIR}"
echo "    Limit             : $(build_limit)"
echo "    Skip nodes        : ${SKIP_NODES:-none}"
echo "    Expand by         : ${SIZE}"
echo "    Force reboot      : ${FORCE_REBOOT}"
echo ""

ansible-playbook playbooks/expand-kubernetes-worker-disks.yml "${ANSIBLE_ARGS[@]}"

