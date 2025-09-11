# Automatically monitor macOS extensive CPU usage

### Why

This macOS CPU monitoring script automatically tracks resource usage across all applications, addressing the challenge of identifying performance-impacting processes. It sends notifications when apps exceed CPU thresholds, enabling user to quickly manage power-hungry tasks. Ideal for developers, content creators, and power users. Lightweight and integrated with macOS, offers ongoing monitoring without significant system overhead.

## Setup

1. Download [the script](setup_cpu_monitor.sh) and save it to your home directory, e.g. `~/Applications/`.
2. Open Terminal and run the following command to make the script executable:

```
chmod +x setup_cpu_monitor.sh
```

3. Run the script with the following command:

```
./setup_cpu_monitor.sh
```

4. Configure the desired thresholds as prompted.
5. The script will start monitoring CPU usage and send notifications when thresholds are exceeded.

> [!NOTE]
> You will receive notifications when CPU usage exceeds the set thresholds.

## Usage Instructions

The monitoring starts automatically when you log in.

- To reconfigure CPU monitoring:<br>
`~/setup_cpu_monitor.sh`


- To stop CPU monitoring:<br>
`~/setup_cpu_monitor.sh stop`


- To manually start monitoring after stopping:<br>
`launchctl enable gui/$(id -u)/com.user.cpumonitor && launchctl bootstrap gui/$(id -u) "~/Library/LaunchAgents/com.user.cpumonitor.plist"`


## FAQ

### What are good thresholds for my Mac?
Don't worry: the script evaluates your available CPU cores as a baseline to suggest suitable values based on the following calculations:

- Single Process % CPU usage threshold: 25% of total capacity
- Overall System % CPU threshold: 85% of total capacity
- Check interval: 60 seconds per core
