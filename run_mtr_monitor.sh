#!/bin/bash

# ----------------------
# Prompt for Target IP/Host (default: 8.8.8.8)
# ----------------------
read -rp "Enter the target IP or hostname to monitor [default: 8.8.8.8]: " TARGET
TARGET=${TARGET:-8.8.8.8}

# ----------------------
# Prompt for Duration (default: 24h)
# ----------------------
read -rp "Enter how long to run the monitor (e.g. 3d, 12h, 30m) [default: 24h]: " DURATION_INPUT
DURATION_INPUT=${DURATION_INPUT:-24h}

# Convert to seconds
if [[ "$DURATION_INPUT" =~ ^([0-9]+)([dhm])$ ]]; then
    VALUE="${BASH_REMATCH[1]}"
    UNIT="${BASH_REMATCH[2]}"
    case "$UNIT" in
        d) DURATION=$((VALUE * 86400)) ;;
        h) DURATION=$((VALUE * 3600)) ;;
        m) DURATION=$((VALUE * 60)) ;;
        *) echo "[!] Invalid time unit. Use d (days), h (hours), or m (minutes)."; exit 1 ;;
    esac
else
    echo "[!] Invalid format. Use something like 3d, 12h, or 30m."
    exit 1
fi

# ----------------------
# Prompt for Test Frequency (default: 5m = 300s)
# ----------------------
read -rp "How often should a test run? (e.g. 60s, 5m, 10m) [default: 5m]: " INTERVAL_INPUT
INTERVAL_INPUT=${INTERVAL_INPUT:-5m}

if [[ "$INTERVAL_INPUT" =~ ^([0-9]+)([smh])$ ]]; then
    VALUE="${BASH_REMATCH[1]}"
    UNIT="${BASH_REMATCH[2]}"
    case "$UNIT" in
        s) INTERVAL=$VALUE ;;
        m) INTERVAL=$((VALUE * 60)) ;;
        h) INTERVAL=$((VALUE * 3600)) ;;
        *) echo "[!] Invalid unit in test interval."; exit 1 ;;
    esac
else
    echo "[!] Invalid format for test interval. Use 60s, 5m, 1h, etc."
    exit 1
fi

# ----------------------
# Prompt for Sample Duration (MTR report cycles)
# ----------------------
read -rp "How long should each MTR sample last? (in cycles, 1 cycle ≈ 1s) [default: 100]: " CYCLES
CYCLES=${CYCLES:-100}

if ! [[ "$CYCLES" =~ ^[0-9]+$ ]]; then
    echo "[!] Invalid cycle count. Must be a number."
    exit 1
fi

# ----------------------
# CONFIGURATION
# ----------------------
LOG_DIR="$HOME/mtr_logs"
MASTER_LOG="$LOG_DIR/master_log.txt"
ANOMALY_LOG="$LOG_DIR/anomalies.txt"
STOP_FILE="$LOG_DIR/STOP_MONITOR"
SCREEN_NAME="mtr_monitor_$(echo "$TARGET" | tr '.:' '_')"
DEPENDENCIES=(mtr screen awk grep)

# ----------------------
# Install missing dependencies
# ----------------------
install_deps() {
    echo "[*] Checking dependencies..."
    MISSING=()

    for cmd in "${DEPENDENCIES[@]}"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            echo "[-] Missing: $cmd"
            MISSING+=("$cmd")
        fi
    done

    if [[ ${#MISSING[@]} -gt 0 ]]; then
        echo "[*] Attempting to install: ${MISSING[*]}"
        if [ -f /etc/debian_version ]; then
            sudo apt update && sudo apt install -y "${MISSING[@]}"
        elif [ -f /etc/redhat-release ]; then
            sudo yum install -y "${MISSING[@]}"
        elif [ -f /etc/alpine-release ]; then
            sudo apk add "${MISSING[@]}"
        else
            echo "[!] Unsupported OS. Please install manually: ${MISSING[*]}"
            exit 1
        fi
    else
        echo "[+] All dependencies are installed."
    fi
}

# ----------------------
# Create the monitor script
# ----------------------
create_monitor_script() {
cat <<EOF > monitor_worker.sh
#!/bin/bash
mkdir -p "$LOG_DIR"
echo "Monitoring $TARGET for $DURATION_INPUT (sample every $INTERVAL_INPUT, $CYCLES cycles each)" > "$MASTER_LOG"
echo "Timestamped anomaly list for $TARGET" > "$ANOMALY_LOG"

echo "Initializing first MTR run... this may take around $CYCLES seconds."
sleep 1
clear

END=\$((SECONDS + $DURATION))

while [ \$SECONDS -lt \$END ]; do
    if [ -f "$STOP_FILE" ]; then
        echo "🛑 STOP file detected. Ending monitor early."
        break
    fi

    TIMESTAMP=\$(date +"%Y-%m-%d_%H-%M-%S")
    FILE="$LOG_DIR/mtr_\$TIMESTAMP.txt"

    mtr --report --report-cycles=$CYCLES "$TARGET" > "\$FILE"

    echo "==== \$TIMESTAMP ====" >> "$MASTER_LOG"
    cat "\$FILE" >> "$MASTER_LOG"
    echo -e "\\n" >> "$MASTER_LOG"

    # Anomaly detection
    if grep -E '([1-9][0-9]?|100)\\.%' "\$FILE" | grep -qv '0.0%'; then
        echo "[!] High packet loss at \$TIMESTAMP" >> "$ANOMALY_LOG"
    fi

    awk '/[0-9]+\.[0-9]+/ { if (\$5+0 > 150) print "[!] High latency (" \$5 "ms) at '"\$TIMESTAMP"'" }' "\$FILE" >> "$ANOMALY_LOG"

    # Live status dashboard
    clear
    echo "📡 Monitoring target: $TARGET"
    echo "⏱️  Last checked: \$TIMESTAMP"
    echo "📁 Logged: \$FILE"
    echo "----------------------------"

    hop_count=\$(grep -cE '^[0-9]+\\.' "\$FILE")
    avg_latency=\$(awk 'NR>1 {sum+=\$5} END {if (NR>1) print sum/(NR-1)}' "\$FILE")
    worst_latency=\$(awk 'NR>1 {if (\$5+0 > max) max=\$5+0} END {print max}' "\$FILE")
    total_loss=\$(awk 'NR>1 && \$7 ~ /^[0-9.]+%$/ {
        gsub("%","",\$7); sum+=\$7; count++
    } END {
        if (count > 0) print sum
        else print 0
    }' "\$FILE")

    printf "🌐 Hop Count: %s\\n" "\$hop_count"
    printf "📊 Avg Latency: %.2f ms\\n" "\$avg_latency"
    printf "🔥 Worst Hop: %.2f ms\\n" "\$worst_latency"
    printf "❌ Total Packet Loss: %.1f%%\\n" "\$total_loss"

    echo "----------------------------"
    echo "(Press Ctrl+A then D to detach screen)"
    echo "🛑 To stop early, run: touch $STOP_FILE"

    sleep $INTERVAL
done

[ -f "$STOP_FILE" ] && rm -f "$STOP_FILE"

echo "✅ Monitoring complete. See:"
echo " - Full log: $MASTER_LOG"
echo " - Anomalies: $ANOMALY_LOG"
EOF

chmod +x monitor_worker.sh
}

# ----------------------
# Launch the monitor in a screen session
# ----------------------
launch_screen() {
    if screen -list | grep -q "$SCREEN_NAME"; then
        echo "[!] Screen session '$SCREEN_NAME' is already running."
    else
        echo "[*] Starting monitor in screen: $SCREEN_NAME"
        screen -dmS "$SCREEN_NAME" ./monitor_worker.sh
        echo "[+] Use 'screen -r $SCREEN_NAME' to view the dashboard."
    fi
}

# ----------------------
# Main flow
# ----------------------
install_deps
create_monitor_script
launch_screen

# ----------------------
# Ask to attach to screen dashboard
# ----------------------
read -rp "Do you want to attach to the live dashboard now? [Y/n]: " ATTACH_NOW
ATTACH_NOW=${ATTACH_NOW,,}  # lowercase

if [[ "$ATTACH_NOW" == "y" || "$ATTACH_NOW" == "" ]]; then
    echo "[*] Attaching to screen session..."
    screen -r "$SCREEN_NAME"
else
    echo "[*] You can reattach anytime with: screen -r $SCREEN_NAME"
    echo "[*] To stop monitoring early, run: touch $STOP_FILE"
    exit 0
fi
