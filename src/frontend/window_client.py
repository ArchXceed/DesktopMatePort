import socket
import json
import time
import subprocess
import sys
import os
from lib_kde.get_all_windows import get_list_of_windows

SERVER_IP = '127.0.0.1'
SERVER_PORT = 5555
MONITOR_NAME = "HDMI-1-A"
monitor_geometry = None

def get_monitor_geometry(name):
    monitors = json.loads(subprocess.check_output(["hyprctl", "monitors", "-j"]).decode())
    for mon in monitors:
        if mon["name"] == name:
            return {
                "x": mon["x"],
                "y": mon["y"],
                "width": mon["width"],
                "height": mon["height"]
            }
    return None

if len(sys.argv) > 1:
    DESKTOP_ENV = sys.argv[1]
else:
    DESKTOP_ENV = "kde"

if len(sys.argv) < 4:
        print("Usage: python window_client.py <desktop_env> <monitor_size> <monitor_position>")
        print("Example: python window_client.py kde 1920x1080 0x0")
        sys.exit(1)
monitor_geometry = {
                "x": int(sys.argv[3].split("x")[0]),
                "y": int(sys.argv[3].split("x")[1]),
                "width": int(sys.argv[2].split("x")[0]),
                "height": int(sys.argv[2].split("x")[1])
            }

def get_hyprland_windows(monitor_geometry):
    output = subprocess.check_output(["hyprctl", "clients", "-j"]).decode()
    clients = json.loads(output)
    window_data = []
    for client in clients:
        x, y = client["at"]
        if client["initialTitle"] == "Overlay":
            continue
        if monitor_geometry and not (monitor_geometry["x"] <= x < monitor_geometry["x"] + monitor_geometry["width"]):
            continue
        if monitor_geometry and not (monitor_geometry["y"] <= y < monitor_geometry["y"] + monitor_geometry["height"]):
            continue
        w, h = client["size"]
        window_data.append({
    "id": client["address"],
    "class": client.get("class", "Unknown"),
    "title": client.get("title", "Unnamed"),
    "x": x - monitor_geometry["x"],
    "y": y - monitor_geometry["y"],
    "width": w,
    "height": h-30,
    "active": False
})
        print(f"Window ID: {client['address']}, Title: {client.get('title', 'Unnamed')}, Position: ({x}, {y}), Size: ({w}, {h})")
    return window_data



def send_data():
    with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
        s.connect((SERVER_IP, SERVER_PORT))
        while True:
            if DESKTOP_ENV != "kde":
                data = get_hyprland_windows(monitor_geometry)
            else:
                data = get_list_of_windows()
                print(data)

            msg = json.dumps(data).encode()
            msg_len = len(msg).to_bytes(4, 'big')
            s.sendall(msg_len + msg)
            time.sleep(0.1)

if __name__ == "__main__":
    send_data()
