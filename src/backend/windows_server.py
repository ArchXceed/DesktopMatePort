import cv2
import numpy as np
import socket
import struct
import threading
import time
import win32gui
import win32ui
import win32con
import win32api
import tkinter as tk
import json
import ctypes
from pynput.mouse import Controller, Button
import pygetwindow as gw
import mss
import os
from queue import Queue

STREAM_PORT = 4089
FRAME_RATE = 60
QUALITY = 90
MAX_UDP_PACKET = 1400
fake_windows = {}  
hwnd = None

mouse = Controller()

update_queue = Queue()

last_pos_x = 0
last_pos_y = 0

server_started_nbr = 0

clicking = False

def move_loop():
    while True:
        if not clicking:
            mouse.position = (last_pos_x, last_pos_y)

            time.sleep(.01)

def send_mouse_event(x_rel, y_rel, event_type, button=1):
    global last_pos_x, last_pos_y
    
    x_rel = int(x_rel * 0.96) + 1
    y_rel = int(y_rel * 0.96) + 1
    if event_type == "move":
        last_pos_x = x_rel
        last_pos_y = y_rel
        mouse.position = (x_rel, y_rel)
    elif event_type == "click_down":
        if button == 1:
            print("click", mouse.position)
            clicking = True
            mouse.press(Button.left)
        elif button == 3:
            mouse.press(Button.right)
    elif event_type == "click_up":
        if button == 1:
            clicking = False
            mouse.release(Button.left)
        elif button == 3:
            mouse.release(Button.right)
    elif event_type == "wheel":
        mouse.scroll(0, button * 1)  


def handle_event_data(data):
    event_type = data[0]
    if event_type == 0 and len(data) >= 6:
        x, y = struct.unpack('!hh', data[1:5])
        send_mouse_event(x, y, "move")
    elif event_type == 1 and len(data) >= 7:
        x, y = struct.unpack('!hh', data[1:5])
        button = data[5]
        send_mouse_event(x, y, "click_down", button)
    elif event_type == 2 and len(data) >= 7:
        x, y = struct.unpack('!hh', data[1:5])
        button = data[5]
        send_mouse_event(x, y, "click_up", button)
    elif event_type == 3 and len(data) >= 7:
        x, y = struct.unpack('!hh', data[1:5])
        delta = data[5]
        send_mouse_event(x, y, "wheel", delta)


def event_receiver():
    global server_started_nbr
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind(('0.0.0.0', STREAM_PORT + 1))  

    print("Event receiver started")

    server_started_nbr += 1
    if server_started_nbr == 3:
        with open("server_started.txt", "w") as f:
            f.write("1")

    while True:
        data, addr = sock.recvfrom(1024)
        handle_event_data(data)



DESKTOPMATE_TITLE = "DesktopMate"
def get_desktopmate_bounds():
    hwnd = ctypes.windll.user32.FindWindowW(None, DESKTOPMATE_TITLE)
    print(f"hwnd: {hwnd}")
    if hwnd:
        rect = win32gui.GetWindowRect(hwnd)
        x, y, x2, y2 = rect
        return x, y, x2 - x, y2 - y
    return None

y_offset = -30
if os.path.exists("cfg_y_offset.txt"):
    with open("cfg_y_offset.txt", "r") as f:
        try:
            y_offset = int(f.read().strip())
        except Exception:
            pass
else:
    with open("cfg_y_offset.txt", "w") as f:
        f.write(str(y_offset))

def create_or_update_window_mainthread(win_id, x, y, w, h, title="FakeWin"):
    h = 10
    y = y + y_offset
    if win_id in fake_windows:
        win = fake_windows[win_id]
        win.geometry(f"{w}x{h}+{x}+{y}")
        win.title(title)

    else:
        win = tk.Toplevel()
        win.geometry(f"{w}x{h}+{x}+{y}")
        win.title(title)
        win.attributes('-topmost', False)
        win.protocol("WM_DELETE_WINDOW", lambda: None)
        win.update_idletasks()
        fake_windows[win_id] = win

def remove_missing_windows_mainthread(current_ids):
    for win_id in list(fake_windows.keys()):
        if win_id not in current_ids:
            win = fake_windows[win_id]
            win.destroy()
            del fake_windows[win_id]

def process_ui_updates(root):
    while not update_queue.empty():
        func = update_queue.get()
        func()
    root.after(50, lambda: process_ui_updates(root))



from PIL import ImageGrab
import os

last_was_ok = (False, False)  

window_magic_nbr_y = 0
window_magic_nbr_x = 0

MAGIC_FILE = "window_magic.json"

def load_window_magics():
    global window_magic_nbr_x, window_magic_nbr_y
    if os.path.exists(MAGIC_FILE):
        try:
            with open(MAGIC_FILE, "r") as f:
                data = json.load(f)
                window_magic_nbr_x = data.get("magic_x", 0)
                window_magic_nbr_y = data.get("magic_y", 0)
        except Exception as e:
            print(f"Failed to load window magics: {e}")

load_window_magics()

def capture_window(hwnd):
    global last_was_ok, window_magic_nbr_x, window_magic_nbr_y
    left, top, right, bot = win32gui.GetClientRect(hwnd)

    x, y = win32gui.ClientToScreen(hwnd, (left, top))
    if x > (win32api.GetSystemMetrics(0) + 200):
        if last_was_ok[0]:
            last_was_ok = (False, last_was_ok[1])
            window_magic_nbr_x = x
            with open(MAGIC_FILE, "w") as f:
                json.dump({"magic_x": window_magic_nbr_x, "magic_y": window_magic_nbr_y}, f)
        x = x - window_magic_nbr_x
    else:
        last_was_ok = (True, last_was_ok[1])
    if y > (win32api.GetSystemMetrics(1) + 200):
        if last_was_ok[1]:
            last_was_ok = (last_was_ok[0], False)
            window_magic_nbr_y = y
            with open(MAGIC_FILE, "w") as f:
                json.dump({"magic_x": window_magic_nbr_x, "magic_y": window_magic_nbr_y}, f)
        y = y - window_magic_nbr_y
    else:
        last_was_ok = (last_was_ok[0], True)
    if x < 0:
        x = 0
    if y < 0:
        y = 0
    x2, y2 = win32gui.GetWindowRect(hwnd)[2:4]
    w, h = x2 - x, y2 - y

    x = int(x / 0.96)+1
    y = int(y / 0.96)+1
    

    img = ImageGrab.grab(bbox=(x, y, x + w, y + h))
    img = np.array(img)
    return cv2.cvtColor(img, cv2.COLOR_RGB2BGRA), (x, y, w, h)

def stream_window():
    global hwnd
    last_frame_time = time.time()
    frame_interval = 1.0 / FRAME_RATE
    hwnd = win32gui.FindWindow(None, "DesktopMate")

    while True:
        current_time = time.time()
        if current_time - last_frame_time < frame_interval:
            continue

        try:
            if not hwnd:
                continue
            img = ImageGrab.grab()
            

            frame, (pos_x, pos_y, width, height) = capture_window(hwnd)

            frame = cv2.cvtColor(frame, cv2.COLOR_BGRA2BGR)
            mask = cv2.inRange(frame, np.array([0, 0, 0]), np.array([5, 5, 5]))
            frame = cv2.bitwise_and(frame, frame, mask=cv2.bitwise_not(mask))

            encode_param = [cv2.IMWRITE_JPEG_QUALITY, QUALITY]
            _, encoded = cv2.imencode('.jpg', frame, encode_param)
            

            header = struct.pack('!iiii', pos_x, pos_y, width, height)
            encoded_with_pos_and_size = header + encoded.tobytes()

            yield encoded_with_pos_and_size
            last_frame_time = current_time

        except Exception as e:
            print(f"Capture error: {e}")
            time.sleep(0.1)

def stream_server():
    global server_started_nbr
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.setsockopt(socket.SOL_SOCKET, socket.SO_SNDBUF, 65536)
    server_addr = ('0.0.0.0', STREAM_PORT)
    sock.bind(server_addr)
    
    clients = set()
    print(f"Starting stream server on port {STREAM_PORT}")
    server_started_nbr += 1
    if server_started_nbr == 3:
        with open("server_started.txt", "w") as f:
            f.write("1")
    def handle_clients():
        while True:
            try:
                data, addr = sock.recvfrom(1024)
                if data == b'connect':
                    clients.add(addr)
                    print(f"Client connected: {addr}")
            except:
                pass
    
    
    threading.Thread(target=handle_clients, daemon=True).start()
    
    try:
        for frame in stream_window():
            if not clients:
                time.sleep(0.1)
                continue
                
            
            chunks = [frame[i:i+MAX_UDP_PACKET] for i in range(0, len(frame), MAX_UDP_PACKET)]
            
            
            for client in list(clients):
                try:
                    for i, chunk in enumerate(chunks):
                        header = struct.pack('!HH', i, len(chunks))
                        sock.sendto(header + chunk, client)
                except Exception as e:
                    print(f"Error sending to {client}: {e}")
                    clients.remove(client)
                    print(f"Client disconnected: {client}")

    finally:
        sock.close()

def start_server(root):
    global server_started_nbr
    host = '0.0.0.0'
    port = 5555

    def handle_client(conn):
        with conn:
            while True:
                raw_len = conn.recv(4)
                if not raw_len:
                    break
                msg_len = struct.unpack('>I', raw_len)[0]
                data = conn.recv(msg_len)
                windows = json.loads(data.decode())

                current_ids = []

                for win in windows:
                    win_id = win["id"]
                    x = win["x"]
                    y = win["y"]
                    w = win["width"]
                    h = win["height"]
                    title = win["title"]
                    if title != "":

                        current_ids.append(win_id)
    
                        update_queue.put(lambda win_id=win_id, x=x, y=y, w=w, h=h, title=title:
                            create_or_update_window_mainthread(win_id, x, y, w, h, title))
    
                    update_queue.put(lambda ids=current_ids:
                        remove_missing_windows_mainthread(ids))

    def server_thread():
        global server_started_nbr
        with socket.socket(socket.AF_INET, socket.SOCK_STREAM) as s:
            s.bind((host, port))
            s.listen(1)
            print("Waiting for connection...")
            server_started_nbr += 1
            if server_started_nbr == 3:
                with open("server_started.txt", "w") as f:
                    f.write("1")
            conn, addr = s.accept()
            print(f"Connected by {addr}")
            handle_client(conn)

    threading.Thread(target=stream_server, daemon=True).start()
    threading.Thread(target=server_thread, daemon=True).start()
    threading.Thread(target=event_receiver, daemon=True).start()
    threading.Thread(target=move_loop, daemon=True).start()    

    root.after(50, lambda: process_ui_updates(root))


if __name__ == "__main__":
    root = tk.Tk()
    root.withdraw()  
    start_server(root)
    root.mainloop()
