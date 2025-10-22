#!/bin/bash
# setup-cron.sh - Script to set up cron job for azcopy-bulk.sh in Ubuntu
# Usage: ./setup-cron.sh [interval_minutes] [task_name]

set -euo pipefail

# Default values
INTERVAL_MINUTES="${1:-5}"
TASK_NAME="${2:-azcopy-bulk-sync}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/azcopy-bulk.sh"

echo "Setting up cron job for azcopy-bulk.sh"
echo "Script path: ${SCRIPT_PATH}"
echo "Interval: ${INTERVAL_MINUTES} minutes"
echo "Task name: ${TASK_NAME}"

# Check if script exists
if [[ ! -f "${SCRIPT_PATH}" ]]; then
    echo "ERROR: azcopy-bulk.sh not found at ${SCRIPT_PATH}"
    exit 1
fi

# Make script executable
chmod +x "${SCRIPT_PATH}"

# Create log directory if it doesn't exist
LOG_DIR="${HOME}/.azcopy_logs"
mkdir -p "${LOG_DIR}"

# Create environment file for cron
ENV_FILE="${SCRIPT_DIR}/.azcopy-env"
cat > "${ENV_FILE}" << EOF
# Environment variables for azcopy-bulk.sh cron job
# Edit these values as needed

# Required variables
export SRC_PATH="/data"
export DEST_URL=""

# Optional variables
export MODE="sync"
export RECURSIVE="true"
export OVERWRITE="true"
export PUT_MD5="false"
export CAP_MBPS="0"
export CONCURRENCY="auto"
export LOG_DIR="${LOG_DIR}"
export EXCLUDE_PATTERN=""
export INCLUDE_PATTERN=""
export DRY_RUN="false"
export AZCOPY_PATH="azcopy"

# Add any additional environment variables here
EOF

echo "Created environment file: ${ENV_FILE}"
echo "Please edit ${ENV_FILE} to set your SRC_PATH and DEST_URL values"

# Create wrapper script for cron
WRAPPER_SCRIPT="${SCRIPT_DIR}/azcopy-cron-wrapper.sh"
cat > "${WRAPPER_SCRIPT}" << EOF
#!/bin/bash
# Wrapper script for azcopy-bulk.sh to run in cron environment

# Load environment variables
source "${ENV_FILE}"

# Set up logging
TIMESTAMP=\$(date +%Y%m%d_%H%M%S)
CRON_LOG="${LOG_DIR}/cron_\${TIMESTAMP}.log"

# Log start time
echo "\$(date): Starting azcopy-bulk.sh cron job" >> "${LOG_DIR}/cron.log"

# Run the main script
cd "${SCRIPT_DIR}"
"${SCRIPT_PATH}" >> "\${CRON_LOG}" 2>&1
EXIT_CODE=\$?

# Log completion
if [[ \${EXIT_CODE} -eq 0 ]]; then
    echo "\$(date): azcopy-bulk.sh completed successfully" >> "${LOG_DIR}/cron.log"
else
    echo "\$(date): azcopy-bulk.sh failed with exit code \${EXIT_CODE}" >> "${LOG_DIR}/cron.log"
fi

exit \${EXIT_CODE}
EOF

chmod +x "${WRAPPER_SCRIPT}"

# Create cron entry
CRON_ENTRY="*/${INTERVAL_MINUTES} * * * * ${WRAPPER_SCRIPT}"

echo ""
echo "Cron entry to add:"
echo "${CRON_ENTRY}"
echo ""

# Ask user if they want to add it automatically
read -p "Do you want to add this cron job automatically? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Backup current crontab
    crontab -l > "${SCRIPT_DIR}/crontab.backup.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
    
    # Add new cron job
    (crontab -l 2>/dev/null; echo "${CRON_ENTRY}") | crontab -
    
    echo "✅ Cron job added successfully!"
    echo ""
    echo "Current crontab:"
    crontab -l
else
    echo "To add the cron job manually, run:"
    echo "crontab -e"
    echo ""
    echo "Then add this line:"
    echo "${CRON_ENTRY}"
fi

echo ""
echo "📋 Next steps:"
echo "1. Edit ${ENV_FILE} to set your SRC_PATH and DEST_URL"
echo "2. Test the script manually: ${SCRIPT_PATH}"
echo "3. Test the wrapper: ${WRAPPER_SCRIPT}"
echo "4. Monitor logs in: ${LOG_DIR}"
echo ""
echo "🔧 Useful commands:"
echo "  View cron logs: tail -f ${LOG_DIR}/cron.log"
echo "  List cron jobs: crontab -l"
echo "  Remove cron job: crontab -e (then delete the line)"
echo "  Test wrapper: ${WRAPPER_SCRIPT}"
