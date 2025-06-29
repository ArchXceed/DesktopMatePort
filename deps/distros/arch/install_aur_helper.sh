#!/bin/bash

# Script to install an AUR helper (yay by default)
# Source: https://github.com/Jguer/yay

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== AUR Helper Installation ====="
print_message "yellow" "An AUR helper is required to install some dependencies."

# Ask user which AUR helper they prefer
print_message "blue" "Which AUR helper would you like to install?"
echo "1. yay (recommended) - Fast and simple AUR helper written in Go"
echo "2. paru - Feature-packed AUR helper based on yay, written in Rust"
echo "3. I'll install one manually later"

read -p "Enter your choice [1-3]: " choice

case $choice in
    2)
        AUR_HELPER="paru"
        CLONE_URL="https://aur.archlinux.org/paru.git"
        ;;
    3)
        print_message "yellow" "Please install an AUR helper manually and run setup.sh again."
        exit 0
        ;;
    *)
        AUR_HELPER="yay"
        CLONE_URL="https://aur.archlinux.org/yay.git"
        ;;
esac

print_message "green" "Installing $AUR_HELPER..."

# Check for required dependencies
print_message "blue" "[1/5] Checking for required dependencies..."
MISSING_DEPS=""
for pkg in git base-devel; do
    if ! pacman -Qi "$pkg" &>/dev/null; then
        MISSING_DEPS+=" $pkg"
    else
        print_message "green" "✓ $pkg is already installed"
    fi
done

# Install missing dependencies
if [ -n "$MISSING_DEPS" ]; then
    print_message "yellow" "Installing required dependencies:$MISSING_DEPS"
    sudo pacman -S --noconfirm $MISSING_DEPS || {
        print_message "red" "Failed to install dependencies. Please install them manually."
        exit 1
    }
    print_message "green" "✓ Dependencies installed successfully"
else
    print_message "green" "✓ All dependencies are already installed"
fi

# Create a temporary directory
print_message "blue" "[2/5] Creating temporary build directory..."
TEMP_DIR=$(mktemp -d)
cd "$TEMP_DIR" || {
    print_message "red" "Failed to create temporary directory"
    exit 1
}
print_message "green" "✓ Created temporary directory: $TEMP_DIR"

# Clone the repository
print_message "blue" "[3/5] Cloning $AUR_HELPER repository..."
git clone "$CLONE_URL" || {
    print_message "red" "Failed to clone $AUR_HELPER repository"
    exit 1
}
print_message "green" "✓ Repository cloned successfully"

# Build and install
print_message "blue" "[4/5] Building and installing $AUR_HELPER..."
cd "$AUR_HELPER" || {
    print_message "red" "Failed to enter $AUR_HELPER directory"
    exit 1
}

print_message "yellow" "This may take a few minutes. Please be patient..."
makepkg -si --noconfirm || {
    print_message "red" "Failed to build and install $AUR_HELPER"
    exit 1
}
print_message "green" "✓ $AUR_HELPER built and installed successfully"

# Clean up
print_message "blue" "[5/5] Cleaning up temporary files..."
cd "$SCRIPT_DIR" || true
rm -rf "$TEMP_DIR"
print_message "green" "✓ Temporary files cleaned up"

print_message "green" "$AUR_HELPER has been successfully installed!"
print_message "blue" "You can now continue with the setup process." 