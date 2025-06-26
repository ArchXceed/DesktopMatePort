try:
    import tkinter as tk
except ImportError:
    print("Error: tkinter is not installed.")
    print("Please install it using your package manager:")
    print("- On Debian/Ubuntu: sudo apt install python3-tk")
    print("- On Arch/Manjaro: sudo pacman -S tk")
    print("- On Fedora: sudo dnf install python3-tkinter")
    print("- On Windows: Reinstall Python and make sure to include tkinter support.")
    exit(1)

import subprocess
import os
import threading
from tkinter import simpledialog, messagebox

def is_hyprland():
    return os.environ.get("XDG_SESSION_DESKTOP", "").lower() == "hyprland"

def is_kde():
    return os.environ.get("XDG_SESSION_DESKTOP", "").lower() == "kde"

def run_script(script_path):
    subprocess.Popen(["bash", script_path])

root = tk.Tk()
root.title("DesktopMatePort TRICKS")
root.geometry("500x400")

title = tk.Label(root, text="DesktopMatePort Control", font=("Arial", 16))
title.pack(pady=10)

if is_hyprland():
    btn_liberate_hypr = tk.Button(
        root, text="Liberate DesktopMate (Hyprland)",
        command=lambda: [run_script("scripts/show.sh"), run_script("scripts/kill_block.sh")],
        width=50
    )
    btn_liberate_hypr.pack(pady=5)

    label1 = tk.Label(root, text="If you want to access to the WINE desktop, without mouse capture,\njust click this button! Only available in Hyprland!")
    label1.pack()

    btn_hide_wine_hypr = tk.Button(
        root, text="Hide Wine (Hyprland)",
        command=lambda: run_script("scripts/hide.sh"),
        width=50
    )
    btn_hide_wine_hypr.pack(pady=10)

if is_kde():
    btn_liberate_kde = tk.Button(
        root, text="Liberate DesktopMate (KDE)",
        command=lambda: [run_script("scripts/disable_hide_kde.sh"), run_script("scripts/kill_block.sh")],
        width=50
    )
    btn_liberate_kde.pack(pady=5)

    label2 = tk.Label(root, text="If you want to access to the WINE desktop, without mouse capture,\njust click this button! Only available in KDE!")
    label2.pack()

    btn_hide_wine_kde = tk.Button(
        root, text="Hide Wine (KDE)",
        command=lambda: run_script("scripts/enable_hide_kde.sh"),
        width=50
    )
    btn_hide_wine_kde.pack(pady=10)

btn_kill_all = tk.Button(
    root,
    text="Kill everything except DesktopMate",
    command=lambda: run_script("scripts/kill_all.sh"),
    width=50
)
btn_kill_all.pack(pady=20)


lbl_run = tk.Label(
    root,
    text="To run, just type DesktopMate in your Search Bar"
)
lbl_run.pack()

def stop_desktopmate():
    try:
        subprocess.run([
            "bash", "-c",
            'wmctrl -r "shell - Wine Desktop" -b remove,below; '
            'kill $(pgrep -f "DesktopMate.exe"); '
            'kill $(pgrep -f "run.bat"); '
            'kill $(pgrep -f "mouse_block.exe"); '
            'kill $(pgrep -n wineserver); '
            'kill $(pgrep -f overlay_wayland); exit'
        ])
    except Exception as e:
        print(f"Error stopping DesktopMate: {e}")
    root.destroy()

btn_stop = tk.Button(
    root,
    text="Stop DesktopMatePort",
    command=stop_desktopmate,
    width=50,
    fg="red"
)
btn_stop.pack(pady=20)

root.protocol("WM_DELETE_WINDOW", stop_desktopmate)

root.mainloop()

