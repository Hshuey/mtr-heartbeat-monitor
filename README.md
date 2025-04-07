# MTR Heartbeat Monitor

A real-time, scriptable network heartbeat monitor using `mtr` with live dashboards, anomaly detection, full logging, and clean detachment via `screen`. Built for long-term connectivity analysis and pinpointing intermittent issues with ease.

## 🚀 Features

- ✅ Target selection — test any IP or hostname (default: `8.8.8.8`)
- ✅ Configurable run time — minutes, hours, or days (default: 24h)
- ✅ Test frequency — how often samples are taken (e.g. every 1m, 5m)
- ✅ Sample duration — how long each test runs (via MTR cycles)
- ✅ Anomaly detection — flags high latency and packet loss
- ✅ Live dashboard — terminal display via `screen`
- ✅ Auto logging — detailed logs stored in `~/mtr_logs/`
- ✅ Graceful exit — stop monitoring early with a `STOP` file

## 📦 Requirements

- Bash (Linux/macOS)
- `mtr`, `screen`, `awk`, `grep`

> 🔧 Don't worry — the script will automatically install missing dependencies using `sudo`.

## 🛠️ Usage

```bash
chmod +x run_mtr_monitor.sh
./run_mtr_monitor.sh
```

You’ll be prompted for:

- Target IP/hostname (default: `8.8.8.8`)
- How long to run (`3d`, `12h`, `30m`, etc.)
- How often to run tests (`60s`, `5m`, `1h`, etc.)
- Sample duration (in MTR cycles, default: 100)

At the end, you’ll be asked if you want to attach to the live dashboard.

## 🧠 Example

```
Target:        1.1.1.1
Run Time:      12h
Interval:      Every 5 minutes
Sample:        100 cycles (~100s per test)
```

Logs will be saved in:

```
~/mtr_logs/
├── master_log.txt            # Combined output of all runs
├── anomalies.txt             # Timestamped high-latency / packet-loss flags
├── mtr_YYYY-MM-DD_HH-MM.txt  # One file per run
```

## 🧑‍💻 Dashboard Preview
Be aware for the frist 100 seconds it will be blank! Dont panic please! 
Inside the live dashboard (via `screen`):

```
📡 Monitoring target: 8.8.8.8
⏱️  Last checked: 2025-04-07_23-15-00
📁 Logged: ~/mtr_logs/mtr_2025-04-07_23-15-00.txt
----------------------------
🌐 Hop Count: 12
📊 Avg Latency: 34.21 ms
🔥 Worst Hop: 68.57 ms
❌ Total Packet Loss: 1.2%
----------------------------
🛑 To stop early, run: touch ~/mtr_logs/STOP_MONITOR
```

## 🛑 Stopping Early

To stop monitoring gracefully:

```bash
touch ~/mtr_logs/STOP_MONITOR
```

The monitor will stop after the current sample finishes.

## 🔍 Screen Session Tips

- List all sessions: `screen -ls`
- Reattach to monitor: `screen -r mtr_monitor_8_8_8_8`
- Force reattach: `screen -D -r`
- Detach from dashboard: Press `Ctrl + A`, then `D`

## 📈 Roadmap Ideas

- [ ] Generate graphs from logs
- [ ] Email/Slack alerts on anomalies
- [ ] Multi-target monitoring support
- [ ] Optional systemd service or cron mode
- [ ] Web dashboard output (via static HTML)

## 🧾 License

This project is released under the MIT License.

## 👨‍💻 Credits

Created by Hunter Shuey  
Inspired by real-world debugging of flaky network links and stubborn packet loss issues.
