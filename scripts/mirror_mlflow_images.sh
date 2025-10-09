#!/usr/bin/env bash
#
# Mirror upstream MLflow container images into 254Carbon's GHCR org.
#
# Why:
#   - The default Bitnami chart pulls from Docker Hub and registry-1.docker.io.
#   - Many clusters (and all prod clusters here) block anonymous Docker Hub access.
#   - We mirror the exact images we depend on so the Helm release uses GHCR exclusively.
#
# Requirements:
#   - `crane` (https://github.com/google/go-containerregistry) installed and on PATH.
#   - GHCR write access (`gh auth login` or docker login ghcr.io).
#   - Environment variables below can be customised as needed.

set -euo pipefail

GHCR_REPO_PREFIX=${GHCR_REPO_PREFIX:-ghcr.io/254carbon/mirror}
CRANE_VERSION=${CRANE_VERSION:-v0.20.2}
CRANE_IMAGE=${CRANE_IMAGE:-gcr.io/go-containerregistry/crane:latest}
CRANE_BIN_DIR=${CRANE_BIN_DIR:-$(pwd)/.bin}
CRANE_BIN="${CRANE_BIN_DIR}/crane"

# Source digests lifted from bitnami/mlflow chart v5.1.17 render (2024-02 snapshot).
# Override via environment variables if Bitnami publishes new builds.
BITNAMI_OS_SHELL_DIGEST=${BITNAMI_OS_SHELL_DIGEST:-sha256:028f4ddeecd0edbe82884513e2bd14268fdc8b04899a826bd840521949700857}
BITNAMI_OS_SHELL_SOURCE_REF=${BITNAMI_OS_SHELL_SOURCE_REF:-docker.io/bitnami/os-shell@${BITNAMI_OS_SHELL_DIGEST}}
BITNAMI_OS_SHELL_TARGET_TAG=${BITNAMI_OS_SHELL_TARGET_TAG:-12-debian-12-r51}

BITNAMI_MLFLOW_DIGEST=${BITNAMI_MLFLOW_DIGEST:-sha256:590fd5ec61f17efa7d8fa9968791cfd85809763c79a589b58c2519d9a303a94c}
BITNAMI_MLFLOW_SOURCE_REF=${BITNAMI_MLFLOW_SOURCE_REF:-registry-1.docker.io/bitnamicharts/mlflow@${BITNAMI_MLFLOW_DIGEST}}
BITNAMI_MLFLOW_TARGET_TAG=${BITNAMI_MLFLOW_TARGET_TAG:-bitnami-5.1.17}

declare -a CRANE_CMD
if command -v crane >/dev/null 2>&1; then
  CRANE_CMD=(crane)
else
  if [ ! -x "${CRANE_BIN}" ]; then
    echo "[mirror] 'crane' binary not found. Attempting to download release ${CRANE_VERSION}"
    mkdir -p "${CRANE_BIN_DIR}"

    OS=$(uname -s)
    ARCH=$(uname -m)

    case "${OS}" in
      Linux) TAR_OS="Linux" ;;
      Darwin) TAR_OS="Darwin" ;;
      *)
        echo "[mirror] unsupported OS: ${OS}. Install 'crane' manually." >&2
        TAR_OS=""
        ;;
    esac

    case "${ARCH}" in
      x86_64|amd64) TAR_ARCH="x86_64" ;;
      arm64|aarch64) TAR_ARCH="arm64" ;;
      *)
        echo "[mirror] unsupported architecture: ${ARCH}. Install 'crane' manually." >&2
        TAR_ARCH=""
        ;;
    esac

    if [ -n "${TAR_OS}" ] && [ -n "${TAR_ARCH}" ]; then
      TARBALL="go-containerregistry_${TAR_OS}_${TAR_ARCH}.tar.gz"
      URL="https://github.com/google/go-containerregistry/releases/download/${CRANE_VERSION}/${TARBALL}"
      if command -v curl >/dev/null 2>&1; then
        if ! curl -sSfL "${URL}" | tar -xz -C "${CRANE_BIN_DIR}" crane; then
          echo "[mirror] download failed from ${URL}" >&2
        fi
      elif command -v wget >/dev/null 2>&1; then
        if ! wget -qO- "${URL}" | tar -xz -C "${CRANE_BIN_DIR}" crane; then
          echo "[mirror] download failed from ${URL}" >&2
        fi
      else
        echo "[mirror] install 'curl' or 'wget' to download crane, or install crane manually." >&2
      fi
    fi

    if [ -x "${CRANE_BIN}" ]; then
      chmod +x "${CRANE_BIN}"
      CRANE_CMD=("${CRANE_BIN}")
    else
      if ! command -v docker >/dev/null 2>&1; then
        echo "[mirror] could not provision 'crane' automatically and Docker is unavailable. Install crane manually." >&2
        exit 1
      fi

      DOCKER_CONFIG_DIR=${DOCKER_CONFIG:-$HOME/.docker}
      echo "[mirror] download failed or unsupported platform. Falling back to container image ${CRANE_IMAGE}"
      CRANE_CMD=(
        docker run --rm
        -v "${DOCKER_CONFIG_DIR}:/root/.docker"
        -v "$(pwd):/workspace"
        -w /workspace
        "${CRANE_IMAGE}"
      )
    fi
  else
    CRANE_CMD=("${CRANE_BIN}")
  fi
fi

run_crane() {
  "${CRANE_CMD[@]}" "$@"
}

# Attempt to log in to GHCR using GitHub CLI credentials unless opted out.
if [ -z "${SKIP_GHCR_AUTO_LOGIN:-}" ] && command -v gh >/dev/null 2>&1; then
  if gh auth status >/dev/null 2>&1; then
    GHCR_USERNAME=${GHCR_USERNAME:-$(gh api user --jq '.login' 2>/dev/null || echo "")}
    GHCR_TOKEN=$(gh auth status -t --hostname github.com 2>&1 | awk '/Token:/ {print $NF}' | tail -n1)
    if [ -n "${GHCR_USERNAME}" ] && [ -n "${GHCR_TOKEN}" ]; then
      if ! run_crane auth login ghcr.io -u "${GHCR_USERNAME}" -p "${GHCR_TOKEN}" >/dev/null 2>&1; then
        echo "[mirror] warning: automatic ghcr login via gh cli failed; falling back to existing docker credentials" >&2
      fi
    else
      echo "[mirror] warning: gh auth token unavailable; ensure 'docker login ghcr.io' succeeds before mirroring." >&2
    fi
  fi
fi

# Source image → target image mappings.
# Keep the upstream digest/tag in comments so we can validate drift quickly.
IMAGES=(
  "${BITNAMI_OS_SHELL_SOURCE_REF}=${GHCR_REPO_PREFIX}/os-shell:${BITNAMI_OS_SHELL_TARGET_TAG}"
  "${BITNAMI_MLFLOW_SOURCE_REF}=${GHCR_REPO_PREFIX}/mlflow-bitnami:${BITNAMI_MLFLOW_TARGET_TAG}"
)

for mapping in "${IMAGES[@]}"; do
  src="${mapping%%=*}"
  dst="${mapping#*=}"

  echo "[mirror] copying ${src} -> ${dst}"
  run_crane copy \
    --platform=linux/amd64 \
    --platform=linux/arm64 \
    "${src}" \
    "${dst}"
done

echo "[mirror] done. Remember to push signed attestations if required by policy."
