#!/usr/bin/env python3

import subprocess
from datetime import datetime
import os
import time
import urllib.parse


def get_list_of_windows():
    try:
        datetime_now = datetime.now()
    
        script = os.path.join(os.path.dirname(__file__), "list_windows.js")
        reg_script_number = subprocess.run(
            "dbus-send --print-reply --dest=org.kde.KWin "
            "/Scripting org.kde.kwin.Scripting.loadScript "
            f"string:{script} | awk 'END {{print $2}}'",
            capture_output=True, shell=True
        ).stdout.decode().split("\n")[0].strip()


        if reg_script_number:
            script_path = f"/Scripting/Script{reg_script_number}"
            subprocess.run(
                f"dbus-send --print-reply --dest=org.kde.KWin {script_path} org.kde.kwin.Script.run",
                shell=True, stdout=subprocess.DEVNULL
            )
            subprocess.run(
                f"dbus-send --print-reply --dest=org.kde.KWin {script_path} org.kde.kwin.Script.stop",
                shell=True, stdout=subprocess.DEVNULL
            )
    
        since = str(datetime_now)
    
        msg = subprocess.run("journalctl _COMM=kwin_wayland -o cat --since \"" + since + "\"",
                             capture_output=True, shell=True).stdout.decode().rstrip().split("\n")
        msg = [el.lstrip("js: ") for el in msg]
        print(f"Debug: {msg}")  # Debugging line to see the raw output
        for i, el in enumerate(msg):
            result = el.split(" ")
            msg[i] = {
                "x": int(result[0]),
                "y": int(result[1]) + 30,
                "width": int(result[2]),
                "height": int(result[3]),
                "title": urllib.parse.unquote(result[5]),
                "id": result[5] if len(result) > 5 else "",
                "active": result[4] == "1"
            }
        return msg
    except Exception as e:
        print(f"Error getting list of windows: {e}")
        return []
 

if __name__ == "__main__":
    print(get_list_of_windows())
