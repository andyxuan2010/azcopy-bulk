# ...existing code...
#!/usr/bin/env bash
# azcopy_bulk.sh — Robust AzCopy wrapper for large uploads/downloads (e.g., 1+ TB)
# Usage examples at bottom of file.

set -euo pipefail

### ====== USER CONFIG (env vars override) ======
SRC_PATH="${SRC_PATH:-/data}"                     # Local file/dir to upload OR remote URL to download from
DEST_URL="${DEST_URL:-}"                          # Full dest URL (Blob or ADLS) OR local path to download into; can include SAS
MODE="${MODE:-copy}"                              # copy | sync
RECURSIVE="${RECURSIVE:-true}"                    # true | false
OVERWRITE="${OVERWRITE:-true}"                    # true | false (copy only)
PUT_MD5="${PUT_MD5:-false}"                       # true to upload MD5 for integrity auditing (only used when uploading)
CAP_MBPS="${CAP_MBPS:-0}"                         # 0 = unlimited; set e.g. 400 to cap
CONCURRENCY="${CONCURRENCY:-auto}"                # auto or integer (e.g., 64)
LOG_DIR="${LOG_DIR:-$HOME/.azcopy_logs}"          # AzCopy keeps its own logs; we also tee stdout here
EXCLUDE_PATTERN="${EXCLUDE_PATTERN:-}"            # e.g. "*.tmp;*.log"
INCLUDE_PATTERN="${INCLUDE_PATTERN:-}"            # e.g. "*.parquet;*.csv"
DRY_RUN="${DRY_RUN:-false}"                       # true = just print the command
AZCOPY_PATH="${AZCOPY_PATH:-azcopy}"              # path to azcopy if not in $PATH
### ============================================

if [[ -z "${DEST_URL}" ]]; then
  echo "ERROR: DEST_URL is required. Export it or pass inline (see examples below)." >&2
  exit 1
fi

# Detect whether SRC_PATH is a remote Azure URL (download scenario) or local path (upload scenario).
IS_REMOTE_SRC=false
if [[ "${SRC_PATH}" =~ ^https?:// ]] || [[ "${SRC_PATH}" == *".dfs.core.windows.net"* ]] || [[ "${SRC_PATH}" == *".blob.core.windows.net"* ]]; then
  IS_REMOTE_SRC=true
fi

# If SRC is local, validate it exists. If SRC is remote, ensure DEST (local) exists or will be created.
if [[ "${IS_REMOTE_SRC}" == "false" ]]; then
  if [[ ! -e "${SRC_PATH}" ]]; then
    echo "ERROR: SRC_PATH does not exist: ${SRC_PATH}" >&2
    exit 1
  fi
else
  # Ensure destination local path exists (create if needed)
  if [[ ! -e "${DEST_URL}" ]]; then
    mkdir -p "${DEST_URL}" || true
  fi
fi

mkdir -p "${LOG_DIR}"
STAMP="$(date +%Y%m%d_%H%M%S)"
RUN_LOG="${LOG_DIR}/run_${STAMP}.log"

# Optional: pin concurrency
if [[ "${CONCURRENCY}" != "auto" ]]; then
  export AZCOPY_CONCURRENCY_VALUE="${CONCURRENCY}"
fi

# Build common flags
FLAGS=( "--recursive=${RECURSIVE}" "--cap-mbps=${CAP_MBPS}" "--log-level=INFO" )
# Skip length pre-check for speed on huge trees (safer to keep true; disable with CHECK_LENGTH=false)
CHECK_LENGTH="${CHECK_LENGTH:-true}"
if [[ "${CHECK_LENGTH}" == "false" ]]; then
  FLAGS+=( "--check-length=false" )
fi
# Overwrite policy (copy only)
if [[ "${MODE}" == "copy" ]]; then
  FLAGS+=( "--overwrite=${OVERWRITE}" )
fi
# MD5: only apply when uploading to remote destination
if [[ "${PUT_MD5}" == "true" && "${IS_REMOTE_SRC}" == "false" ]]; then
  FLAGS+=( "--put-md5" )
fi
# Include/Exclude patterns
if [[ -n "${EXCLUDE_PATTERN}" ]]; then
  FLAGS+=( "--exclude-pattern=${EXCLUDE_PATTERN}" )
fi
if [[ -n "${INCLUDE_PATTERN}" ]]; then
  FLAGS+=( "--include-pattern=${INCLUDE_PATTERN}" )
fi

# Determine remote endpoint for nicer logging and validation commands
if [[ "${IS_REMOTE_SRC}" == "true" ]]; then
  REMOTE_URL="${SRC_PATH}"
  LOCAL_PATH="${DEST_URL}"
else
  REMOTE_URL="${DEST_URL}"
  LOCAL_PATH="${SRC_PATH}"
fi

if [[ "${REMOTE_URL}" == *".dfs.core.windows.net"* ]]; then
  TARGET_KIND="ADLS Gen2"
elif [[ "${REMOTE_URL}" == *".blob.core.windows.net"* ]]; then
  TARGET_KIND="Blob Storage"
else
  TARGET_KIND="Unknown Endpoint"
fi

DIRECTION="upload"
if [[ "${IS_REMOTE_SRC}" == "true" ]]; then
  DIRECTION="download"
fi

echo "========== AzCopy Bulk ${MODE^^} (${DIRECTION^^}) =========="
echo "Source         : ${SRC_PATH}"
echo "Destination    : ${DEST_URL}"
echo "Remote Endpoint: ${REMOTE_URL}"
echo "Endpoint Type  : ${TARGET_KIND}"
echo "Recursive      : ${RECURSIVE}"
echo "Overwrite      : ${OVERWRITE:-n/a}"
echo "Put MD5        : ${PUT_MD5} (applies only when uploading)"
echo "Cap Mbps       : ${CAP_MBPS}"
echo "Concurrency    : ${CONCURRENCY}"
echo "Log file       : ${RUN_LOG}"
echo "==========================================="

# Build azcopy command
if [[ "${MODE}" == "sync" ]]; then
  # Sync only changes; by default, won't delete extra files at destination unless --delete-destination=true
  DELETE_DEST="${DELETE_DEST:-false}"   # true | false
  SYNC_FLAGS=( "--delete-destination=${DELETE_DEST}" )
  # For sync the order is the same: src then dest
  CMD=( "${AZCOPY_PATH}" sync "${SRC_PATH}" "${DEST_URL}" )
  CMD+=( "${FLAGS[@]}" )
  CMD+=( "${SYNC_FLAGS[@]}" )
else
  # copy mode: azcopy copy <src> <dest>
  CMD=( "${AZCOPY_PATH}" copy "${SRC_PATH}" "${DEST_URL}" )
  CMD+=( "${FLAGS[@]}" )
fi

echo "Command:"
printf '  %q ' "${CMD[@]}"; echo

if [[ "${DRY_RUN}" == "true" ]]; then
  echo "DRY_RUN=true — exiting before execution."
  exit 0
fi

# Run and tee output
set +e
"${CMD[@]}" 2>&1 | tee -a "${RUN_LOG}"
EXIT_CODE=${PIPESTATUS[0]}
set -e

if [[ ${EXIT_CODE} -ne 0 ]]; then
  echo "AzCopy returned ${EXIT_CODE}. Attempting resume if job exists..." | tee -a "${RUN_LOG}"
  echo "Existing jobs:" | tee -a "${RUN_LOG}"
  "${AZCOPY_PATH}" jobs list | tee -a "${RUN_LOG}" || true

  # Optional: auto-resume last job (uncomment to enable naive resume)
  # LAST_JOB_ID="$("${AZCOPY_PATH}" jobs list | awk '/JobId/ {print $2}' | tail -n1)"
  # if [[ -n "${LAST_JOB_ID}" ]]; then
  #   echo "Resuming JobId: ${LAST_JOB_ID}" | tee -a "${RUN_LOG}"
  #   "${AZCOPY_PATH}" jobs resume "${LAST_JOB_ID}" 2>&1 | tee -a "${RUN_LOG}"
  # fi
  echo "Check detailed logs in ~/.azcopy and ${RUN_LOG}"
  exit "${EXIT_CODE}"
fi

echo "✅ Transfer completed."
echo "Tip: Use 'azcopy list \"${REMOTE_URL}\"' to validate objects on the remote endpoint."
# ...existing code...