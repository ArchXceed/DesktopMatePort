#!/bin/bash

# Script to enable RPM Fusion repositories for Fedora
# RPM Fusion provides additional packages that are not included in the standard Fedora repositories

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== RPM Fusion Repository Setup ====="
print_message "yellow" "RPM Fusion repositories are required for some dependencies."

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

# Ask user which RPM Fusion repositories they want to enable
print_message "blue" "Which RPM Fusion repositories would you like to enable?"
echo "1. Free only (recommended for most users)"
echo "2. Non-Free only (includes proprietary software)"
echo "3. Both Free and Non-Free (recommended for maximum compatibility)"
echo "4. I'll set this up manually later"

read -p "Enter your choice [1-4]: " choice

case $choice in
    1)
        REPOS="free"
        print_message "green" "Enabling RPM Fusion Free repositories..."
        ;;
    2)
        REPOS="nonfree"
        print_message "green" "Enabling RPM Fusion Non-Free repositories..."
        ;;
    3)
        REPOS="free nonfree"
        print_message "green" "Enabling both RPM Fusion Free and Non-Free repositories..."
        ;;
    4)
        print_message "yellow" "Please set up RPM Fusion repositories manually and run setup.sh again."
        exit 0
        ;;
    *)
        REPOS="free nonfree"
        print_message "green" "Defaulting to both RPM Fusion Free and Non-Free repositories..."
        ;;
esac

# Installation process
print_message "blue" "[1/3] Checking for required dependencies..."
if ! command_exists "dnf"; then
    print_message "red" "DNF package manager not found. This is unusual for a Fedora system."
    exit 1
fi
print_message "green" "✓ DNF package manager is available"

# Enable RPM Fusion repositories
print_message "blue" "[2/3] Enabling RPM Fusion repositories..."

for repo in $REPOS; do
    if [ "$repo" = "free" ]; then
        print_message "yellow" "Enabling RPM Fusion Free repository..."
        sudo dnf install -y https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$FEDORA_VERSION.noarch.rpm || {
            print_message "red" "Failed to enable RPM Fusion Free repository."
            exit 1
        }
        print_message "green" "✓ RPM Fusion Free repository enabled successfully"
    elif [ "$repo" = "nonfree" ]; then
        print_message "yellow" "Enabling RPM Fusion Non-Free repository..."
        sudo dnf install -y https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-$FEDORA_VERSION.noarch.rpm || {
            print_message "red" "Failed to enable RPM Fusion Non-Free repository."
            exit 1
        }
        print_message "green" "✓ RPM Fusion Non-Free repository enabled successfully"
    fi
done

# Update package database
print_message "blue" "[3/3] Updating package database..."
sudo dnf check-update || true
print_message "green" "✓ Package database updated"

print_message "green" "RPM Fusion repositories have been successfully enabled!"
print_message "blue" "You can now continue with the setup process." 