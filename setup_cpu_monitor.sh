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

# Function to stop monitoring
stop_monitoring() {
    launchctl unload ~/Library/LaunchAgents/com.user.cpumonitor.plist 2>/dev/null
    echo -e "${GREEN}CPU monitoring stopped.${NC}"
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
    read -p "$(echo -e ${YELLOW}$prompt [$default]: ${NC})" value
    echo "${value:-$default}"
}

# Prompt for configuration
echo -e "${BOLD}${BLUE}CPU Monitoring Setup${NC}"
echo -e "${CYAN}Please configure the following settings:${NC}\n"
cpu_threshold=$(prompt_with_default "Enter CPU usage threshold percentage" 50)
system_threshold=$(prompt_with_default "Enter overall system CPU threshold percentage" 200)
check_interval=$(prompt_with_default "Enter check interval in seconds" 300)

# Create the monitoring script
cat << EOF > ~/cpu_monitor.sh
#!/bin/bash

# Function to send notification
send_notification() {
    /usr/bin/osascript -e "display notification \"\$1\" with title \"CPU Usage Alert\" subtitle \"\$2\""
}

# Set the CPU usage threshold (in percentage)
CPU_THRESHOLD=$cpu_threshold

# Get the list of all processes with their CPU usage, sort by CPU usage descending
process_list=\$(/bin/ps -A -o %cpu,comm | sort -nr)

# Initialize a variable to store high CPU processes
high_cpu_processes=""

# Check each process
while read -r cpu_usage app_name; do
    # Check if cpu_usage is a valid number
    if [[ \$cpu_usage =~ ^[0-9]+([.][0-9]+)?\$ ]]; then
        # Compare usage to threshold
        if (( \$(echo "\$cpu_usage > \$CPU_THRESHOLD" | bc -l) )); then
            # Add this process to our list of high CPU processes
            high_cpu_processes+="\$app_name: \${cpu_usage}%\n"
        else
            # Since the list is sorted, we can break once we hit a process below threshold
            break
        fi
    fi
done <<< "\$process_list"

# If we found any high CPU processes, send a notification
if [ ! -z "\$high_cpu_processes" ]; then
    message="The following processes are using high CPU:\n\$high_cpu_processes"
    send_notification "\$message" "High CPU Usage"
fi

# Check overall system CPU usage
total_cpu=\$(/bin/ps -A -o %cpu | awk '{s+=\$1} END {print s}')
system_threshold=$system_threshold

if (( \$(echo "\$total_cpu > \$system_threshold" | bc -l) )); then
    message="Overall CPU usage is high: \${total_cpu}%"
    send_notification "\$message" "System Alert"
fi
EOF

# Make the script executable
chmod +x ~/cpu_monitor.sh

# Create the launchd plist file
cat << EOF > ~/Library/LaunchAgents/com.user.cpumonitor.plist
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.cpumonitor</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$HOME/cpu_monitor.sh</string>
    </array>
    <key>StartInterval</key>
    <integer>$check_interval</integer>
    <key>RunAtLoad</key>
    <true/>
</dict>
</plist>
EOF

# Load the launchd job
launchctl unload ~/Library/LaunchAgents/com.user.cpumonitor.plist 2>/dev/null
launchctl load ~/Library/LaunchAgents/com.user.cpumonitor.plist

# Display setup information and usage instructions
echo -e "\n${BOLD}${GREEN}CPU Monitoring Setup Complete${NC}"

echo -e "\n${BOLD}${CYAN}Configuration:${NC}"
echo -e "- CPU usage threshold: ${YELLOW}$cpu_threshold%${NC}"
echo -e "- System CPU threshold: ${YELLOW}$system_threshold%${NC}"
echo -e "- Check interval: Every ${YELLOW}$check_interval seconds${NC}"

echo -e "\n${BOLD}${MAGENTA}Usage Instructions:${NC}"
echo -e "1. The monitoring is now active and will start automatically when you log in."
echo -e "\n2. To reconfigure CPU monitoring:"
echo -e "   ${BLUE}~/setup_cpu_monitor.sh${NC}"
echo -e "\n3. To stop CPU monitoring:"
echo -e "   ${BLUE}~/setup_cpu_monitor.sh stop${NC}"
echo -e "\n4. To manually start monitoring after stopping:"
echo -e "   ${BLUE}launchctl load ~/Library/LaunchAgents/com.user.cpumonitor.plist${NC}"

echo -e "\n${BOLD}${RED}Note:${NC} You will receive notifications when CPU usage exceeds the set thresholds."
