#!/bin/bash

export WINEPREFIX=~/.dskmatewine

if pgrep "wine" || pgrep "explorer"; then
    echo "Wine/Explorer is already running. If you ran DesktopMatePort earlier, it may cause problems. Do you want to kill it (input)? (y/n):"
    read choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        kill -9 $(pgrep wine)
        kill -9 $(pgrep explorer)
        echo "Wine/Explorer has been killed."
    else
        echo "Wine/Explorer is still running."
    fi
else
    echo "Wine/Explorer is not running."
fi

if pgrep -f "python ./windows_server.py"; then
    echo "The DesktopMatePort Wine-Side server is already running. If you ran DesktopMatePort earlier, it may cause problems. Do you want to kill it (input)? (y/n):"
    read choice
    if [[ "$choice" == "y" || "$choice" == "Y" ]]; then
        kill -9 $(pgrep -f "python ./windows_server.py")
        echo "DesktopMatePort Wine-Side server has been killed."
    else
        echo "DesktopMatePort Wine-Side server is still running."
    fi
else
    echo "DesktopMatePort Wine-Side server is not running."
fi


cd ../backend
rm server_started.txt
# Open a window selector and pass the selected window size as argument
monitor_info=$(xrandr --query | grep " connected" | awk '{print $1}')

echo "Available monitors:"
i=1
for mon in $monitor_info; do
    echo "$i) $mon"
    i=$((i+1))
done

echo "Select monitor number:"
read monitor_index

i=1
for mon in $monitor_info; do
    if [ "$i" = "$monitor_index" ]; then
        monitor=$mon
        break
    fi
    i=$((i+1))
done

if [ -z "$monitor" ]; then
    echo "Invalid selection."
    exit 1
fi

echo "Selected monitor: $monitor"


monitor_geometry=$(xrandr --query | grep "^$monitor connected" | grep -o '[0-9]\+x[0-9]\++[0-9]\++[0-9]\+')
window_size=$(echo "$monitor_geometry" | awk -F'[x+]' '{print $1 "x" $2}')
window_pos=$(echo "$monitor_geometry" | awk -F'[x+]' '{print $3 "x" $4}')

echo "Selected window size: $window_size"

wine reg add "HKCU\Control Panel\Desktop" /v LogPixels /t REG_DWORD /d 100 /f
wine reg add "HKCU\\Software\\Wine\\Explorer" /v Desktop /t REG_SZ /d Default /f
wine reg add "HKCU\\Software\\Wine\\Explorer\\Desktops" /v Default /t REG_SZ /d $window_size /f

WINEPREFIX="${WINEPREFIX:-$HOME/.wine}"
STEAM_PATH="$WINEPREFIX/drive_c/Program Files (x86)/Steam"
STEAM_APPS_PATH="$STEAM_PATH/steamapps"
APP_ID=3301060

if [ ! -d "$STEAM_PATH" ]; then
    echo "Steam not found under Wine. Launching DesktopMate.exe..."
    wine explorer /desktop=shell,$window_size DesktopMate/DesktopMate.exe > /dev/null 2>&1 &
else
    if [ -f "$STEAM_APPS_PATH/appmanifest_${APP_ID}.acf" ]; then
        echo "Steam app $APP_ID installed. Running via Steam..."
        wine explorer /desktop=shell,$window_size "$STEAM_PATH/Steam.exe" -silent steam://run/$APP_ID > /dev/null 2>&1 &
    else
        echo "Steam app $APP_ID not installed. Running DesktopMate.exe..."
        wine explorer /desktop=shell,$window_size DesktopMate/DesktopMate.exe > /dev/null 2>&1 &
    fi
fi
echo "Workaround for Wine Desktop opening two windows..."
window_id=$(wmctrl -lx | grep -i "Wine.Desktop" | awk '{print $1}')
if [ -n "$window_id" ]; then
    pid=$(xprop -id "$window_id" _NET_WM_PID | awk '{print $3}')
    if [ -n "$pid" ]; then
        kill "$pid"
        echo "Killed Wine Desktop with PID $pid"
    else
        echo "PID not found for window ID $window_id"
    fi
else
    echo "Wine Desktop window not found"
fi
bash ../src/dskmptricks/scripts/disable_hide_kde.sh
bash ../src/dskmptricks/scripts/show.sh
notify-send "Press [ENTER] on the terminal when DesktopMate is showed up (the black window in wine)"
read -p "Enter when DesktopMate is running: "
bash ../src/dskmptricks/scripts/enable_hide_kde.sh
bash ../src/dskmptricks/scripts/hide.sh
wmctrl -r "shell - Wine Desktop" -b add,below
wine explorer /desktop=shell,$window_size python ./windows_server.py > /dev/null 2>&1 &
wine explorer /desktop=shell,$window_size mouse_block.exe > /dev/null 2>&1 &
if [ -n "$1" ]; then
    cpulimit_value="$1"
else
    cpulimit_value=10
fi
limitcpu -p $(pgrep -n wineserver) -l "$cpulimit_value" &
while [ ! -f server_started.txt ]; do
    sleep 1
done
sleep 4

cd ../../frontend

if [ -n "$2" ]; then
    env="$2"
else
    env=kde
fi

python3 window_client.py "$env" "$window_size" "$window_pos" > /dev/null 2>&1 &
./overlay_wayland -de "$env" -o "$window_pos"
overlay_pid=$!
trap 'echo "Stopping..."; wmctrl -r "shell - Wine Desktop" -b remove,below; kill $(pgrep -f "DesktopMate.exe"); kill $(pgrep -f "run.bat"); kill $(pgrep -f "mouse_block.exe"); kill $(pgrep -n wineserver); kill $overlay_pid; exit' INT
wait $overlay_pid
