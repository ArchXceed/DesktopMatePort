#!/bin/bash

# Get the directory where the script is located
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source utility functions
source "$SCRIPT_DIR/deps/funcs.sh"

print_message "blue" "===== DesktopMatePort Uninstaller ====="
print_message "yellow" "This script will remove all components installed by DesktopMatePort."
print_message "yellow" "Warning: This will not uninstall system packages that were installed during setup."

if ! confirm "Are you sure you want to uninstall DesktopMatePort?"; then
    print_message "green" "Uninstallation cancelled."
    exit 0
fi

# Remove Wine prefix
print_message "blue" "Removing Wine prefix..."
if [ -d "$HOME/.dskmatewine" ]; then
    rm -rf "$HOME/.dskmatewine" && print_message "green" "Wine prefix removed." || print_message "red" "Failed to remove Wine prefix."
else
    print_message "yellow" "Wine prefix not found."
fi

# Remove desktop shortcuts
print_message "blue" "Removing desktop shortcuts..."
for shortcut in "$HOME/.local/share/applications/Desktopmate[kde].desktop" \
                "$HOME/.local/share/applications/Desktopmate[hyprland].desktop" \
                "$HOME/.local/share/applications/DesktopmateportTricks.desktop"; do
    if [ -f "$shortcut" ]; then
        rm "$shortcut" && print_message "green" "Removed $shortcut" || print_message "red" "Failed to remove $shortcut"
    fi
done

# Remove temporary installation files
print_message "blue" "Removing temporary installation files..."
if [ -d "$SCRIPT_DIR/tmp_install" ]; then
    rm -rf "$SCRIPT_DIR/tmp_install" && print_message "green" "Temporary installation files removed." || print_message "red" "Failed to remove temporary installation files."
else
    print_message "yellow" "Temporary installation directory not found."
fi

# Kill any running processes
print_message "blue" "Stopping any running DesktopMate processes..."

# Kill mouse_block.exe process
pids=$(pgrep mouse_block.exe 2>/dev/null)
if [ -n "$pids" ]; then
    kill -9 $pids 2>/dev/null
    print_message "green" "Stopped mouse_block.exe process."
fi

# Kill windows_server.py process
pids=$(pgrep -f "python windows_server.py" 2>/dev/null)
if [ -n "$pids" ]; then
    kill -9 $pids 2>/dev/null
    print_message "green" "Stopped windows_server.py process."
fi

# Kill overlay_wayland process
pids=$(pgrep -f "overlay_wayland" 2>/dev/null)
if [ -n "$pids" ]; then
    kill -9 $pids 2>/dev/null
    print_message "green" "Stopped overlay_wayland process."
fi

# Check for and remove any wine processes
print_message "blue" "Checking for Wine processes..."
wine_pids=$(pgrep -f wine 2>/dev/null)
if [ -n "$wine_pids" ]; then
    print_message "yellow" "Found Wine processes. Attempting to terminate..."
    kill -9 $wine_pids 2>/dev/null
    print_message "green" "Wine processes terminated."
else
    print_message "green" "No Wine processes found."
fi

# Optional: Remove installed packages
if confirm "Would you like to remove packages that were installed by setup.sh? (This is optional)"; then
    # Detect package manager
    PKG_MANAGER=$(detect_package_manager)
    print_message "blue" "Detected package manager: $PKG_MANAGER"
    
    case "$PKG_MANAGER" in
        pacman)
            # Read package list for pacman-based systems
            if [ -f "$SCRIPT_DIR/deps/distros/arch/pkglists/arch.txt" ]; then
                print_message "blue" "Removing packages for pacman-based systems..."
                
                # Read the package list, excluding comments and empty lines
                PACKAGES=$(readpkgs "$SCRIPT_DIR/deps/distros/arch/pkglists/arch.txt")
                
                # Split into regular and AUR packages
                REGULAR_PKGS=""
                AUR_PKGS=""
                
                while read -r pkg; do
                    # Skip empty lines and comments
                    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                    
                    # Check if package is from official repos
                    if pacman -Qi "$pkg" &>/dev/null; then
                        REGULAR_PKGS+=" $pkg"
                    elif command_exists "pacman" && pacman -Qm "$pkg" &>/dev/null; then
                        AUR_PKGS+=" $pkg"
                    fi
                done <<< "$PACKAGES"
                
                # Remove AUR packages first if an AUR helper is available
                if [ -n "$AUR_PKGS" ]; then
                    AUR_HELPER=$(detect_aur_helper)
                    if [ -n "$AUR_HELPER" ]; then
                        print_message "blue" "Removing AUR packages using $AUR_HELPER..."
                        if confirm "Remove the following AUR packages? $AUR_PKGS"; then
                            $AUR_HELPER -Rns $AUR_PKGS || print_message "red" "Failed to remove some AUR packages."
                        fi
                    else
                        print_message "yellow" "No AUR helper found. Skipping AUR package removal."
                    fi
                fi
                
                # Remove regular packages
                if [ -n "$REGULAR_PKGS" ]; then
                    print_message "blue" "Removing packages from official repositories..."
                    if confirm "Remove the following packages? $REGULAR_PKGS"; then
                        sudo pacman -Rns $REGULAR_PKGS || print_message "red" "Failed to remove some packages."
                    fi
                fi
            else
                print_message "yellow" "Package list not found. Cannot remove packages."
            fi
            ;;
            
        apt)
            # Read package list for Debian/Ubuntu systems
            if [ -f "$SCRIPT_DIR/deps/distros/debian/pkglists/debian.txt" ]; then
                print_message "blue" "Removing packages for Debian/Ubuntu systems..."
                
                # Read the package list, excluding comments and empty lines
                PACKAGES=$(readpkgs "$SCRIPT_DIR/deps/distros/debian/pkglists/debian.txt")
                
                # Create a list of installed packages
                INSTALLED_PKGS=""
                
                while read -r pkg; do
                    # Skip empty lines and comments
                    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                    
                    # Check if package is installed
                    if dpkg -s "$pkg" &>/dev/null; then
                        INSTALLED_PKGS+=" $pkg"
                    fi
                done <<< "$PACKAGES"
                
                # Remove packages
                if [ -n "$INSTALLED_PKGS" ]; then
                    print_message "blue" "Removing installed packages..."
                    if confirm "Remove the following packages? $INSTALLED_PKGS"; then
                        # Special handling for winehq-staging
                        if echo "$INSTALLED_PKGS" | grep -q "winehq-staging"; then
                            print_message "blue" "Removing winehq-staging..."
                            sudo apt-get remove --purge -y winehq-staging || print_message "red" "Failed to remove winehq-staging."
                            # Remove Wine repository
                            if [ -f /etc/apt/sources.list.d/winehq.list ]; then
                                print_message "blue" "Removing WineHQ repository..."
                                sudo rm /etc/apt/sources.list.d/winehq.list
                                sudo rm -f /usr/share/keyrings/winehq.gpg
                            fi
                            # Update the package list
                            INSTALLED_PKGS=$(echo "$INSTALLED_PKGS" | sed 's/winehq-staging//')
                        fi
                        
                        # Special handling for winetricks (installed from GitHub)
                        if command_exists "winetricks"; then
                            print_message "blue" "Removing winetricks installed from GitHub..."
                            sudo rm -f /usr/bin/winetricks
                            sudo rm -f /usr/share/bash-completion/completions/winetricks
                            sudo rm -f /usr/share/man/man1/winetricks.1
                            print_message "green" "✓ Winetricks removed"
                        fi
                        
                        # Remove remaining packages
                        if [ -n "$INSTALLED_PKGS" ]; then
                            print_message "blue" "Removing packages: $INSTALLED_PKGS"
                            sudo apt-get remove --purge -y $INSTALLED_PKGS || print_message "red" "Failed to remove some packages."
                        fi
                        
                        # Run autoremove to clean up dependencies
                        print_message "blue" "Cleaning up unused dependencies..."
                        sudo apt-get autoremove -y
                    fi
                else
                    print_message "yellow" "No packages from our list are currently installed."
                fi
            else
                print_message "yellow" "Package list not found. Cannot remove packages."
            fi
            ;;
            
        dnf|yum)
            # Read package list for Fedora/RHEL systems
            if [ -f "$SCRIPT_DIR/deps/distros/fedora/pkglists/fedora.txt" ]; then
                print_message "blue" "Removing packages for Fedora/RHEL systems..."
                
                # Read the package list, excluding comments and empty lines
                PACKAGES=$(readpkgs "$SCRIPT_DIR/deps/distros/fedora/pkglists/fedora.txt")
                
                # Create a list of installed packages
                INSTALLED_PKGS=""
                
                while read -r pkg; do
                    # Skip empty lines and comments
                    [[ -z "$pkg" || "$pkg" =~ ^# ]] && continue
                    
                    # Check if package is installed
                    if rpm -q "$pkg" &>/dev/null; then
                        INSTALLED_PKGS+=" $pkg"
                    fi
                done <<< "$PACKAGES"
                
                # Remove packages
                if [ -n "$INSTALLED_PKGS" ]; then
                    print_message "blue" "Removing installed packages..."
                    if confirm "Remove the following packages? $INSTALLED_PKGS"; then
                        # Special handling for winehq-staging
                        if echo "$INSTALLED_PKGS" | grep -q "winehq-staging"; then
                            print_message "blue" "Removing winehq-staging..."
                            sudo dnf remove -y winehq-staging || print_message "red" "Failed to remove winehq-staging."
                            # Remove Wine repository
                            if [ -f /etc/yum.repos.d/winehq.repo ]; then
                                print_message "blue" "Removing WineHQ repository..."
                                sudo rm /etc/yum.repos.d/winehq.repo
                            fi
                            # Update the package list
                            INSTALLED_PKGS=$(echo "$INSTALLED_PKGS" | sed 's/winehq-staging//')
                        fi
                        
                        # Special handling for winetricks (check if installed via package or from GitHub)
                        if command_exists "winetricks"; then
                            if rpm -q winetricks &>/dev/null; then
                                print_message "blue" "Removing winetricks package..."
                                sudo dnf remove -y winetricks || print_message "red" "Failed to remove winetricks package."
                            else
                                print_message "blue" "Removing winetricks installed from GitHub..."
                                sudo rm -f /usr/bin/winetricks
                                sudo rm -f /usr/share/bash-completion/completions/winetricks
                                sudo rm -f /usr/share/man/man1/winetricks.1
                                print_message "green" "✓ Winetricks removed"
                            fi
                        fi
                        
                        # Remove remaining packages
                        if [ -n "$INSTALLED_PKGS" ]; then
                            sudo dnf remove -y $INSTALLED_PKGS || print_message "red" "Failed to remove some packages."
                        fi
                        
                        # Run autoremove to clean up dependencies
                        print_message "blue" "Cleaning up unused dependencies..."
                        sudo dnf autoremove -y
                        
                        # Remove RPM Fusion repositories if they exist
                        if rpm -q rpmfusion-free-release &>/dev/null || rpm -q rpmfusion-nonfree-release &>/dev/null; then
                            if confirm "Remove RPM Fusion repositories?"; then
                                print_message "blue" "Removing RPM Fusion repositories..."
                                sudo dnf remove -y rpmfusion-\*-release
                            fi
                        fi
                    fi
                else
                    print_message "yellow" "No packages from our list are currently installed."
                fi
            else
                print_message "yellow" "Package list not found. Cannot remove packages."
            fi
            ;;
            
        zypper)
            print_message "yellow" "Package removal for OpenSUSE is not yet implemented."
            ;;
            
        *)
            print_message "yellow" "Unsupported package manager: $PKG_MANAGER. Cannot remove packages."
            ;;
    esac
else
    print_message "yellow" "Skipping package removal."
fi

# Offer to remove the entire repository
if confirm "Do you want to remove the entire DesktopMatePort repository?"; then
    print_message "yellow" "This will delete all files in: $SCRIPT_DIR"
    if confirm "Are you ABSOLUTELY sure? This cannot be undone!"; then
        cd ..
        rm -rf "$SCRIPT_DIR" && print_message "green" "Repository removed." || print_message "red" "Failed to remove repository."
        print_message "green" "Uninstallation complete. The repository has been removed."
        exit 0
    fi
fi

print_message "green" "Uninstallation complete. The repository files remain but all installed components have been removed."
print_message "yellow" "You may want to manually remove any system packages that were installed specifically for DesktopMatePort if they are no longer needed." 