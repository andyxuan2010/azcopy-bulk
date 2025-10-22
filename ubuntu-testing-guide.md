# Ubuntu Testing and Monitoring Guide for azcopy-bulk.sh

## Quick Start Commands

### Copy files to Ubuntu and set up
```bash
# 1. Copy files to your Ubuntu system
scp azcopy-bulk.sh setup-cron.sh setup-systemd.sh ubuntu-setup-instructions.md user@your-ubuntu-server:/home/user/

# 2. SSH into your Ubuntu system
ssh user@your-ubuntu-server

# 3. Navigate to the directory
cd /home/user/

# 4. Make scripts executable
chmod +x *.sh
```

## Method 1: Cron Setup (Recommended for simple scheduling)

### Automated Setup
```bash
# Run the automated setup script
./setup-cron.sh

# Or customize interval (every 10 minutes)
./setup-cron.sh 10
```

### Manual Setup
```bash
# 1. Create environment file
cat > ~/.azcopy-env << 'EOF'
export SRC_PATH="/data"
export DEST_URL="https://yourstorageaccount.blob.core.windows.net/container"
export MODE="sync"
export RECURSIVE="true"
export OVERWRITE="true"
export PUT_MD5="false"
export CAP_MBPS="0"
export CONCURRENCY="auto"
export LOG_DIR="$HOME/.azcopy_logs"
export EXCLUDE_PATTERN=""
export INCLUDE_PATTERN=""
export DRY_RUN="false"
export AZCOPY_PATH="azcopy"
EOF

# 2. Create wrapper script
cat > ~/azcopy-cron-wrapper.sh << 'EOF'
#!/bin/bash
source ~/.azcopy-env
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CRON_LOG="$HOME/.azcopy_logs/cron_${TIMESTAMP}.log"
echo "$(date): Starting azcopy-bulk.sh cron job" >> "$HOME/.azcopy_logs/cron.log"
cd /home/user/
./azcopy-bulk.sh >> "${CRON_LOG}" 2>&1
EXIT_CODE=$?
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo "$(date): azcopy-bulk.sh completed successfully" >> "$HOME/.azcopy_logs/cron.log"
else
    echo "$(date): azcopy-bulk.sh failed with exit code ${EXIT_CODE}" >> "$HOME/.azcopy_logs/cron.log"
fi
exit ${EXIT_CODE}
EOF

chmod +x ~/azcopy-cron-wrapper.sh

# 3. Add cron job
crontab -e
# Add this line: */5 * * * * ~/azcopy-cron-wrapper.sh
```

## Method 2: Systemd Service (Recommended for system-level services)

### Automated Setup
```bash
# Run as root or with sudo
sudo ./setup-systemd.sh

# Or customize interval and user
sudo ./setup-systemd.sh 10 username
```

### Manual Setup
```bash
# 1. Create service file
sudo tee /etc/systemd/system/azcopy-bulk.service > /dev/null << EOF
[Unit]
Description=AzCopy Bulk Sync Service
After=network.target

[Service]
Type=oneshot
User=username
Group=username
WorkingDirectory=/home/username
EnvironmentFile=/home/username/.azcopy-env
ExecStart=/home/username/azcopy-bulk.sh
StandardOutput=append:/home/username/.azcopy_logs/service.log
StandardError=append:/home/username/.azcopy_logs/service.log

[Install]
WantedBy=multi-user.target
EOF

# 2. Create timer file
sudo tee /etc/systemd/system/azcopy-bulk.timer > /dev/null << EOF
[Unit]
Description=Run AzCopy Bulk Sync every 5 minutes
Requires=azcopy-bulk.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
EOF

# 3. Enable and start
sudo systemctl daemon-reload
sudo systemctl enable azcopy-bulk.timer
sudo systemctl start azcopy-bulk.timer
```

## Testing Before Scheduling

### 1. Test Environment Variables
```bash
# Load environment
source ~/.azcopy-env

# Check variables
echo "SRC_PATH: $SRC_PATH"
echo "DEST_URL: $DEST_URL"
echo "MODE: $MODE"
```

### 2. Test AzCopy Installation
```bash
# Check if azcopy is installed
which azcopy
azcopy --version

# If not installed, install it
# For Ubuntu/Debian:
wget https://aka.ms/downloadazcopy-v10-linux
tar -xvf downloadazcopy-v10-linux
sudo cp ./azcopy_linux_amd64_*/azcopy /usr/local/bin/
```

### 3. Test Script Manually
```bash
# Test with dry run first
export DRY_RUN="true"
./azcopy-bulk.sh

# Test actual run
export DRY_RUN="false"
./azcopy-bulk.sh
```

### 4. Test Wrapper Script (for cron)
```bash
# Test the wrapper
~/azcopy-cron-wrapper.sh

# Check logs
tail -f ~/.azcopy_logs/cron.log
```

### 5. Test Systemd Service (for systemd)
```bash
# Test the service manually
sudo systemctl start azcopy-bulk.service

# Check service status
sudo systemctl status azcopy-bulk.service

# View logs
sudo journalctl -u azcopy-bulk.service -f
```

## Monitoring and Troubleshooting

### Cron Monitoring
```bash
# View cron logs
tail -f ~/.azcopy_logs/cron.log

# List cron jobs
crontab -l

# View system cron logs
sudo tail -f /var/log/syslog | grep CRON

# Check cron service
sudo systemctl status cron
```

### Systemd Monitoring
```bash
# Check timer status
sudo systemctl status azcopy-bulk.timer

# List timer schedule
sudo systemctl list-timers azcopy-bulk.timer

# View service logs
sudo journalctl -u azcopy-bulk.service -f

# View timer logs
sudo journalctl -u azcopy-bulk.timer -f

# Check service status
sudo systemctl status azcopy-bulk.service
```

### General Monitoring
```bash
# Check AzCopy logs
ls -la ~/.azcopy_logs/
tail -20 ~/.azcopy_logs/run_*.log

# Check disk space
df -h

# Check network connectivity
ping -c 3 yourstorageaccount.blob.core.windows.net

# Check running processes
ps aux | grep azcopy
```

## Common Issues and Solutions

### Issue 1: Environment Variables Not Loaded
```bash
# Solution: Ensure .azcopy-env is sourced
source ~/.azcopy-env
echo $SRC_PATH
```

### Issue 2: Permission Denied
```bash
# Solution: Check and fix permissions
ls -la azcopy-bulk.sh
chmod +x azcopy-bulk.sh
```

### Issue 3: AzCopy Not Found
```bash
# Solution: Install or set correct path
which azcopy
export AZCOPY_PATH="/usr/local/bin/azcopy"
```

### Issue 4: Network Issues
```bash
# Solution: Check network and firewall
ping yourstorageaccount.blob.core.windows.net
sudo ufw status
```

### Issue 5: Storage Account Access
```bash
# Solution: Check SAS token or authentication
azcopy list "https://yourstorageaccount.blob.core.windows.net/container?sv=2021-06-08&ss=bfqt&srt=sco&sp=rwdlacupitfx&se=2024-01-01T00:00:00Z&st=2023-01-01T00:00:00Z&spr=https&sig=..."
```

## Useful Commands Summary

### Cron Management
```bash
# Add cron job
crontab -e

# List cron jobs
crontab -l

# Remove cron job
crontab -e  # Delete the line

# View cron logs
tail -f ~/.azcopy_logs/cron.log
```

### Systemd Management
```bash
# Start timer
sudo systemctl start azcopy-bulk.timer

# Stop timer
sudo systemctl stop azcopy-bulk.timer

# Enable timer (start on boot)
sudo systemctl enable azcopy-bulk.timer

# Disable timer
sudo systemctl disable azcopy-bulk.timer

# Check status
sudo systemctl status azcopy-bulk.timer

# View logs
sudo journalctl -u azcopy-bulk.service -f
```

### Script Management
```bash
# Test script
./azcopy-bulk.sh

# Test with different settings
export DRY_RUN="true"
export MODE="copy"
./azcopy-bulk.sh

# View logs
tail -f ~/.azcopy_logs/run_*.log
```
