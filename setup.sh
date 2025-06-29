#!/bin/bash
export WINEPREFIX=~/.dskmatewine

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "$SCRIPT_DIR/deps/funcs.sh"

print_message "blue" "===== DesktopMatePort Setup ====="

# Detect distribution and package manager
DISTRO=$(detect_distro)
PKG_MANAGER=$(detect_package_manager)
print_message "green" "Detected distribution: $DISTRO"
print_message "green" "Detected package manager: $PKG_MANAGER"

# Run distribution-specific setup
case "$PKG_MANAGER" in
    pacman)
        print_message "blue" "Running Arch Linux setup (pacman)..."
        bash "$SCRIPT_DIR/deps/distros/arch/arch.sh" || {
            print_message "red" "Arch Linux setup failed."
            exit 1
        }
        ;;
    dnf|yum)
        print_message "blue" "Running Fedora setup (dnf/yum)..."
        bash "$SCRIPT_DIR/deps/distros/fedora/fedora.sh" || {
            print_message "red" "Fedora setup failed."
            exit 1
        }
        ;;
    apt)
        print_message "blue" "Running Debian/Ubuntu setup (apt)..."
        bash "$SCRIPT_DIR/deps/distros/debian/debian.sh" || {
            print_message "red" "Debian/Ubuntu setup failed."
            exit 1
        }
        ;;
    zypper)
        print_message "blue" "Running openSUSE setup (zypper)..."
        bash "$SCRIPT_DIR/deps/distros/opensuse/opensuse.sh" || {
            print_message "red" "openSUSE setup failed."
            exit 1
        }
        ;;
    *)
        print_message "yellow" "Unsupported package manager: $PKG_MANAGER"
        print_message "yellow" "You may need to install dependencies manually."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
        ;;
esac

print_message "blue" "[1/6] Checking for required dependencies..."
for cmd in winetricks wine python3 zenity wget wmctrl; do
    if ! command_exists "$cmd"; then
        print_message "red" "Error: $cmd is not installed. Please install $cmd and rerun this script."
        exit 1
    fi
done

# Check for limitcpu separately as it might be named differently on some distros
if ! command_exists "limitcpu" && ! command_exists "cpulimit"; then
    print_message "red" "Error: limitcpu/cpulimit is not installed. Please install it and rerun this script."
    exit 1
fi

mkdir -p tmp_install
cd tmp_install
print_message "blue" "[2/6] Installing Wine dependencies..."
run_wine_command "wineboot" "Initializing Wine environment"
run_wine_command "winetricks dxvk" "Installing DXVK for DirectX support"

print_message "blue" "[3/6] Installing Python..."
download_with_progress "https://www.python.org/ftp/python/3.10.0/python-3.10.0-amd64.exe" "python-3.10.0-amd64.exe" "Downloading Python 3.10.0..."
run_wine_command "wine python-3.10.0-amd64.exe /quiet InstallAllUsers=1 PrependPath=1 Include_test=0" "Installing Python in Wine environment"

print_message "blue" "[4/6] Installing Python dependencies..."
# Install Python packages one by one to show progress
PYTHON_PACKAGES=("opencv-python" "pywin32" "pynput" "pygetwindow" "Pillow" "mss")
for package in "${PYTHON_PACKAGES[@]}"; do
    run_wine_command "wine pip install $package" "Installing Python package: $package"
done

print_message "blue" "[5/6] Setting wine DPI to 100"
run_wine_command 'wine reg add "HKCU\\Control Panel\\Desktop" /v LogPixels /t REG_DWORD /d 100 /f' "Configuring Wine DPI settings"

print_message "blue" "[6/6] Setting up DesktopMate PORT..."
if [[ "$XDG_SESSION_DESKTOP" =~ (KDE|Hyprland) ]] || [[ "$XDG_CURRENT_DESKTOP" =~ (KDE|Hyprland) ]] || [[ "$XDG_SESSION_TYPE" == "wayland" && ( "$XDG_SESSION_DESKTOP" == "KDE" || "$XDG_CURRENT_DESKTOP" == "KDE" ) ]]; then
    print_message "green" "Running under KDE/Wayland or Hyprland."
else
    print_message "yellow" "Not running under KDE/Wayland or Hyprland."
    print_message "yellow" "WARNING: DesktopMate PORT may not work optimally outside KDE/Wayland or Hyprland environments."
fi

print_message "green" "Installed DesktopMate PORT!"

cd ..

if confirm "Would you like to create the shortcut for KDE (input)?"; then
    print_message "blue" "Creating KDE shortcut..."
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMate [KDE]\nComment=DesktopMate - Linux Port\nPath=$(pwd)\nExec=$(pwd)/src/run.sh 20\nTerminal=true\n" > ~/.local/share/applications/Desktopmate[kde].desktop
else
    print_message "yellow" "Skipping shortcut creation."
fi

if confirm "Would you like to create the shortcut for Hyprland (input)?"; then
    print_message "blue" "Creating Hyprland shortcut..."
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMate [Hyprland]\nComment=DesktopMate - Linux Port (Hyprland)\nPath=$(pwd)\nExec=$(pwd)/src/run.sh 20 hyprland\nTerminal=true\n" > ~/.local/share/applications/Desktopmate[hyprland].desktop 
else
    print_message "yellow" "Skipping shortcut creation."
fi

if confirm "Do you want to install Steam under Wine? [REALLY recommended]?"; then
    print_message "blue" "Running steam install script"
    bash ./src/install_steam.sh
fi

if confirm "Do you want to install the desktopmateport tricks? [recommended]?"; then
    print_message "blue" "Installing desktopmate tricks desktop shortcut"
    echo -e "[Desktop Entry]\n# Created by desktopfilecreator.com\nType=Application\nVersion=1.0\nName=DesktopMatePort TRICKS\nComment=Created by desktopfilecreator.com\nPath=$(pwd)/dskmptricks/\nExec=python3 main.py\nTerminal=false\n" > ~/.local/share/applications/DesktopmateportTricks.desktop
fi

print_message "green" "Setup completed successfully!"
# WINEPREFIX=~/.dskmatewine
# mkdir tmp_install
# cd tmp_install
# wget https://github.com/doitsujin/dxvk/releases/download/v2.6.2/dxvk-2.6.2.tar.gz
# tar -xvf dxvk-2.6.2.tar.gz
# cd dxvk-2.6.2
# DXVK_FOLDER=$(pwd)
# cp -v $DXVK_FOLDER/x64/* $WINEPREFIX/drive_c/windows/system32
# cp -v $DXVK_FOLDER/x32/* $WINEPREFIX/drive_c/windows/syswow64
