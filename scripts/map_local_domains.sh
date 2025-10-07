#!/usr/bin/env bash
set -euo pipefail

# Maps local.254carbon domains to the active ingress load balancer IP.

DOMAINS=(
  "api.local.254carbon"
  "stream.local.254carbon"
  "mlflow.local.254carbon"
  "keycloak.local.254carbon"
)

CLUSTER_NAME="${CLUSTER_NAME:-local-254carbon}"
SERVICE_NAME="${SERVICE_NAME:-ingress-nginx-controller}"
SERVICE_NAMESPACE="${SERVICE_NAMESPACE:-ingress-nginx}"
DEFAULT_HOSTS_FILE="/etc/hosts"

BLOCK_START="# >>> 254carbon local domains start"
BLOCK_END="# <<< 254carbon local domains end"

KUBECTL_CONTEXT=""
HOSTS_FILE="${HOSTS_FILE:-$DEFAULT_HOSTS_FILE}"
OVERRIDE_IP=""
DRY_RUN=0

usage() {
  cat <<'EOF'
Usage: map_local_domains.sh [options]

Options:
  --hosts-file PATH   Hosts file to update (default: /etc/hosts or $HOSTS_FILE)
  --context NAME      kubectl context to use when discovering the load balancer IP
  --ip ADDRESS        Explicit IP/hostname to use instead of auto-detection
  --dry-run           Print the resulting hosts file content instead of writing
  -h, --help          Show this help message

Environment overrides:
  HOSTS_FILE          Alternate hosts file path
  CLUSTER_NAME        k3d cluster name (default: local-254carbon)
  SERVICE_NAME        Kubernetes service name (default: ingress-nginx-controller)
  SERVICE_NAMESPACE   Kubernetes namespace (default: ingress-nginx)
EOF
}

log() {
  printf '[+] %s\n' "$1"
}

detect_lb_ip() {
  local context_args=()
  if [[ -n "$KUBECTL_CONTEXT" ]]; then
    context_args=(--context "$KUBECTL_CONTEXT")
  fi

  if command -v kubectl >/dev/null 2>&1; then
    local ip hostname
    ip="$(kubectl "${context_args[@]}" get svc "$SERVICE_NAME" -n "$SERVICE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi

    hostname="$(kubectl "${context_args[@]}" get svc "$SERVICE_NAME" -n "$SERVICE_NAMESPACE" -o jsonpath='{.status.loadBalancer.ingress[0].hostname}' 2>/dev/null || true)"
    if [[ -n "$hostname" ]]; then
      case "$hostname" in
        localhost | 127.0.0.1)
          echo "127.0.0.1"
          return 0
          ;;
      esac

      if command -v dig >/dev/null 2>&1; then
        ip="$(dig +short "$hostname" 2>/dev/null | head -n1 || true)"
        if [[ -n "$ip" ]]; then
          echo "$ip"
          return 0
        fi
      fi
    fi
  fi

  if command -v docker >/dev/null 2>&1; then
    local container="k3d-${CLUSTER_NAME}-serverlb"
    local ip
    ip="$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "$container" 2>/dev/null || true)"
    if [[ -n "$ip" ]]; then
      echo "$ip"
      return 0
    fi
  fi

  echo "127.0.0.1"
}

remove_existing_block() {
  local file="$1"
  awk -v start="$BLOCK_START" -v end="$BLOCK_END" '
    $0 == start {skip=1; next}
    $0 == end {skip=0; next}
    skip != 1 {print}
  ' "$file"
}

update_hosts_file() {
  local ip="$1"
  local file="$2"
  local dry_run="$3"

  if [[ "$dry_run" -ne 1 ]]; then
    if [[ -e "$file" ]]; then
      if [[ ! -w "$file" ]]; then
        printf 'ERROR: Unable to write to %s. Try running with sudo or adjust HOSTS_FILE.\n' "$file" >&2
        exit 1
      fi
    else
      local parent
      parent="$(dirname "$file")"
      if [[ ! -w "$parent" ]]; then
        printf 'ERROR: Unable to create %s. Try running with sudo or adjust HOSTS_FILE.\n' "$file" >&2
        exit 1
      fi
      touch "$file"
    fi
  fi

  local tmp
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT

  if [[ -e "$file" ]]; then
    remove_existing_block "$file" > "$tmp"
  else
    : > "$tmp"
  fi

  {
    echo "$BLOCK_START"
    printf '# Generated on %s\n' "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
    for domain in "${DOMAINS[@]}"; do
      printf '%-15s %s\n' "$ip" "$domain"
    done
    echo "$BLOCK_END"
  } >> "$tmp"

  if [[ "$dry_run" -eq 1 ]]; then
    cat "$tmp"
  else
    cat "$tmp" > "$file"
  fi

  rm -f "$tmp"
  trap - EXIT
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --hosts-file)
      [[ $# -lt 2 ]] && { printf 'ERROR: --hosts-file requires a value\n' >&2; exit 1; }
      HOSTS_FILE="$2"
      shift 2
      ;;
    --context)
      [[ $# -lt 2 ]] && { printf 'ERROR: --context requires a value\n' >&2; exit 1; }
      KUBECTL_CONTEXT="$2"
      shift 2
      ;;
    --ip)
      [[ $# -lt 2 ]] && { printf 'ERROR: --ip requires a value\n' >&2; exit 1; }
      OVERRIDE_IP="$2"
      shift 2
      ;;
    --dry-run)
      DRY_RUN=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      printf 'ERROR: Unknown option: %s\n' "$1" >&2
      usage
      exit 1
      ;;
  esac
done

if [[ -n "$OVERRIDE_IP" ]]; then
  LB_IP="$OVERRIDE_IP"
else
  LB_IP="$(detect_lb_ip)"
fi

if [[ -z "$LB_IP" ]]; then
  printf 'ERROR: Unable to determine load balancer IP. Provide one via --ip.\n' >&2
  exit 1
fi

log "Using load balancer endpoint: $LB_IP"
log "Updating hosts file: $HOSTS_FILE"
update_hosts_file "$LB_IP" "$HOSTS_FILE" "$DRY_RUN"

if [[ "$DRY_RUN" -eq 1 ]]; then
  log "Dry run complete; no changes were written."
else
  log "Hosts file updated with 254carbon local domain mappings."
fi
