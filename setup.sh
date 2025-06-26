#!/bin/bash
export WINEPREFIX=~/.dskmatewine
echo "[1/6] Checking for required dependencies..."
for cmd in winetricks wine python3 limitcpu zenity wget wmctrl; do
    if ! command -v $cmd &> /dev/null; then
        echo "Error: $cmd is not installed. Please install $cmd and rerun this script."
        exit 1
    fi
done
mkdir -p tmp_install
cd tmp_install
echo "[2/6] Installing Wine dependencies..."
wineboot
winetricks dxvk

echo "[3/6] Installing Python..."
wget https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe
wine python-3.10.0-amd64.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0
echo "[4/6] Installing Python dependencies..."
wine pip install opencv-python pywin32 pynput pygetwindow Pillow mss

echo "[5/6] Setting wine DPI to 100"
wine reg add "HKCU\Control Panel\Desktop" /v LogPixels /t REG_DWORD /d 100 /f

echo "[6/6] Setting up DesktopMate PORT..."
if [[ "$XDG_SESSION_DESKTOP" =~ (KDE|Hyprland) ]] || [[ "$XDG_CURRENT_DESKTOP" =~ (KDE|Hyprland) ]] || [[ "$XDG_SESSION_TYPE" == "wayland" && ( "$XDG_SESSION_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "KDE" ) ]]; then
    echo "Running under KDE/Wayland or Hyprland."
else
    echo "Not running under KDE/Wayland or Hyprland."
    echo -e "\e[33mWARNING: DesktopMate PORT may not work optimally outside KDE/Wayland or Hyprland environments.\e[0m"
fi


echo "Installed DesktopMate PORT!"

cd ..

read -p "Would you like to create the shortcut for KDE (input)? (y/n): " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Creating KDE shortcut..."
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMate [KDE]\nComment=DesktopMate - Linux Port\nPath=$(pwd)\nExec=$(pwd)/run.sh 20\nTerminal=true\n" > ~/.local/share/applications/Desktopmate[kde].desktop
    # your shortcut creation logic here
else
    echo "Skipping shortcut creation."
fi
read -p "Would you like to create the shortcut for Hyprland (input)? (y/n): " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Creating KDE shortcut..."
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMate [Hyprland]\nComment=DesktopMate - Linux Port (Hyprland)\nPath=$(pwd)\nExec=$(pwd)/run.sh 20 hyprland\nTerminal=true\n" > ~/.local/share/applications/Desktopmate[hyprland].desktop 
    # your shortcut creation logic here
else
    echo "Skipping shortcut creation."
fi
read -p "Do you want to install Steam under Wine? [REALLY recommended]? (y/n): " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Running steam install script"
    bash ./install_steam.sh
fi
read -p "Do you want to install the desktopmateport tricks? [recommended]? (y/n): " response
if [[ "$response" =~ ^[Yy]$ ]]; then
    echo "Installing desktopmate tricks desktop shortcut"
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMatePort TRICKS\nComment=Created by desktopfilecreator.com\nPath=$(pwd)/dskmptricks/\nExec=python3 main.py\nTerminal=false\n" > ~/.local/share/applications/DesktopmateportTricks.desktop
fi
# WINEPREFIX=~/.dskmatewine
# mkdir tmp_install
# cd tmp_install
# wget https://github.com/doitsujin/dxvk/releases/download/v2.6.2/dxvk-2.6.2.tar.gz
# tar -xvf dxvk-2.6.2.tar.gz
# cd dxvk-2.6.2
# DXVK_FOLDER=$(pwd)
# cp -v $DXVK_FOLDER/x64/* $WINEPREFIX/drive_c/windows/system32
# cp -v $DXVK_FOLDER/x32/* $WINEPREFIX/drive_c/windows/syswow64
