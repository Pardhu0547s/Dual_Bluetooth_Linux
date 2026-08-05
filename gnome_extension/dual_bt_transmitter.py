#!/usr/bin/env python3
"""
Dual Bluetooth Audio Transmitter & Stream Combiner for Linux (PipeWire / BlueZ)
-------------------------------------------------------------------------------
This application allows connecting two Bluetooth audio devices (headphones/speakers)
simultaneously and streaming the exact same audio signal to both devices in sync.
"""

import json
import os
import re
import sys
import subprocess
import threading
import time
from http.server import HTTPServer, BaseHTTPRequestHandler
from urllib.parse import parse_qs, urlparse

PORT = 5050

class DualAudioEngine:
    def __init__(self):
        self.active_loopbacks = []
        self.dual_sink_node_id = None
        self.is_active = False
        self.device1_id = None
        self.device2_id = None
        self.delay1_ms = 0
        self.delay2_ms = 0

    def get_pipewire_nodes(self):
        """Fetches all Audio Sinks from PipeWire using pw-dump."""
        try:
            output = subprocess.check_output(['pw-dump'], stderr=subprocess.DEVNULL)
            data = json.loads(output)
            sinks = []
            for item in data:
                if item.get('type') == 'PipeWire:Interface:Node':
                    props = item.get('info', {}).get('props', {})
                    media_class = props.get('media.class', '')
                    if media_class == 'Audio/Sink':
                        sinks.append({
                            'id': item['id'],
                            'name': props.get('node.name', f"node_{item['id']}"),
                            'description': props.get('node.description') or props.get('node.name', 'Audio Output'),
                            'is_bluetooth': 'bluez' in props.get('node.name', '') or props.get('device.api') == 'bluez5'
                        })
            return sinks
        except Exception as e:
            print(f"Error reading PipeWire nodes: {e}")
            return []

    def get_bluetooth_devices(self):
        """Lists Bluetooth devices using bluetoothctl."""
        try:
            output = subprocess.check_output(['bluetoothctl', 'devices'], text=True)
            devices = []
            for line in output.strip().split('\n'):
                if not line:
                    continue
                parts = line.split(' ', 2)
                if len(parts) >= 3:
                    devices.append({
                        'mac': parts[1],
                        'name': parts[2]
                    })
            return devices
        except Exception as e:
            print(f"Error fetching BT devices: {e}")
            return []

    def connect_bt_device(self, mac):
        """Connects to a bluetooth device by MAC address."""
        try:
            res = subprocess.run(['bluetoothctl', 'connect', mac], capture_output=True, text=True, timeout=10)
            return "Successful" in res.stdout or "Connection successful" in res.stdout
        except Exception as e:
            print(f"Error connecting to {mac}: {e}")
            return False

    def start_dual_stream(self, target_sink1, target_sink2, delay1=0, delay2=0):
        """Creates master virtual sink and streams to both targets simultaneously."""
        self.stop_dual_stream()
        
        self.device1_id = target_sink1
        self.device2_id = target_sink2
        self.delay1_ms = delay1
        self.delay2_ms = delay2
        
        print(f"Starting Dual Bluetooth Stream -> Target 1: {target_sink1} (+{delay1}ms), Target 2: {target_sink2} (+{delay2}ms)")
        
        try:
            # 1. Master loopback outputs to Target 1
            cmd1 = [
                'pw-loopback',
                '--name', 'Dual_Master_Sink',
                '-i', 'node.name=Dual_Master_Sink media.class=Audio/Sink node.description="Dual Bluetooth Audio Master"',
                '--playback', str(target_sink1)
            ]
            if delay1 > 0:
                cmd1.extend(['--delay', f"{delay1 / 1000.0:.3f}"])
                
            proc1 = subprocess.Popen(cmd1, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.active_loopbacks.append(proc1)
            time.sleep(0.6)

            # 2. Slave loopback captures from Master and outputs to Target 2
            cmd2 = [
                'pw-loopback',
                '--name', 'Dual_Slave_Stream',
                '--capture', 'Dual_Master_Sink',
                '--playback', str(target_sink2)
            ]
            if delay2 > 0:
                cmd2.extend(['--delay', f"{delay2 / 1000.0:.3f}"])
                
            proc2 = subprocess.Popen(cmd2, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            self.active_loopbacks.append(proc2)
            time.sleep(0.6)

            # 3. Set Dual_Master_Sink as default audio sink in PipeWire
            dump = json.loads(subprocess.check_output(['pw-dump']))
            master_node = next((item for item in dump if item.get('type') == 'PipeWire:Interface:Node' and item.get('info',{}).get('props',{}).get('node.name') == 'Dual_Master_Sink'), None)
            if master_node:
                subprocess.run(['wpctl', 'set-default', str(master_node['id'])])
            
            self.is_active = True
            return True
        except Exception as e:
            print(f"Failed to start dual stream: {e}")
            self.stop_dual_stream()
            return False

    def stop_dual_stream(self):
        """Stops active loopback streams."""
        for proc in self.active_loopbacks:
            try:
                proc.terminate()
                proc.wait(timeout=2)
            except Exception:
                try:
                    proc.kill()
                except Exception:
                    pass
        self.active_loopbacks = []
        self.is_active = False
        print("Dual Bluetooth Stream Stopped.")
        return True


engine = DualAudioEngine()

HTML_PAGE = """<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Dual Bluetooth Audio Sync | Linux</title>
    <link href="https://fonts.googleapis.com/css2?family=Inter:wght@300;400;500;600;700&display=swap" rel="stylesheet">
    <style>
        :root {
            --bg-primary: #0a0c10;
            --bg-card: rgba(22, 27, 34, 0.75);
            --border-color: rgba(255, 255, 255, 0.1);
            --accent-blue: #38bdf8;
            --accent-purple: #818cf8;
            --accent-gradient: linear-gradient(135deg, #38bdf8 0%, #818cf8 100%);
            --text-main: #f3f4f6;
            --text-muted: #9ca3af;
            --success: #34d399;
            --danger: #f87171;
        }

        * {
            box-sizing: border-box;
            margin: 0;
            padding: 0;
            font-family: 'Inter', sans-serif;
        }

        body {
            background: var(--bg-primary);
            background-image: 
                radial-gradient(at 10% 20%, rgba(56, 189, 248, 0.12) 0px, transparent 50%),
                radial-gradient(at 90% 80%, rgba(129, 140, 248, 0.12) 0px, transparent 50%);
            color: var(--text-main);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }

        .container {
            width: 100%;
            max-width: 840px;
            background: var(--bg-card);
            backdrop-filter: blur(16px);
            -webkit-backdrop-filter: blur(16px);
            border: 1px solid var(--border-color);
            border-radius: 24px;
            padding: 32px;
            box-shadow: 0 25px 50px -12px rgba(0, 0, 0, 0.5);
        }

        header {
            text-align: center;
            margin-bottom: 32px;
        }

        .badge {
            display: inline-flex;
            align-items: center;
            gap: 6px;
            background: rgba(56, 189, 248, 0.1);
            color: var(--accent-blue);
            border: 1px solid rgba(56, 189, 248, 0.2);
            padding: 6px 14px;
            border-radius: 20px;
            font-size: 13px;
            font-weight: 500;
            margin-bottom: 12px;
        }

        .status-dot {
            width: 8px;
            height: 8px;
            border-radius: 50%;
            background: var(--text-muted);
        }

        .status-dot.active {
            background: var(--success);
            box-shadow: 0 0 10px var(--success);
        }

        h1 {
            font-size: 28px;
            font-weight: 700;
            letter-spacing: -0.5px;
            background: var(--accent-gradient);
            -webkit-background-clip: text;
            -webkit-text-fill-color: transparent;
            margin-bottom: 8px;
        }

        p.subtitle {
            color: var(--text-muted);
            font-size: 14px;
        }

        .grid {
            display: grid;
            grid-template-columns: 1fr 1fr;
            gap: 20px;
            margin-bottom: 28px;
        }

        @media (max-width: 640px) {
            .grid { grid-template-columns: 1fr; }
        }

        .device-card {
            background: rgba(255, 255, 255, 0.03);
            border: 1px solid var(--border-color);
            border-radius: 16px;
            padding: 20px;
            transition: all 0.3s ease;
        }

        .device-card:hover {
            border-color: rgba(56, 189, 248, 0.3);
            transform: translateY(-2px);
        }

        .card-header {
            display: flex;
            align-items: center;
            gap: 10px;
            font-size: 15px;
            font-weight: 600;
            margin-bottom: 16px;
            color: var(--accent-blue);
        }

        label {
            display: block;
            font-size: 12px;
            font-weight: 500;
            color: var(--text-muted);
            margin-bottom: 6px;
            text-transform: uppercase;
            letter-spacing: 0.5px;
        }

        select {
            width: 100%;
            background: rgba(10, 12, 16, 0.8);
            border: 1px solid var(--border-color);
            color: var(--text-main);
            padding: 12px;
            border-radius: 10px;
            font-size: 14px;
            outline: none;
            cursor: pointer;
            margin-bottom: 16px;
        }

        select:focus {
            border-color: var(--accent-blue);
        }

        .slider-group {
            margin-top: 12px;
        }

        .slider-label {
            display: flex;
            justify-content: space-between;
            align-items: center;
            font-size: 13px;
            color: var(--text-muted);
            margin-bottom: 8px;
        }

        .slider-val {
            color: var(--accent-purple);
            font-weight: 600;
        }

        input[type="range"] {
            width: 100%;
            accent-color: var(--accent-purple);
        }

        .actions {
            display: flex;
            flex-direction: column;
            gap: 12px;
        }

        .btn {
            width: 100%;
            padding: 16px;
            border-radius: 14px;
            border: none;
            font-size: 16px;
            font-weight: 600;
            cursor: pointer;
            display: flex;
            align-items: center;
            justify-content: center;
            gap: 10px;
            transition: all 0.2s ease;
        }

        .btn-primary {
            background: var(--accent-gradient);
            color: #000;
            box-shadow: 0 4px 20px rgba(56, 189, 248, 0.3);
        }

        .btn-primary:hover {
            opacity: 0.95;
            transform: scale(1.01);
        }

        .btn-danger {
            background: rgba(248, 113, 113, 0.15);
            border: 1px solid rgba(248, 113, 113, 0.3);
            color: var(--danger);
        }

        .btn-danger:hover {
            background: rgba(248, 113, 113, 0.25);
        }

        .info-box {
            background: rgba(255, 255, 255, 0.02);
            border-radius: 12px;
            padding: 16px;
            margin-top: 24px;
            font-size: 13px;
            color: var(--text-muted);
            line-height: 1.5;
        }

        .info-box ul {
            padding-left: 18px;
            margin-top: 8px;
        }
    </style>
</head>
<body>
    <div class="container">
        <header>
            <div class="badge">
                <span class="status-dot" id="statusDot"></span>
                <span id="statusText">Stream Idle</span>
            </div>
            <h1>Dual Bluetooth Audio Transmitter</h1>
            <p class="subtitle">Transmit synchronized audio to two Bluetooth devices on Linux via PipeWire</p>
        </header>

        <div class="grid">
            <!-- Device 1 -->
            <div class="device-card">
                <div class="card-header">
                    🎧 Bluetooth Device 1
                </div>
                <label for="sink1">Select Output Sink</label>
                <select id="sink1">
                    <option value="">Scanning Audio Sinks...</option>
                </select>

                <div class="slider-group">
                    <div class="slider-label">
                        <span>Latency Offset</span>
                        <span class="slider-val" id="delay1Val">0 ms</span>
                    </div>
                    <input type="range" id="delay1" min="0" max="500" value="0" step="5" oninput="updateVal('delay1Val', this.value)">
                </div>
            </div>

            <!-- Device 2 -->
            <div class="device-card">
                <div class="card-header">
                    🎧 Bluetooth Device 2
                </div>
                <label for="sink2">Select Output Sink</label>
                <select id="sink2">
                    <option value="">Scanning Audio Sinks...</option>
                </select>

                <div class="slider-group">
                    <div class="slider-label">
                        <span>Latency Offset</span>
                        <span class="slider-val" id="delay2Val">0 ms</span>
                    </div>
                    <input type="range" id="delay2" min="0" max="500" value="0" step="5" oninput="updateVal('delay2Val', this.value)">
                </div>
            </div>
        </div>

        <div class="actions">
            <button class="btn btn-primary" id="toggleBtn" onclick="toggleDualStream()">
                ▶ Start Dual Bluetooth Stream
            </button>
        </div>

        <div class="info-box">
            <strong>💡 How it works:</strong>
            <ul>
                <li>Connect both of your Bluetooth headphones/speakers in Linux Bluetooth Settings.</li>
                <li>Select Device 1 and Device 2 from the dropdown menus above.</li>
                <li>Click <strong>Start Dual Stream</strong> to clone audio output to both devices simultaneously.</li>
                <li>Adjust Latency Offset sliders if one headset experiences slight Bluetooth audio delay.</li>
            </ul>
        </div>
    </div>

    <script>
        let isRunning = false;

        function updateVal(id, val) {
            document.getElementById(id).innerText = val + ' ms';
        }

        async function fetchSinks() {
            try {
                const res = await fetch('/api/sinks');
                const sinks = await res.json();
                
                const s1 = document.getElementById('sink1');
                const s2 = document.getElementById('sink2');
                
                const prev1 = s1.value;
                const prev2 = s2.value;

                s1.innerHTML = '';
                s2.innerHTML = '';

                if (sinks.length === 0) {
                    s1.innerHTML = '<option value="">No audio sinks found</option>';
                    s2.innerHTML = '<option value="">No audio sinks found</option>';
                    return;
                }

                sinks.forEach((sink, idx) => {
                    const opt1 = document.createElement('option');
                    opt1.value = sink.id;
                    opt1.innerText = (sink.is_bluetooth ? '🔵 ' : '🔊 ') + sink.description;
                    s1.appendChild(opt1);

                    const opt2 = opt1.cloneNode(true);
                    s2.appendChild(opt2);
                });

                if (prev1) s1.value = prev1;
                if (prev2) s2.value = prev2;
                else if (sinks.length > 1) s2.selectedIndex = 1;

            } catch (err) {
                console.error("Failed to load sinks", err);
            }
        }

        async function toggleDualStream() {
            const btn = document.getElementById('toggleBtn');
            const statusDot = document.getElementById('statusDot');
            const statusText = document.getElementById('statusText');

            if (isRunning) {
                await fetch('/api/stop', { method: 'POST' });
                isRunning = false;
                btn.className = 'btn btn-primary';
                btn.innerText = '▶ Start Dual Bluetooth Stream';
                statusDot.className = 'status-dot';
                statusText.innerText = 'Stream Idle';
            } else {
                const sink1 = document.getElementById('sink1').value;
                const sink2 = document.getElementById('sink2').value;
                const delay1 = parseInt(document.getElementById('delay1').value);
                const delay2 = parseInt(document.getElementById('delay2').value);

                if (!sink1 || !sink2) {
                    alert("Please select two audio output sinks.");
                    return;
                }

                const res = await fetch('/api/start', {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ sink1, sink2, delay1, delay2 })
                });

                const data = await res.json();
                if (data.status === 'ok') {
                    isRunning = true;
                    btn.className = 'btn btn-danger';
                    btn.innerText = '⏹ Stop Dual Bluetooth Stream';
                    statusDot.className = 'status-dot active';
                    statusText.innerText = 'Transmitting to Dual Devices';
                } else {
                    alert("Failed to start dual streaming: " + (data.error || 'Unknown error'));
                }
            }
        }

        fetchSinks();
        setInterval(fetchSinks, 5000);
    </script>
</body>
</html>
"""

class RequestHandler(BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        return

    def do_GET(self):
        parsed = urlparse(self.path)
        if parsed.path == '/' or parsed.path == '/index.html':
            self.send_response(200)
            self.send_header('Content-Type', 'text/html')
            self.end_headers()
            self.wfile.write(HTML_PAGE.encode('utf-8'))
        elif parsed.path == '/api/sinks':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            sinks = engine.get_pipewire_nodes()
            self.wfile.write(json.dumps(sinks).encode('utf-8'))
        elif parsed.path == '/api/bt-devices':
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            devices = engine.get_bluetooth_devices()
            self.wfile.write(json.dumps(devices).encode('utf-8'))
        else:
            self.send_error(404)

    def do_POST(self):
        parsed = urlparse(self.path)
        content_length = int(self.headers.get('Content-Length', 0))
        body = self.rfile.read(content_length) if content_length > 0 else b'{}'
        data = json.loads(body.decode('utf-8')) if body else {}

        if parsed.path == '/api/start':
            sink1 = data.get('sink1')
            sink2 = data.get('sink2')
            delay1 = int(data.get('delay1', 0))
            delay2 = int(data.get('delay2', 0))
            
            success = engine.start_dual_stream(sink1, sink2, delay1, delay2)
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            if success:
                self.wfile.write(json.dumps({'status': 'ok'}).encode('utf-8'))
            else:
                self.wfile.write(json.dumps({'status': 'error', 'error': 'Could not start PipeWire stream'}).encode('utf-8'))

        elif parsed.path == '/api/stop':
            engine.stop_dual_stream()
            self.send_response(200)
            self.send_header('Content-Type', 'application/json')
            self.end_headers()
            self.wfile.write(json.dumps({'status': 'ok'}).encode('utf-8'))
        else:
            self.send_error(404)

class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True

def run_server():
    port = PORT
    server = None
    for try_port in range(port, port + 10):
        try:
            server = ReusableHTTPServer(('0.0.0.0', try_port), RequestHandler)
            port = try_port
            break
        except OSError:
            continue

    if not server:
        print(f"❌ Error: Could not bind to any port in range {PORT}-{PORT+10}. Try: fuser -k {PORT}/tcp")
        sys.exit(1)

    print(f"🚀 Dual Bluetooth Dashboard running at http://localhost:{port}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nStopping server...")
    finally:
        engine.stop_dual_stream()

if __name__ == '__main__':
    run_server()
