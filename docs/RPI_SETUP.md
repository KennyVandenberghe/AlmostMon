# Raspberry Pi Backend Node Setup Guide

This document describes how to set up a Raspberry Pi as a backend node
for the AlmostMon Dev project.

---

# Overview

The Pi runs a minimal HTTP service used for:

- Backend calculations
- Simulation logic
- Future world generation
- Health checks

The game connects via HTTP `/ping` on port `8787`.

---

# 1. Hardware

Recommended:

- Raspberry Pi (tested on 3b and 4b)
- Sufficient power supply

---

# 2. Flash Raspberry Pi OS

## Use Raspberry Pi Imager

Select:
- **Raspberry Pi OS Lite (64-bit)**

Lite = headless (no desktop, CLI only).

---

## Advanced Settings (⚙️)

Set:

Hostname:
```
rpi-node-01
```

Username:
```
nodeadmin
```

Password:
- 16+ characters
- Not reused
- Store in password manager

Enable:
- SSH ✔
- WiFi ✔ (if using wireless)
- Set country correctly

Disable:
- Raspberry Pi Connect

Write image to SD card.

---

# 3. First Boot

Insert SD card and power on.

Wait ~60–120 seconds.

From your development machine:

```bash
ping rpi-node-01.local
ssh nodeadmin@rpi-node-01.local
```

If `.local` does not resolve on Windows, use IP instead.

---

# 4. Update System

SSH into the Pi:

```bash
sudo apt update
sudo apt full-upgrade -y
```

---

# 5. Assign Stable IP (Router Method - Recommended)

Do NOT configure static IP on the Pi.

Instead:

1. Open router admin panel
2. Find DHCP reservation section
3. Assign fixed IP to Pi MAC address

Example:
```
192.168.0.241
```

Reboot Pi:

```bash
sudo reboot
```

Confirm:

```bash
hostname -I
```

---

# 6. Backend HTTP Service (Dual Stack IPv4 + IPv6)

The backend must listen on both IPv4 and IPv6.

This ensures:
- `.local` hostname works on Windows (IPv6 resolution)
- Direct IPv4 works as fallback
- No dependency on specific IP family

---

Create backend directory:

```bash
mkdir -p ~/backend
nano ~/backend/server.py
```

Paste:

```python
import json
import time
import socket
from http.server import BaseHTTPRequestHandler, HTTPServer

PORT = 8787
VERSION = "0.1"
NAME = socket.gethostname()

class Handler(BaseHTTPRequestHandler):
    def _send_json(self, data, code=200):
        raw = json.dumps(data).encode("utf-8")
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(raw)))
        self.end_headers()
        self.wfile.write(raw)

    def do_GET(self):
        if self.path == "/ping":
            self._send_json({
                "ok": True,
                "name": NAME,
                "version": VERSION,
                "unix": int(time.time())
            })
            return

        self._send_json({"ok": False, "error": "not_found"}, 404)

# Dual-stack server (IPv4 + IPv6)
class DualStackServer(HTTPServer):
    address_family = socket.AF_INET6

def main():
    server = DualStackServer(("::", PORT), Handler)
    server.serve_forever()

if __name__ == "__main__":
    main()
```

---

Restart service:

```bash
sudo systemctl restart rpi-backend
```

Verify listening ports:

```bash
sudo ss -ltnp | grep 8787
```

Expected:
- `[::]:8787` (IPv6)
- or `*:8787`

Test via hostname (IPv6):

```bash
curl.exe http://rpi-node-01.local:8787/ping
```

Test via IPv4:

```bash
curl.exe http://192.168.X.X:8787/ping
```

# 7. Create Systemd Service

This makes it autostart on RPI boot.

```bash
sudo nano /etc/systemd/system/rpi-backend.service
```

Paste:

```ini
[Unit]
Description=RPI Backend Service
After=network-online.target
Wants=network-online.target

[Service]
User=nodeadmin
WorkingDirectory=/home/nodeadmin/backend
ExecStart=/usr/bin/python3 /home/nodeadmin/backend/server.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl daemon-reload
sudo systemctl enable rpi-backend
sudo systemctl start rpi-backend
```

Check status:

```bash
sudo systemctl status rpi-backend
```

Test from PC:

```bash
curl.exe http://192.168.0.241:8787/ping
```

Expected response:

```json
{"ok": true, "name": "rpi-node-01", "version": "0.1", "unix": 123456789}
```

---

# 8. Godot Integration

File location:

```
res://core/backend/BackendConnector.gd
```

Autoload it in:

```
Project → Project Settings → Autoload
```

---

## BackendConnector.gd

```gdscript
extends Node

@export var enabled := true
@export var timeout_sec := 2.0

@export var candidates: PackedStringArray = [
	"http://rpi-node-01.local:8787",
	"http://192.168.0.241:8787"
]

var _http: HTTPRequest
var backend_base := ""
var connected := false

func _ready() -> void:
	if not enabled:
		return

	_http = HTTPRequest.new()
	add_child(_http)
	_http.request_completed.connect(_on_done)

	_try_index(0)

func _try_index(i: int) -> void:
	if i >= candidates.size():
		print("[RPI] no backend found (safe fallback).")
		return

	var base := candidates[i]
	_http.timeout = timeout_sec

	set_meta("try_i", i)
	set_meta("try_base", base)

	var err := _http.request(base + "/ping")
	if err != OK:
		_try_index(i + 1)

func _on_done(result: int, code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var i := int(get_meta("try_i", 0))
	var base := String(get_meta("try_base", ""))

	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_try_index(i + 1)
		return

	var json := JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		_try_index(i + 1)
		return

	var data := json.data as Dictionary

	if data.get("ok", false):
		backend_base = base
		connected = true
		print("[RPI] Connected:", data)
```

---

# 9. Changing IP or Hostname

If the Pi IP changes:

1. Update router DHCP reservation
2. Update `candidates` array in `BackendConnector.gd`
3. Restart Godot

Optional fallback setup:

```gdscript
@export var candidates: PackedStringArray = [
	"http://rpi-node-01.local:8787",
	"http://192.168.0.241:8787"
]
```

---

# 10. Service Management

Stop service:
```bash
sudo systemctl stop rpi-backend
```

Start:
```bash
sudo systemctl start rpi-backend
```

Restart:
```bash
sudo systemctl restart rpi-backend
```

Logs:
```bash
journalctl -u rpi-backend -f
```

---
