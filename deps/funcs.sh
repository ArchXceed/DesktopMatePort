#!/bin/bash

# Function to read packages from a file
readpkgs() {
    local pkgfile="$1"
    if [ ! -f "$pkgfile" ]; then
        echo "Package file not found: $pkgfile"
        return 1
    fi
    
    # Read packages, ignoring comments and empty lines
    grep -v '^#' "$pkgfile" | grep -v '^$'
}

# Function to detect Linux distribution
detect_distro() {
    if [ -f /etc/os-release ]; then
        . /etc/os-release
        echo "$ID"
    elif [ -f /etc/arch-release ]; then
        echo "arch"
    elif [ -f /etc/debian_version ]; then
        echo "debian"
    elif [ -f /etc/fedora-release ]; then
        echo "fedora"
    else
        echo "unknown"
    fi
}

# Function to detect package manager
detect_package_manager() {
    if command_exists "pacman"; then
        echo "pacman"
    elif command_exists "apt"; then
        echo "apt"
    elif command_exists "dnf"; then
        echo "dnf"
    elif command_exists "yum"; then
        echo "yum"
    elif command_exists "zypper"; then
        echo "zypper"
    else
        echo "unknown"
    fi
}

# Function to check if a command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Function to detect AUR helpers
detect_aur_helper() {
    for helper in yay paru pamac aurman trizen pacaur; do
        if command_exists "$helper"; then
            echo "$helper"
            return 0
        fi
    done
    echo ""
    return 1
}

# Function to print colored messages
print_message() {
    local color="$1"
    local message="$2"
    
    case "$color" in
        "red")    echo -e "\033[0;31m$message\033[0m" ;;
        "green")  echo -e "\033[0;32m$message\033[0m" ;;
        "yellow") echo -e "\033[0;33m$message\033[0m" ;;
        "blue")   echo -e "\033[0;34m$message\033[0m" ;;
        *)        echo "$message" ;;
    esac
}

# Function to ask for confirmation
confirm() {
    local prompt="$1"
    local default="${2:-y}"
    
    while true; do
        if [ "$default" = "y" ]; then
            read -p "$prompt [Y/n] " response
            response=${response:-y}
        else
            read -p "$prompt [y/N] " response
            response=${response:-n}
        fi
        
        case "$response" in
            [Yy]* ) return 0 ;;
            [Nn]* ) return 1 ;;
            * ) echo "Please answer yes or no." ;;
        esac
    done
}

# Function to run wine commands with a loading indicator
run_wine_command() {
    local command="$1"
    local message="$2"
    local temp_file=$(mktemp)
    
    # Print the message
    echo -n "$message "
    
    # Start the wine command in the background
    bash -c "$command" > "$temp_file" 2>&1 &
    local pid=$!
    
    # Display a loading animation while the command is running
    local chars="⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"
    local i=0
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#chars} ))
        echo -ne "\r$message ${chars:$i:1} "
        sleep 0.1
    done
    
    # Check if the command was successful
    wait $pid
    local exit_code=$?
    
    if [ $exit_code -eq 0 ]; then
        echo -e "\r$message \033[0;32m✓\033[0m"
    else
        echo -e "\r$message \033[0;31m✗\033[0m"
        echo "Error details:"
        cat "$temp_file"
    fi
    
    # Clean up
    rm -f "$temp_file"
    return $exit_code
}

# Function to create a modern progress bar
show_modern_progress() {
    local percent="$1"
    local width=50
    local bar_char="█"
    local empty_char="░"
    local filled=$((percent * width / 100))
    
    # ANSI color codes for gradient effect
    local colors=("\033[38;5;27m" "\033[38;5;33m" "\033[38;5;39m" "\033[38;5;45m" "\033[38;5;51m")
    local num_colors=${#colors[@]}
    
    echo -ne "\r\033[K"  # Clear the line
    
    # Show percentage with a nice format
    echo -ne "\033[1m${percent}%\033[0m "
    
    # Show the progress bar with gradient effect
    echo -ne "["
    
    for ((i=0; i<filled; i++)); do
        local color_idx=$((i * num_colors / width))
        echo -ne "${colors[$color_idx]}$bar_char\033[0m"
    done
    
    for ((i=filled; i<width; i++)); do
        echo -ne "$empty_char"
    done
    
    echo -ne "]"
    
    # Show speed and ETA if provided
    if [ -n "$2" ]; then
        echo -ne " \033[90m$2\033[0m"
    fi
}

# Function to download a file with a modern progress bar
download_with_progress() {
    local url="$1"
    local output_file="$2"
    local message="$3"
    
    echo "$message"
    
    if command_exists "curl"; then
        # Use curl with its built-in progress bar
        curl --progress-bar -L -o "$output_file" "$url"
        local exit_code=$?
        
        if [ $exit_code -ne 0 ]; then
            echo -e "\nDownload failed."
        fi
        
        return $exit_code
    elif command_exists "wget"; then
        # Initialize progress bar at 0%
        show_modern_progress 0
        
        # Use wget with custom progress output
        wget --progress=dot:mega "$url" -O "$output_file" 2>&1 | 
        while read -r line; do
            if [[ $line =~ ([0-9]+)% ]]; then
                local percent="${BASH_REMATCH[1]}"
                local speed=""
                if [[ $line =~ ([0-9.]+[KM]) ]]; then
                    speed="${BASH_REMATCH[1]}B/s"
                fi
                show_modern_progress "$percent" "$speed"
            fi
        done
        
        local exit_code=${PIPESTATUS[0]}
        
        if [ $exit_code -eq 0 ]; then
            show_modern_progress 100
            echo  # New line after completion
        else
            echo -e "\nDownload failed."
        fi
        
        return $exit_code
    else
        print_message "red" "Neither wget nor curl is installed. Cannot download file."
        return 1
    fi
}

# Function to show a simple progress bar
show_progress() {
    local message="$1"
    local duration="$2"  # in seconds
    local width=50
    local interval=$(echo "scale=3; $duration / $width" | bc)
    
    echo -n "$message ["
    for ((i=0; i<width; i++)); do
        echo -n " "
    done
    echo -n "] 0%"
    
    for ((i=0; i<width; i++)); do
        sleep $interval
        echo -ne "\r$message ["
        for ((j=0; j<=i; j++)); do
            echo -n "="
        done
        for ((j=i+1; j<width; j++)); do
            echo -n " "
        done
        local percent=$((($i+1)*100/width))
        echo -n "] $percent%"
    done
    echo
} 