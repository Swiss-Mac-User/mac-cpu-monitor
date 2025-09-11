#!/bin/bash

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Settings
launchd_plist="$HOME/Library/LaunchAgents/com.user.cpumonitor.plist"
save_script="$(cd "$(dirname "$0")" && pwd)/cpu_monitor.sh"
user_uid=$(id -u)

# Function to stop monitoring
stop_monitoring() {
    launchctl disable gui/$user_uid/com.user.cpumonitor
    launchctl bootout gui/$user_uid/com.user.cpumonitor

    echo -e "🛑 ${BOLD}${RED}CPU monitoring stopped.${NC}"
    echo -e "\nTo manually re-start monitoring with same thresholds:"
    echo -e "   ${BLUE}launchctl enable gui/$user_uid/com.user.cpumonitor && launchctl bootstrap gui/$user_uid "$launchd_plist"${NC}"
    exit 0
}

# Check if the user wants to stop monitoring
if [[ "$1" == "stop" ]]; then
    stop_monitoring
fi

# Function to prompt for user input with a default value
prompt_with_default() {
    local prompt="$1"
    local default="$2"
    read -p "$(echo -e ${YELLOW}$prompt [recommended: $default]: ${NC})" value
    echo "${value:-$default}"
}

# Evaluate system for recommended thresholds
number_cores="$(sysctl -n hw.ncpu)"
# > assumption: 25% of total system capacity, clamped to [min: 120%, max: 400%]
cpu_threshold_recommended=$(( $number_cores * 100 * 25 / 100 ))
[ "$cpu_threshold_recommended" -lt 120 ] && cpu_threshold_recommended=120
[ "$cpu_threshold_recommended" -gt 400 ] && cpu_threshold_recommended=400
# > assumption: 85% of total system capacity
system_threshold_recommended=$(( $number_cores * 100 * 85 / 100 ))
# > assumption: 60s per core, clamp to [min: 1minute, max: 10minute]
check_interval_recommended=$(( $number_cores * 60 ))
[ "$check_interval_recommended" -lt 60 ] && check_interval_recommended=60
[ "$check_interval_recommended" -gt 600 ] && check_interval_recommended=600

# Prompt for configuration using calculated recommendations
echo -e "${BOLD}${BLUE}CPU Monitoring Setup${NC}\n"
echo -e "${CYAN}Please configure the following settings:${NC}"
echo -e "[ Your System: ${BOLD}$number_cores${NC} CPU cores (= $(( $number_cores * 100 ))% total capacity) ]\n"
cpu_threshold=$(prompt_with_default "Enter single Process % CPU usage threshold" $cpu_threshold_recommended)
system_threshold=$(prompt_with_default "Enter overall System % CPU threshold" $system_threshold_recommended)
check_interval=$(prompt_with_default "Enter check interval in seconds" $check_interval_recommended)

# Create the monitoring script
cat << EOF > "$save_script"
#!/bin/bash

# Function to send notification
send_notification() {
    osascript -e "display notification \"\$1\" with title \"CPU Usage Alert\" subtitle \"\$2\""
}

# Set the CPU usage threshold (in percentage)
CPU_THRESHOLD=$cpu_threshold

# Get the list of all processes with their CPU usage, sort by CPU usage descending
process_list=\$(ps -A -r -o %cpu,comm)

# Initialize a variable to store high CPU processes
high_cpu_processes=""

# Check each process
while read -r cpu_usage app_name; do
    # Check if cpu_usage is a valid number
    if [[ \$cpu_usage =~ ^[0-9]+([.][0-9]+)?\$ ]]; then
        # Compare usage to threshold
        if (( \$(echo "\$cpu_usage > \$CPU_THRESHOLD" | bc -l) )); then
            # Extract just the app name from the full path
            app_display_name=\$(basename "\$app_name")
            # Add this process to our list of high CPU processes
            high_cpu_processes+="\$app_display_name | \${cpu_usage}%\n"
        else
            # Since the list is sorted, we can break once we hit a process below threshold
            break
        fi
    fi
done <<< "\$process_list"

# If we found any high CPU processes, send a notification
if [ ! -z "\$high_cpu_processes" ]; then
    message="\$high_cpu_processes"
    send_notification "\$message" "📈 Processes using high CPU"
fi

# Check overall system CPU usage
total_cpu=\$(ps -A -o %cpu | awk '{s+=\$1} END {print s}')
system_threshold=$system_threshold

if (( \$(echo "\$total_cpu > \$system_threshold" | bc -l) )); then
    message="\${total_cpu}%"
    send_notification "🔥 \$message" "Overall System CPU usage is high"
fi
EOF

# Make the script executable
chmod +x "$save_script"

# Create the launchd plist file
cat << EOF > "$launchd_plist"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.cpumonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$save_script</string>
    </array>
    <key>StartInterval</key>
    <integer>$check_interval</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the launchd job
launchctl bootout gui/$user_uid "$launchd_plist" 2>/dev/null || true
launchctl enable gui/$user_uid/com.user.cpumonitor
launchctl bootstrap gui/$user_uid "$launchd_plist"
launchctl kickstart -k gui/$user_uid/com.user.cpumonitor

# Calculate percentage of total capacity (with proper decimal handling)
single_process_percent=$(echo "scale=1; $cpu_threshold / $number_cores" | bc -l)
system_percent=$(echo "scale=1; $system_threshold / $number_cores" | bc -l)
check_interval_minutes=$(( $check_interval / 60 ))

# Display setup information and usage instructions
echo -e "\n✅ ${BOLD}${GREEN}CPU Monitoring Setup Complete${NC}"
echo -e "${BOLD}The monitoring is now ${GREEN}active${NC} and will start automatically when you log in."
echo -e "${BOLD}${YELLOW}Note:${NC} You will receive notifications when CPU usage exceeds the set thresholds."

echo -e "\n${BOLD}${CYAN}Alerting Thresholds:${NC}"
echo -e "- Single Process % CPU usage threshold: ${YELLOW}$cpu_threshold%${NC} (${single_process_percent}% of total capacity)"
echo -e "- Overall System % CPU threshold: ${YELLOW}$system_threshold%${NC} (${system_percent}% of total capacity)"
echo -e "- Check interval: Every ${YELLOW}$check_interval seconds${NC} ($check_interval_minutes minute$([ "$check_interval_minutes" -ne 1 ] && echo "s"))"

echo -e "\nℹ️ ${BOLD}${MAGENTA}Usage Instructions:${NC}"
echo -e "\n1. To reconfigure CPU monitoring:"
echo -e "   ${BLUE}$(printf '%q' $0)${NC}"
echo -e "\n2. To stop CPU monitoring:"
echo -e "   ${BLUE}$(printf '%q' $0) stop${NC}"
echo -e "\n3. To manually start monitoring after stopping:"
echo -e "   ${BLUE}launchctl kickstart gui/$user_uid/com.user.cpumonitor${NC}"
