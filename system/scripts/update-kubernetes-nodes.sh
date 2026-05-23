#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Safely updates all Kubernetes nodes via Ansible (one at a time).
Each node is drained and upgraded in parallel, then rebooted if needed,
and uncordoned once Ready again.

Options:
  -l, --limit <pattern>        Limit to a subset of nodes (e.g. k8s_worker, 300-kubernetes)
  -s, --skip-nodes <n1,n2,...> Comma-separated node names to skip (already updated today)
  -f, --force-reboot           Reboot even if no pending reboot-required flag is present
  -e, --extra-vars <vars>      Pass extra variables to ansible-playbook (key=value)
  -v, --verbose                Increase Ansible verbosity (repeat for more: -vvv)
  -h, --help                   Show this help message
EOF
}

LIMIT=""
SKIP_NODES=""
EXTRA_VARS=()
VERBOSE=""
FORCE_REBOOT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--limit)        LIMIT="$2";              shift 2 ;;
    -s|--skip-nodes)   SKIP_NODES="$2";         shift 2 ;;
    -f|--force-reboot) FORCE_REBOOT=true;       shift   ;;
    -e|--extra-vars)   EXTRA_VARS+=(-e "$2");   shift 2 ;;
    -v|--verbose)      VERBOSE="${VERBOSE}v";   shift   ;;
    -h|--help)         usage; exit 0                    ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1     ;;
  esac
done

# Build the Ansible --limit pattern. Start from the base group/pattern,
# then append :!nodename exclusions for each skipped node.
build_limit() {
  local pattern="${LIMIT:-kubernetes}"
  if [[ -n "$SKIP_NODES" ]]; then
    IFS=',' read -ra nodes <<< "$SKIP_NODES"
    for node in "${nodes[@]}"; do
      pattern="${pattern}:!${node}"
    done
  fi
  echo "$pattern"
}

ANSIBLE_ARGS=(--limit "$(build_limit)")

[[ -n "$VERBOSE" ]]  && ANSIBLE_ARGS+=("-${VERBOSE}")
"${FORCE_REBOOT}"    && EXTRA_VARS+=(-e "k8s_node_update_force_reboot=true")

ANSIBLE_ARGS+=("${EXTRA_VARS[@]+"${EXTRA_VARS[@]}"}")

cd "${SYSTEM_DIR}"

echo "==> Running Kubernetes node update playbook"
echo "    Working directory : ${SYSTEM_DIR}"
echo "    Limit             : $(build_limit)"
echo "    Skip nodes        : ${SKIP_NODES:-none}"
echo "    Force reboot      : ${FORCE_REBOOT}"
echo ""

ansible-playbook playbooks/update-kubernetes-nodes.yml "${ANSIBLE_ARGS[@]}"
