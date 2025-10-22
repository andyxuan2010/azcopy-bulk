# Ubuntu Cron Setup Instructions for azcopy-bulk.sh

## Method 1: Using the Automated Setup Script

1. **Copy the files to your Ubuntu system:**
   ```bash
   # Make sure you have the following files in your Ubuntu system:
   # - azcopy-bulk.sh
   # - setup-cron.sh
   ```

2. **Run the setup script:**
   ```bash
   # Make executable and run
   chmod +x setup-cron.sh
   ./setup-cron.sh
   
   # Or customize the interval (e.g., every 10 minutes)
   ./setup-cron.sh 10
   ```

3. **Edit the environment file:**
   ```bash
   nano .azcopy-env
   # Set your SRC_PATH and DEST_URL values
   ```

## Method 2: Manual Cron Setup

### Step 1: Create Environment File
```bash
# Create environment file
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
```

### Step 2: Create Wrapper Script
```bash
# Create wrapper script
cat > ~/azcopy-cron-wrapper.sh << 'EOF'
#!/bin/bash
# Load environment variables
source ~/.azcopy-env

# Set up logging
TIMESTAMP=$(date +%Y%m%d_%H%M%S)
CRON_LOG="$HOME/.azcopy_logs/cron_${TIMESTAMP}.log"

# Log start time
echo "$(date): Starting azcopy-bulk.sh cron job" >> "$HOME/.azcopy_logs/cron.log"

# Run the main script
cd /path/to/your/azcopy-bulk
./azcopy-bulk.sh >> "${CRON_LOG}" 2>&1
EXIT_CODE=$?

# Log completion
if [[ ${EXIT_CODE} -eq 0 ]]; then
    echo "$(date): azcopy-bulk.sh completed successfully" >> "$HOME/.azcopy_logs/cron.log"
else
    echo "$(date): azcopy-bulk.sh failed with exit code ${EXIT_CODE}" >> "$HOME/.azcopy_logs/cron.log"
fi

exit ${EXIT_CODE}
EOF

chmod +x ~/azcopy-cron-wrapper.sh
```

### Step 3: Add Cron Job
```bash
# Edit crontab
crontab -e

# Add this line (runs every 5 minutes):
*/5 * * * * ~/azcopy-cron-wrapper.sh

# Or every 10 minutes:
*/10 * * * * ~/azcopy-cron-wrapper.sh

# Or every hour at minute 0:
0 * * * * ~/azcopy-cron-wrapper.sh
```

## Method 3: Systemd Service (Alternative to Cron)

### Step 1: Create Service File
```bash
sudo nano /etc/systemd/system/azcopy-bulk.service
```

Add this content:
```ini
[Unit]
Description=AzCopy Bulk Sync Service
After=network.target

[Service]
Type=oneshot
User=yourusername
Group=yourusername
WorkingDirectory=/path/to/your/azcopy-bulk
EnvironmentFile=/home/yourusername/.azcopy-env
ExecStart=/path/to/your/azcopy-bulk/azcopy-bulk.sh
StandardOutput=append:/home/yourusername/.azcopy_logs/service.log
StandardError=append:/home/yourusername/.azcopy_logs/service.log

[Install]
WantedBy=multi-user.target
```

### Step 2: Create Timer File
```bash
sudo nano /etc/systemd/system/azcopy-bulk.timer
```

Add this content:
```ini
[Unit]
Description=Run AzCopy Bulk Sync every 5 minutes
Requires=azcopy-bulk.service

[Timer]
OnBootSec=5min
OnUnitActiveSec=5min

[Install]
WantedBy=timers.target
```

### Step 3: Enable and Start
```bash
# Reload systemd
sudo systemctl daemon-reload

# Enable the timer
sudo systemctl enable azcopy-bulk.timer

# Start the timer
sudo systemctl start azcopy-bulk.timer

# Check status
sudo systemctl status azcopy-bulk.timer
sudo systemctl list-timers azcopy-bulk.timer
```

## Testing and Monitoring

### Test the Script Manually
```bash
# Test environment loading
source ~/.azcopy-env
echo "SRC_PATH: $SRC_PATH"
echo "DEST_URL: $DEST_URL"

# Test the main script
./azcopy-bulk.sh

# Test the wrapper
~/azcopy-cron-wrapper.sh
```

### Monitor Cron Jobs
```bash
# View cron logs
tail -f ~/.azcopy_logs/cron.log

# List current cron jobs
crontab -l

# View system cron logs
sudo tail -f /var/log/syslog | grep CRON

# Check if cron service is running
sudo systemctl status cron
```

### Monitor Systemd Service
```bash
# View service logs
sudo journalctl -u azcopy-bulk.service -f

# View timer logs
sudo journalctl -u azcopy-bulk.timer -f

# Check timer status
sudo systemctl list-timers azcopy-bulk.timer
```

## Troubleshooting

### Common Issues:
1. **Environment variables not loaded**: Make sure the `.azcopy-env` file is sourced
2. **Permission denied**: Check file permissions with `ls -la`
3. **Path issues**: Use absolute paths in cron/systemd
4. **AzCopy not found**: Install azcopy or set correct path in AZCOPY_PATH

### Debug Commands:
```bash
# Check if azcopy is installed
which azcopy
azcopy --version

# Test environment
env | grep -E "(SRC_PATH|DEST_URL)"

# Check logs
ls -la ~/.azcopy_logs/
tail -20 ~/.azcopy_logs/cron.log
```

## Useful Cron Patterns

```bash
# Every 5 minutes
*/5 * * * *

# Every 10 minutes
*/10 * * * *

# Every hour at minute 0
0 * * * *

# Every 2 hours
0 */2 * * *

# Daily at 2 AM
0 2 * * *

# Weekdays only at 9 AM
0 9 * * 1-5

# Monthly on the 1st at midnight
0 0 1 * *
```
