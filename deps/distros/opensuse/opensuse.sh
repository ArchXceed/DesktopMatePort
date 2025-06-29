#!/bin/bash

# openSUSE setup script for DesktopMatePort

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== openSUSE System Setup ====="

# Check if we're running on openSUSE
if ! grep -q "openSUSE" /etc/os-release; then
    print_message "red" "This script is intended for openSUSE systems only."
    exit 1
fi

# Add Wine repository if not already added
if ! zypper lr | grep -q "Wine"; then
    print_message "yellow" "Adding Wine repository..."
    
    # Get OS information
    source /etc/os-release
    
    # Print debug information
    print_message "blue" "Detected OS: $NAME $VERSION_ID ($PRETTY_NAME)"
    
    # Add Wine repository based on version
    if [[ "$NAME" == *"Leap"* || "$PRETTY_NAME" == *"Leap"* ]]; then
        # For openSUSE Leap
        VERSION_NUMBER=$(echo "$VERSION_ID" | grep -oP '\d+\.\d+' || echo "$VERSION_ID")
        print_message "blue" "Detected Leap version: $VERSION_NUMBER"
        
        sudo zypper addrepo -f https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Leap_$VERSION_NUMBER/Emulators:Wine.repo || {
            print_message "red" "Failed to add Wine repository."
            exit 1
        }
    elif [[ "$NAME" == *"Tumbleweed"* || "$PRETTY_NAME" == *"Tumbleweed"* ]]; then
        # For openSUSE Tumbleweed
        print_message "blue" "Detected Tumbleweed"
        
        sudo zypper addrepo -f https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/Emulators:Wine.repo || {
            print_message "red" "Failed to add Wine repository."
            exit 1
        }
    else
        print_message "yellow" "Could not determine openSUSE version from: $PRETTY_NAME"
        print_message "yellow" "Assuming Tumbleweed as fallback..."
        
        sudo zypper addrepo -f https://download.opensuse.org/repositories/Emulators:/Wine/openSUSE_Tumbleweed/Emulators:Wine.repo || {
            print_message "red" "Failed to add Wine repository."
            exit 1
        }
    fi
    
    # Refresh repositories
    print_message "yellow" "Refreshing repositories..."
    sudo zypper --gpg-auto-import-keys refresh || {
        print_message "red" "Failed to refresh repositories."
        exit 1
    }
    
    print_message "green" "✓ Wine repository added"
fi

# Read package lists
print_message "blue" "Analyzing required packages..."
OPENSUSE_PKGS=$(readpkgs "$SCRIPT_DIR/pkglists/opensuse.txt")

# Create an array of packages
declare -a PKGS_ARRAY
TOTAL_PKGS=0

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    
    PKGS_ARRAY+=("$pkg")
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
done <<< "$OPENSUSE_PKGS"

print_message "blue" "Found $TOTAL_PKGS packages to install"

# Check for busybox-which package that conflicts with xdg-utils
if rpm -q busybox-which &>/dev/null && ! rpm -q which &>/dev/null; then
    print_message "yellow" "Detected package conflict: xdg-utils requires 'which', but 'busybox-which' is installed instead."
    if confirm "Would you like to replace busybox-which with the standard which package?"; then
        print_message "blue" "Replacing busybox-which with which package..."
        sudo zypper remove -y busybox-which
        sudo zypper install -y which
        print_message "green" "✓ Package conflict resolved"
    else
        print_message "yellow" "Warning: Some packages may not install correctly without resolving this conflict."
    fi
fi

# Check which packages are already installed
print_message "blue" "Checking installed packages..."
PACKAGES_TO_INSTALL=""
for pkg in "${PKGS_ARRAY[@]}"; do
    if ! rpm -q "$pkg" &>/dev/null; then
        PACKAGES_TO_INSTALL+=" $pkg"
    else
        print_message "green" "✓ Package already installed: $pkg"
    fi
done

# Install missing packages
if [ -n "$PACKAGES_TO_INSTALL" ]; then
    print_message "yellow" "Installing missing packages. This may take some time..."
    sudo zypper install --allow-vendor-change -y $PACKAGES_TO_INSTALL || {
        print_message "red" "Failed to install some packages."
        if ! confirm "Continue anyway?"; then
            exit 1
        fi
    }
else
    print_message "green" "All required packages are already installed."
fi

print_message "green" "openSUSE system setup completed successfully!" 