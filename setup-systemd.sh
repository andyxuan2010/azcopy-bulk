#!/bin/bash
# setup-systemd.sh - Script to set up systemd service and timer for azcopy-bulk.sh
# Usage: ./setup-systemd.sh [interval_minutes] [username]

set -euo pipefail

# Default values
INTERVAL_MINUTES="${1:-5}"
USERNAME="${2:-$USER}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_PATH="${SCRIPT_DIR}/azcopy-bulk.sh"

echo "Setting up systemd service for azcopy-bulk.sh"
echo "Script path: ${SCRIPT_PATH}"
echo "Interval: ${INTERVAL_MINUTES} minutes"
echo "User: ${USERNAME}"

# Check if running as root or with sudo
if [[ $EUID -ne 0 ]]; then
    echo "This script must be run as root or with sudo"
    echo "Usage: sudo ./setup-systemd.sh [interval_minutes] [username]"
    exit 1
fi

# Check if script exists
if [[ ! -f "${SCRIPT_PATH}" ]]; then
    echo "ERROR: azcopy-bulk.sh not found at ${SCRIPT_PATH}"
    exit 1
fi

# Make script executable
chmod +x "${SCRIPT_PATH}"

# Create log directory
LOG_DIR="/home/${USERNAME}/.azcopy_logs"
mkdir -p "${LOG_DIR}"
chown "${USERNAME}:${USERNAME}" "${LOG_DIR}"

# Create environment file
ENV_FILE="/home/${USERNAME}/.azcopy-env"
cat > "${ENV_FILE}" << EOF
# Environment variables for azcopy-bulk.sh systemd service
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

chown "${USERNAME}:${USERNAME}" "${ENV_FILE}"

echo "Created environment file: ${ENV_FILE}"
echo "Please edit ${ENV_FILE} to set your SRC_PATH and DEST_URL values"

# Create service file
SERVICE_FILE="/etc/systemd/system/azcopy-bulk.service"
cat > "${SERVICE_FILE}" << EOF
[Unit]
Description=AzCopy Bulk Sync Service
After=network.target

[Service]
Type=oneshot
User=${USERNAME}
Group=${USERNAME}
WorkingDirectory=${SCRIPT_DIR}
EnvironmentFile=${ENV_FILE}
ExecStart=${SCRIPT_PATH}
StandardOutput=append:${LOG_DIR}/service.log
StandardError=append:${LOG_DIR}/service.log

[Install]
WantedBy=multi-user.target
EOF

# Create timer file
TIMER_FILE="/etc/systemd/system/azcopy-bulk.timer"
cat > "${TIMER_FILE}" << EOF
[Unit]
Description=Run AzCopy Bulk Sync every ${INTERVAL_MINUTES} minutes
Requires=azcopy-bulk.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=${INTERVAL_MINUTES}min

[Install]
WantedBy=timers.target
EOF

# Reload systemd
systemctl daemon-reload

# Enable the timer
systemctl enable azcopy-bulk.timer

echo "✅ Systemd service and timer created successfully!"
echo ""
echo "Service file: ${SERVICE_FILE}"
echo "Timer file: ${TIMER_FILE}"
echo "Environment file: ${ENV_FILE}"
echo ""

# Ask user if they want to start the timer
read -p "Do you want to start the timer now? (y/N): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    systemctl start azcopy-bulk.timer
    echo "✅ Timer started!"
    
    # Show status
    echo ""
    echo "Timer status:"
    systemctl status azcopy-bulk.timer --no-pager
    echo ""
    echo "Next run times:"
    systemctl list-timers azcopy-bulk.timer --no-pager
else
    echo "To start the timer manually, run:"
    echo "sudo systemctl start azcopy-bulk.timer"
fi

echo ""
echo "📋 Next steps:"
echo "1. Edit ${ENV_FILE} to set your SRC_PATH and DEST_URL"
echo "2. Test the script manually: ${SCRIPT_PATH}"
echo "3. Start the timer: sudo systemctl start azcopy-bulk.timer"
echo "4. Monitor logs in: ${LOG_DIR}"
echo ""
echo "🔧 Useful commands:"
echo "  Start timer: sudo systemctl start azcopy-bulk.timer"
echo "  Stop timer: sudo systemctl stop azcopy-bulk.timer"
echo "  Check status: sudo systemctl status azcopy-bulk.timer"
echo "  View logs: sudo journalctl -u azcopy-bulk.service -f"
echo "  List timers: sudo systemctl list-timers azcopy-bulk.timer"
echo "  Disable timer: sudo systemctl disable azcopy-bulk.timer"
