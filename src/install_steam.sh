#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "$SCRIPT_DIR/../deps/funcs.sh"

print_message "blue" "===== Steam Installation for DesktopMatePort ====="

mkdir -p ../tmp_install
cd ../tmp_install
export WINEPREFIX=~/.dskmatewine

print_message "blue" "[1/11] Downloading Steam installer..."
download_with_progress "https://cdn.akamai.steamstatic.com/client/installer/SteamSetup.exe" "SteamSetup.exe" "Downloading Steam setup..."

print_message "blue" "[2/11] Stopping any running Wine processes..."
killall wineserver 2>/dev/null || true
sleep 1

print_message "blue" "[3/11] Installing required Wine components..."
# List of Wine components to install with their descriptions
COMPONENTS=(
    "corefonts:Installing core fonts (for better text rendering)"
    "vcrun2015:Installing Visual C++ 2015 Runtime (required by Steam)"
    "d3dcompiler_43:Installing DirectX Compiler (for game compatibility)"
    "d3dx9_43:Installing DirectX 9 (for older games)"
    "dxvk:Installing DXVK (DirectX to Vulkan translation layer)"
    "xact:Installing XACT (for game audio support)"
    "openal:Installing OpenAL (for 3D audio)"
    "dotnet48:Installing .NET Framework 4.8 (required by many games)"
)

# Counter for progress display
COMPONENT_COUNT=${#COMPONENTS[@]}
CURRENT=0

for component in "${COMPONENTS[@]}"; do
    CURRENT=$((CURRENT + 1))
    NAME="${component%%:*}"
    DESC="${component#*:}"
    print_message "yellow" "[Component $CURRENT/$COMPONENT_COUNT] $DESC"
    run_wine_command "winetricks $NAME" "$DESC"
done

print_message "blue" "[10/11] Setting up Windows 10 environment..."
run_wine_command "winetricks win10" "Setting up Windows 10 environment"

print_message "blue" "[11/11] Running Steam installer..."
print_message "yellow" "Please follow the Steam installation wizard that will appear."
print_message "yellow" "After installation completes, you can close Steam."
run_wine_command "wine SteamSetup.exe" "Launching Steam installer"

print_message "green" "Steam installation completed!"
print_message "yellow" "You can now run Steam using the DesktopMatePort launcher."

cd ..
