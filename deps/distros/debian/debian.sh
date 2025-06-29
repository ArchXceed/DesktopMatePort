#!/bin/bash

# Debian/Ubuntu setup script for DesktopMatePort

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== Debian/Ubuntu System Setup ====="

# Check if we're running on Debian or Ubuntu
if ! grep -qE "Debian|Ubuntu" /etc/os-release; then
    print_message "red" "This script is intended for Debian or Ubuntu-based systems only."
    exit 1
fi

# Check if we have 32-bit architecture enabled
if ! dpkg --print-foreign-architectures | grep -q i386; then
    print_message "yellow" "Enabling 32-bit architecture support (required for Wine)..."
    sudo dpkg --add-architecture i386 || {
        print_message "red" "Failed to enable 32-bit architecture support."
        exit 1
    }
    print_message "green" "✓ 32-bit architecture support enabled"
    
    # Update package lists after adding architecture
    print_message "yellow" "Updating package lists..."
    sudo apt update || {
        print_message "red" "Failed to update package lists."
        exit 1
    }
fi

# Add Wine repository
if [ ! -f /etc/apt/sources.list.d/winehq.list ] && [ ! -f /etc/apt/sources.list.d/wine-obs.list ]; then
    print_message "yellow" "Adding WineHQ repository..."
    
    # Install prerequisites for adding the repository
    sudo apt install -y ca-certificates gnupg2 software-properties-common wget || {
        print_message "red" "Failed to install prerequisites for WineHQ repository."
        exit 1
    }
    
    # Get OS information
    source /etc/os-release
    
    print_message "blue" "Detected OS: $ID $VERSION_CODENAME"
    
    # Download and add the WineHQ repository key
    print_message "blue" "Adding WineHQ repository key..."
    wget -qO- https://dl.winehq.org/wine-builds/winehq.key | sudo gpg --dearmor --yes -o /usr/share/keyrings/winehq.gpg
    
    if [[ "$ID" == "ubuntu" ]]; then
        # For Ubuntu
        print_message "blue" "Adding WineHQ repository for Ubuntu $UBUNTU_CODENAME..."
        echo "deb [signed-by=/usr/share/keyrings/winehq.gpg] https://dl.winehq.org/wine-builds/ubuntu/ $UBUNTU_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null || {
            print_message "red" "Failed to add WineHQ repository."
            exit 1
        }
    elif [[ "$ID" == "debian" ]]; then
        # For Debian
        print_message "blue" "Adding WineHQ repository for Debian $VERSION_CODENAME..."
        echo "deb [signed-by=/usr/share/keyrings/winehq.gpg] https://dl.winehq.org/wine-builds/debian/ $VERSION_CODENAME main" | \
            sudo tee /etc/apt/sources.list.d/winehq.list > /dev/null || {
            print_message "red" "Failed to add WineHQ repository."
            exit 1
        }
    fi
    
    # Update package lists after adding repository
    print_message "yellow" "Updating package lists..."
    sudo apt update || {
        print_message "red" "Failed to update package lists."
        exit 1
    }
    
    print_message "green" "✓ WineHQ repository added"
fi

# Install dependencies required for Wine
print_message "blue" "Installing dependencies required for Wine..."
sudo apt install -y --install-recommends libfaudio0 libfaudio0:i386 || {
    print_message "yellow" "Could not install some Wine dependencies. This might cause issues with Wine."
}

# Read package lists
print_message "blue" "Analyzing required packages..."
DEBIAN_PKGS=$(readpkgs "$SCRIPT_DIR/pkglists/debian.txt")

# Create an array of packages
declare -a PKGS_ARRAY
TOTAL_PKGS=0

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    
    PKGS_ARRAY+=("$pkg")
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
done <<< "$DEBIAN_PKGS"

print_message "blue" "Found $TOTAL_PKGS packages to install"

# Check which packages are already installed
print_message "blue" "Checking installed packages..."
PACKAGES_TO_INSTALL=""
for pkg in "${PKGS_ARRAY[@]}"; do
    if ! dpkg -s "$pkg" &>/dev/null; then
        PACKAGES_TO_INSTALL+=" $pkg"
    else
        print_message "green" "✓ Package already installed: $pkg"
    fi
done

# Install missing packages
if [ -n "$PACKAGES_TO_INSTALL" ]; then
    print_message "yellow" "Installing missing packages. This may take some time..."
    
    # Check if winehq-staging is in the list of packages to install
    if echo "$PACKAGES_TO_INSTALL" | grep -q "winehq-staging"; then
        print_message "blue" "Installing winehq-staging with recommended packages..."
        
        # Extract winehq-staging from the list
        WINE_PKG="winehq-staging"
        OTHER_PKGS=$(echo "$PACKAGES_TO_INSTALL" | sed 's/winehq-staging//')
        
        # Install winehq-staging with --install-recommends
        if ! sudo apt install -y --install-recommends $WINE_PKG; then
            print_message "red" "Failed to install winehq-staging."
            if ! confirm "Continue without Wine?"; then
                exit 1
            fi
        else
            print_message "green" "✓ winehq-staging installed successfully"
        fi
        
        # Update the packages list to exclude winehq-staging
        PACKAGES_TO_INSTALL="$OTHER_PKGS"
    fi
    
    # Try to install the remaining packages
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        print_message "blue" "Installing remaining packages..."
        if ! sudo apt install -y $PACKAGES_TO_INSTALL; then
            print_message "red" "Failed to install some packages."
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        fi
    fi
else
    print_message "green" "All required packages are already installed."
fi

# Always install winetricks from GitHub
print_message "blue" "Installing winetricks from GitHub..."
bash "$BASE_DIR/install_winetricks.sh" || {
    print_message "red" "Failed to install winetricks from GitHub."
    if ! confirm "Continue without winetricks?"; then
        exit 1
    fi
}

# Install Vulkan support
print_message "blue" "Setting up Vulkan support..."
if ! dpkg -s libvulkan1 libvulkan1:i386 &>/dev/null; then
    sudo apt install -y libvulkan1 libvulkan1:i386 || {
        print_message "yellow" "Could not install Vulkan support. Some games may not work correctly."
    }
fi

print_message "green" "Debian/Ubuntu system setup completed successfully!" 