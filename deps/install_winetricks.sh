#!/bin/bash

# Script to install winetricks from GitHub
# Based on the official installation method from https://github.com/Winetricks/winetricks

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
source "$SCRIPT_DIR/funcs.sh"

print_message "blue" "===== Installing Winetricks from GitHub ====="

# Create and switch to a temporary directory
TMP_DIR=$(mktemp -d)
cd "$TMP_DIR" || {
    print_message "red" "Failed to create temporary directory."
    exit 1
}

print_message "blue" "[1/5] Downloading winetricks script..."
if command_exists "wget"; then
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks || {
        print_message "red" "Failed to download winetricks script."
        exit 1
    }
elif command_exists "curl"; then
    curl -O https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks || {
        print_message "red" "Failed to download winetricks script."
        exit 1
    }
else
    print_message "red" "Neither wget nor curl is installed. Cannot download winetricks."
    exit 1
fi

print_message "blue" "[2/5] Making winetricks executable..."
chmod +x winetricks || {
    print_message "red" "Failed to make winetricks executable."
    exit 1
}

print_message "blue" "[3/5] Installing winetricks to /usr/bin..."
sudo mv winetricks /usr/bin/ || {
    print_message "red" "Failed to install winetricks to /usr/bin."
    exit 1
}

print_message "blue" "[4/5] Downloading winetricks bash completion..."
if command_exists "wget"; then
    wget https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion || {
        print_message "yellow" "Failed to download bash completion, but continuing anyway."
    }
elif command_exists "curl"; then
    curl -O https://raw.githubusercontent.com/Winetricks/winetricks/master/src/winetricks.bash-completion || {
        print_message "yellow" "Failed to download bash completion, but continuing anyway."
    }
fi

if [ -f "winetricks.bash-completion" ]; then
    print_message "blue" "[5/5] Installing bash completion..."
    # Create directory if it doesn't exist
    sudo mkdir -p /usr/share/bash-completion/completions/
    sudo mv winetricks.bash-completion /usr/share/bash-completion/completions/winetricks || {
        print_message "yellow" "Failed to install bash completion, but continuing anyway."
    }
else
    print_message "yellow" "Skipping bash completion installation."
fi

# Clean up
cd "$SCRIPT_DIR" || true
rm -rf "$TMP_DIR"

# Verify installation
if command_exists "winetricks"; then
    print_message "green" "Winetricks has been successfully installed!"
    winetricks --version
else
    print_message "red" "Winetricks installation failed."
    exit 1
fi 