#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SYSTEM_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

usage() {
  cat <<EOF
Usage: $(basename "$0") [OPTIONS]

Installs required tool packages (nfs-common, open-iscsi, …) on all
Kubernetes nodes via Ansible.

Options:
  -l, --limit <pattern>        Limit to a subset of nodes (e.g. k8s_worker, 300-kubernetes)
  -s, --skip-nodes <n1,n2,...> Comma-separated node names to skip
  -p, --packages <pkg1,pkg2>   Override the package list (comma-separated)
  -e, --extra-vars <vars>      Pass extra variables to ansible-playbook (key=value)
  -v, --verbose                Increase Ansible verbosity (repeat for more: -vvv)
  -h, --help                   Show this help message
EOF
}

LIMIT=""
SKIP_NODES=""
PACKAGES=""
EXTRA_VARS=()
VERBOSE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    -l|--limit)       LIMIT="$2";            shift 2 ;;
    -s|--skip-nodes)  SKIP_NODES="$2";       shift 2 ;;
    -p|--packages)    PACKAGES="$2";         shift 2 ;;
    -e|--extra-vars)  EXTRA_VARS+=(-e "$2"); shift 2 ;;
    -v|--verbose)     VERBOSE="${VERBOSE}v"; shift   ;;
    -h|--help)        usage; exit 0                  ;;
    *) echo "Unknown option: $1" >&2; usage; exit 1  ;;
  esac
done

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

[[ -n "$VERBOSE" ]] && ANSIBLE_ARGS+=("-${VERBOSE}")

if [[ -n "$PACKAGES" ]]; then
  # Convert comma-separated list to a YAML sequence for Ansible
  pkg_yaml="[$(echo "$PACKAGES" | sed "s/,/, /g" | sed "s/[^ ,][^ ,]*/'\0'/g")]"
  EXTRA_VARS+=(-e "k8s_node_packages_list=${pkg_yaml}")
fi

ANSIBLE_ARGS+=("${EXTRA_VARS[@]+"${EXTRA_VARS[@]}"}")

cd "${SYSTEM_DIR}"

echo "==> Running Kubernetes node package installation playbook"
echo "    Working directory : ${SYSTEM_DIR}"
echo "    Limit             : $(build_limit)"
echo "    Skip nodes        : ${SKIP_NODES:-none}"
echo "    Packages override : ${PACKAGES:-<role defaults>}"
echo ""

ansible-playbook playbooks/install-node-packages.yml "${ANSIBLE_ARGS[@]}"

