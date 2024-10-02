# Automatically monitor macOS extensive CPU usage

### Why

This macOS CPU monitoring script automatically tracks resource usage across all applications, addressing the challenge of identifying performance-impacting processes. It sends notifications when apps exceed CPU thresholds, enabling user to quickly manage power-hungry tasks. Ideal for developers, content creators, and power users. Lightweight and integrated with macOS, offers ongoing monitoring without significant system overhead.

## Setup

1. Download [the script](https://github.com/vladzima/mac-cpu-monitor/blob/main/setup_cpu_monitor.sh) and save it to your home directory (/Users/YOUR_USERNAME).
2. Open Terminal and run the following command to make the script executable:

```
chmod +x cpu_monitor.sh
```

3. Run the script with the following command:

```
./cpu_monitor.sh
```

4. The script will start monitoring CPU usage and send notifications when thresholds are exceeded.

## Usage Instructions:

The monitoring starts automatically when you log in.

- To reconfigure CPU monitoring:
`~/setup_cpu_monitor.sh`


- To stop CPU monitoring:
`~/setup_cpu_monitor.sh stop`


- To manually start monitoring after stopping:
`launchctl load ~/Library/LaunchAgents/com.user.cpumonitor.plist`


**Note:** You will receive notifications when CPU usage exceeds the set thresholds.
