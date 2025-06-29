#!/bin/bash

# Arch Linux setup script for DesktopMatePort

# Import utility functions
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
source "$BASE_DIR/funcs.sh"

print_message "blue" "===== Arch Linux System Setup ====="

# Check for AUR helper
AUR_HELPER=$(detect_aur_helper)
if [ -z "$AUR_HELPER" ]; then
    print_message "yellow" "No AUR helper found. An AUR helper is required for some packages."
    
    if confirm "Would you like to install an AUR helper now?"; then
        # Run the AUR helper installer
        bash "$SCRIPT_DIR/install_aur_helper.sh" || {
            print_message "red" "Failed to install AUR helper. Please install one manually and run setup.sh again."
            exit 1
        }
        
        # Re-detect AUR helper
        AUR_HELPER=$(detect_aur_helper)
        if [ -z "$AUR_HELPER" ]; then
            print_message "red" "AUR helper installation failed or was cancelled."
            exit 1
        fi
    else
        print_message "red" "AUR helper is required. Please install one manually and run setup.sh again."
        exit 1
    fi
fi

print_message "green" "Using AUR helper: $AUR_HELPER"

# Read package lists
print_message "blue" "Analyzing required packages..."
ARCH_PKGS=$(readpkgs "$SCRIPT_DIR/pkglists/arch.txt")

# Arrays to store packages
declare -a REGULAR_PKGS_ARRAY
declare -a AUR_PKGS_ARRAY

# Count total packages for progress display
TOTAL_PKGS=0

while read -r pkg; do
    # Skip empty lines and comments
    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
    
    TOTAL_PKGS=$((TOTAL_PKGS + 1))
    
    # Check if package is available in official repos
    if pacman -Si "$pkg" &>/dev/null; then
        REGULAR_PKGS_ARRAY+=("$pkg")
    else
        AUR_PKGS_ARRAY+=("$pkg")
    fi
done <<< "$ARCH_PKGS"

# Convert arrays to space-separated strings for pacman/AUR helper
REGULAR_PKGS="${REGULAR_PKGS_ARRAY[*]}"
AUR_PKGS="${AUR_PKGS_ARRAY[*]}"

print_message "blue" "Found $TOTAL_PKGS packages to install:"
print_message "blue" "- ${#REGULAR_PKGS_ARRAY[@]} packages from official repositories"
print_message "blue" "- ${#AUR_PKGS_ARRAY[@]} packages from AUR"

# Install regular packages
if [ ${#REGULAR_PKGS_ARRAY[@]} -gt 0 ]; then
    print_message "blue" "Installing packages from official repositories..."
    
    # Check if packages are already installed
    PACKAGES_TO_INSTALL=""
    for pkg in "${REGULAR_PKGS_ARRAY[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            PACKAGES_TO_INSTALL+=" $pkg"
        else
            print_message "green" "✓ Package already installed: $pkg"
        fi
    done
    
    if [ -n "$PACKAGES_TO_INSTALL" ]; then
        print_message "yellow" "Installing ${PACKAGES_TO_INSTALL}"
        sudo pacman -S --needed --noconfirm $PACKAGES_TO_INSTALL || {
            print_message "red" "Failed to install some packages from official repositories."
            if ! confirm "Continue anyway?"; then
                exit 1
            fi
        }
    else
        print_message "green" "All official repository packages are already installed."
    fi
fi

# Install AUR packages
if [ ${#AUR_PKGS_ARRAY[@]} -gt 0 ]; then
    print_message "blue" "Installing packages from AUR..."
    
    # Check if packages are already installed
    PACKAGES_TO_INSTALL=""
    for pkg in "${AUR_PKGS_ARRAY[@]}"; do
        if ! pacman -Qi "$pkg" &>/dev/null; then
            PACKAGES_TO_INSTALL+=" $pkg"
            print_message "yellow" "Installing AUR package: $pkg"
            $AUR_HELPER -S --needed --noconfirm "$pkg" || {
                print_message "red" "Failed to install AUR package: $pkg"
                if ! confirm "Continue anyway?"; then
                    exit 1
                fi
            }
        else
            print_message "green" "✓ AUR package already installed: $pkg"
        fi
    done
    
    if [ -z "$PACKAGES_TO_INSTALL" ]; then
        print_message "green" "All AUR packages are already installed."
    fi
fi

print_message "green" "Arch Linux system setup completed successfully!" 