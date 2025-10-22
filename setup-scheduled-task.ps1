# PowerShell script to create a scheduled task for azcopy-bulk.sh
# Run this script as Administrator

param(
    [string]$TaskName = "AzCopy-Bulk-Sync",
    [string]$ScriptPath = ".\azcopy-bulk.sh",
    [int]$IntervalMinutes = 5,
    [string]$Description = "Automated AzCopy bulk sync every 5 minutes"
)

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Error "This script must be run as Administrator. Please run PowerShell as Administrator and try again."
    exit 1
}

# Get the full path to the script
$FullScriptPath = Resolve-Path $ScriptPath -ErrorAction Stop
Write-Host "Script path: $FullScriptPath"

# Get the directory containing the script
$ScriptDirectory = Split-Path $FullScriptPath -Parent
Write-Host "Script directory: $ScriptDirectory"

# Create the action (command to run)
$Action = New-ScheduledTaskAction -Execute "bash.exe" -Argument "`"$FullScriptPath`"" -WorkingDirectory $ScriptDirectory

# Create the trigger (every 5 minutes)
$Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date) -RepetitionInterval (New-TimeSpan -Minutes $IntervalMinutes) -RepetitionDuration (New-TimeSpan -Days 365)

# Create task settings
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -RunOnlyIfNetworkAvailable

# Create the principal (run as current user)
$Principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType InteractiveToken

# Register the scheduled task
try {
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Settings $Settings -Principal $Principal -Description $Description -Force
    Write-Host "✅ Scheduled task '$TaskName' created successfully!" -ForegroundColor Green
    Write-Host "The task will run every $IntervalMinutes minutes starting from now." -ForegroundColor Yellow
    
    # Show task info
    $Task = Get-ScheduledTask -TaskName $TaskName
    Write-Host "`nTask Details:" -ForegroundColor Cyan
    Write-Host "  Name: $($Task.TaskName)"
    Write-Host "  State: $($Task.State)"
    Write-Host "  Next Run Time: $((Get-ScheduledTask -TaskName $TaskName | Get-ScheduledTaskInfo).NextRunTime)"
    
    Write-Host "`nTo manage this task:" -ForegroundColor Cyan
    Write-Host "  View: Get-ScheduledTask -TaskName '$TaskName' | Get-ScheduledTaskInfo"
    Write-Host "  Start: Start-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Stop: Stop-ScheduledTask -TaskName '$TaskName'"
    Write-Host "  Remove: Unregister-ScheduledTask -TaskName '$TaskName' -Confirm:`$false"
    
} catch {
    Write-Error "Failed to create scheduled task: $($_.Exception.Message)"
    exit 1
}

Write-Host "`n⚠️  Important Notes:" -ForegroundColor Yellow
Write-Host "1. Make sure bash.exe is available in your PATH (Git Bash, WSL, or MSYS2)"
Write-Host "2. Ensure your environment variables (SRC_PATH, DEST_URL, etc.) are set correctly"
Write-Host "3. Test the script manually first: bash '$FullScriptPath'"
Write-Host "4. Check Task Scheduler logs if the task doesn't run as expected"
