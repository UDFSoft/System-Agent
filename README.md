# Command Executor Installation & Setup

Command Executor scripts connect your device to the **Smart Control** platform and allow it to receive and execute remote commands securely.

Supported platforms:

- **Linux** — `command-executor.sh`
- **Windows** — `command-executor.ps1`

The script:

1. Requests a command from the server  
2. Executes it locally  
3. Sends the result back  

Server endpoint:

```
https://smart.udfsoft.com
```

---

# 1. Where to Get `device_id`

## Linux

On Linux, `device_id` is automatically taken from:

```
/etc/machine-id
```

The script already contains:

```bash
DEVICE_ID=$(cat /etc/machine-id)
```

You can verify manually:

```bash
cat /etc/machine-id
```

No manual configuration is required.

---

## Windows

On Windows, the PowerShell version generates the device ID automatically.

If needed, you can hardcode it:

```powershell
$DEVICE_ID = "your-device-id"
```

---

# 2. Where to Get API Key

The API key is issued by the Smart Control platform.

Inside the script you will find:

```bash
API_KEY="xxxxxx"
```

Replace `xxxxxx` with your actual API key:

```bash
API_KEY="your_real_key"
```

To obtain an API key:

- Log in at: https://smart.udfsoft.com  
- Create a new device using your `device_id`
- Generate and copy the API key

⚠ The API key is required. Without it, the server will return an authorization error.

---

# 3. Linux Installation

## Step 1 — Install Dependencies

Required tools:

- curl  
- jq  
- lscpu  
- lsblk  
- free  
- sensors (optional)

Ubuntu / Debian:

```bash
sudo apt update
sudo apt install curl jq lm-sensors -y
```

---

## Step 2 — Copy Script

```bash
sudo mkdir -p /opt/smart-control
sudo cp command-executor.sh /opt/smart-control/
sudo chmod +x /opt/smart-control/command-executor.sh
```

---

## Step 3 — Set API Key

Edit the file:

```bash
nano /opt/smart-control/command-executor.sh
```

Replace:

```bash
API_KEY="xxxxxx"
```

With:

```bash
API_KEY="your_real_key"
```

---

# 4. Add to Cron (Linux)

To run the script automatically every minute:

```bash
crontab -e
```

Add:

```bash
* * * * * /opt/smart-control/command-executor.sh >> /var/log/smart-control.log 2>&1
```

This means:

- Run every minute  
- Log output to `/var/log/smart-control.log`

Check cron:

```bash
crontab -l
```

---

# 5. Windows Installation

## Step 1 — Allow Script Execution

Run PowerShell as Administrator:

```powershell
Set-ExecutionPolicy RemoteSigned
```

---

## Step 2 — Set API Key

Edit `command-executor.ps1`:

```powershell
$API_KEY = "your_real_key"
```

---

## Step 3 — Add to Task Scheduler

1. Open **Task Scheduler**
2. Create a new task
3. Trigger:
   - Every 1 minute
4. Action:
   - Program: `powershell.exe`
   - Arguments:

```powershell
-ExecutionPolicy Bypass -File "C:\path\command-executor.ps1"
```

---

# 6. How It Works

## Getting a Command

```
GET /api/v1/devices/commands?device_id=...
```

Headers:

```
X-DEVICE-ID
X-Api-Key
X-Platform
```

---

## Sending Result

```
POST /api/v1/devices/commands/{COMMAND}
```

---

# 7. Supported Commands

| Command | Description |
|----------|-------------|
| SEND_CPU_INFO | CPU information |
| SEND_SENSORS_INFO | Temperature sensors |
| SEND_RAM_INFO | Memory usage |
| SEND_DISK_INFO | Disk information |
| SEND_BATTERY_INFO | Battery status |
| SEND_ALL_INFO | Full system report |

---

# 8. Recommended Execution Frequency

| Device Type | Interval |
|-------------|----------|
| Server | 1–5 minutes |
| Workstation | 1–10 minutes |
| Laptop | 5–15 minutes |

---

# 9. Security Recommendations

- Keep your API key private
- Restrict file permissions

Linux:

```bash
chmod 600 command-executor.sh
```

Windows:
- Restrict NTFS file permissions

---

# 10. Testing

Run manually:

Linux:

```bash
/opt/smart-control/command-executor.sh
```

Windows:

```powershell
.\command-executor.ps1
```

If configured correctly, you should see:

```
[INFO] Command received
[INFO] Sending data...
[INFO] Done.
```

---

# Architecture Model

The script uses a **pull-based model**:

1. The device polls the server
2. The server returns a command
3. The device executes it
4. The device sends the result back

Advantages:

- No open ports required
- Works behind NAT
- Secure via API key
- Easy to scale
