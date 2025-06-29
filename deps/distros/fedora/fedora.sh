#!/bin/bash

# Fedora-based system setup script for DesktopMatePort

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== Fedora System Setup ====="

# Check if we're running on Fedora
if ! grep -q "Fedora" /etc/os-release; then
    print_message "red" "This script is intended for Fedora systems only."
    exit 1
fi

# Get Fedora version
FEDORA_VERSION=$(grep -oP '(?<=VERSION_ID=)\d+' /etc/os-release)
if [ -z "$FEDORA_VERSION" ]; then
    print_message "red" "Could not determine Fedora version."
    exit 1
fi

print_message "green" "Detected Fedora version: $FEDORA_VERSION"

# Step 1: Enable all required repositories
print_message "blue" "Step 1: Enabling required repositories..."

# Check for RPM Fusion repositories
if ! dnf repolist | grep -q "rpmfusion"; then
    print_message "yellow" "RPM Fusion repositories are not enabled."
    
    if confirm "Would you like to enable RPM Fusion repositories now?"; then
        # Run the RPM Fusion installer
        bash "$SCRIPT_DIR/install_rpmfusion.sh" || {
            print_message "red" "Failed to enable RPM Fusion repositories. Please enable them manually and run setup.sh again."
            exit 1
        }
    else
        print_message "red" "RPM Fusion repositories are required. Please enable them manually and run setup.sh again."
        exit 1
    fi
else
    print_message "green" "✓ RPM Fusion repositories are already enabled."
fi

# Add WineHQ repository
if ! dnf repolist | grep -q "winehq"; then
    print_message "yellow" "WineHQ repository is not enabled. Adding it now..."
    
    # Check if the repo file already exists
    if [ -f "/etc/yum.repos.d/winehq.repo" ]; then
        print_message "yellow" "WineHQ repository file already exists but is not enabled."
        print_message "blue" "Checking if repository is valid..."
        
        # Try to enable the repo if it exists but is disabled
        sudo dnf config-manager --set-enabled winehq || sudo dnf config-manager --set-enabled WineHQ || {
            print_message "yellow" "Could not enable existing repository. Trying to overwrite..."
            sudo dnf config-manager addrepo --overwrite --from-repofile=https://dl.winehq.org/wine-builds/fedora/$FEDORA_VERSION/winehq.repo || {
                print_message "red" "Failed to add WineHQ repository. Some packages may not be available."
            }
        }
    else
        # Add the repository if it doesn't exist
        sudo dnf config-manager addrepo --from-repofile=https://dl.winehq.org/wine-builds/fedora/$FEDORA_VERSION/winehq.repo || {
            print_message "red" "Failed to add WineHQ repository. Some packages may not be available."
        }
    fi
    
    # Update package database after adding new repository
    print_message "blue" "Updating package database..."
    sudo dnf check-update || true
else
    print_message "green" "✓ WineHQ repository is already enabled."
fi

# Step 2: Install required packages from pkglist
print_message "blue" "Step 2: Installing required packages..."

# Read package lists
FEDORA_PKGS=$(readpkgs "$SCRIPT_DIR/pkglists/fedora.txt")

# Create an array of packages
declare -a PKGS_ARRAY
TOTAL_PKGS=0

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    
    PKGS_ARRAY+=("$pkg")
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
done <<< "$FEDORA_PKGS"

print_message "blue" "Found $TOTAL_PKGS packages to install"

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
    
    # First check if wine-common is installed, which conflicts with winehq-staging
    if rpm -q wine-common &>/dev/null && echo "$PACKAGES_TO_INSTALL" | grep -q "winehq-staging"; then
        print_message "yellow" "Detected potential conflict: wine-common is installed but winehq-staging is required."
        
        if confirm "Would you like to remove existing wine packages to avoid conflicts?"; then
            print_message "blue" "Removing wine-common and related packages to avoid conflicts..."
            sudo dnf remove -y wine\* || {
                print_message "yellow" "Could not remove wine packages. Will try to force installation."
            }
        else
            print_message "yellow" "Keeping existing wine packages. Installation may fail due to conflicts."
        fi
    fi
    
    # First try with allowerasing to handle conflicts
    print_message "blue" "Attempting installation with --allowerasing..."
    if ! sudo dnf install -y --allowerasing $PACKAGES_TO_INSTALL; then
        print_message "yellow" "Installation with --allowerasing failed."
        
        if confirm "Would you like to try installation with --skip-broken?"; then
            print_message "blue" "Attempting installation with --skip-broken..."
            
            # Try with skip-broken if allowerasing fails
            if ! sudo dnf install -y --skip-broken $PACKAGES_TO_INSTALL; then
                print_message "yellow" "Installation with --skip-broken failed."
                
                if confirm "Would you like to try installing packages one by one?"; then
                    print_message "blue" "Attempting to install packages one by one..."
                    
                    # Try installing packages one by one
                    for pkg in ${PACKAGES_TO_INSTALL}; do
                        print_message "blue" "Attempting to install: $pkg"
                        if ! sudo dnf install -y --allowerasing "$pkg"; then
                            print_message "red" "Failed to install package: $pkg"
                        else
                            print_message "green" "✓ Successfully installed: $pkg"
                        fi
                    done
                    
                    print_message "yellow" "Some packages may not have been installed."
                    if ! confirm "Continue anyway?"; then
                        exit 1
                    fi
                else
                    print_message "yellow" "Package installation incomplete."
                    if ! confirm "Continue anyway?"; then
                        exit 1
                    fi
                fi
            else
                print_message "yellow" "Installation completed with --skip-broken. Some packages may not have been installed."
                if ! confirm "Continue anyway?"; then
                    exit 1
                fi
            fi
        else
            print_message "yellow" "Package installation incomplete."
        if ! confirm "Continue anyway?"; then
            exit 1
            fi
        fi
    else
        print_message "green" "All packages installed successfully."
    fi
else
    print_message "green" "All required packages are already installed."
fi

# Step 3: Additional setup steps
print_message "blue" "Step 3: Performing additional setup steps..."

# Enable better font rendering
print_message "blue" "Setting up better font rendering..."
if ! rpm -q freetype-freeworld &>/dev/null; then
    sudo dnf install -y freetype-freeworld || {
        print_message "yellow" "Could not install improved font rendering. This is not critical."
    }
fi

# Install winetricks from GitHub
print_message "blue" "Installing winetricks from GitHub..."
if ! command_exists "winetricks"; then
    bash "$BASE_DIR/install_winetricks.sh" || {
        print_message "yellow" "Could not install winetricks from GitHub. Some Wine functionality may be limited."
    }
else
    print_message "green" "✓ Winetricks is already installed."
fi

print_message "green" "Fedora system setup completed successfully!" 