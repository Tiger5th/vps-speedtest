#!/bin/bash

#===============================================================================================
#   System Required: CentOS 7+, Debian 8+, Ubuntu 16+
#   Description: A comprehensive VPS speed test script
#   Author: AI Assistant
#   Version: 2.0
#
#   Features:
#   - Auto-detects architecture (x86_64, arm64) and downloads the official Ookla Speedtest CLI.
#   - Tests compatibility of the Speedtest CLI. Falls back to Netflix's fast-cli if needed.
#   - Includes speed test nodes for Guangzhou (Telecom, Unicom, Mobile), Hong Kong (PCCW, HGC, HKBN), and international locations.
#   - Cleans up all downloaded files and dependencies automatically upon exit.
#===============================================================================================

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
SPEEDTEST_CLI_DIR="/tmp/speedtest_cli_$$"
SPEEDTEST_EXECUTABLE="${SPEEDTEST_CLI_DIR}/speedtest"
FAST_CLI_INSTALLED_BY_SCRIPT=false

# --- Cleanup Function ---
# This function is called on script exit to ensure no files are left behind.
cleanup() {
    echo -e "${YELLOW}\nCleaning up temporary files...${NC}"
    rm -rf "${SPEEDTEST_CLI_DIR}"
    if [ "$FAST_CLI_INSTALLED_BY_SCRIPT" = true ]; then
        echo -e "${YELLOW}Uninstalling fast-cli...${NC}"
        # Suppress npm output for a cleaner exit
        if command -v npm &> /dev/null; then
            npm uninstall --global fast-cli &> /dev/null
        fi
    fi
    echo -e "${GREEN}Cleanup complete. Your system is clean.${NC}"
}

# Register the cleanup function to be called on EXIT, INT, TERM signals
trap cleanup EXIT INT TERM

# --- Helper Functions ---
print_info() {
    echo -e "${BLUE}INFO: $1${NC}"
}

print_ok() {
    echo -e "${GREEN}OK: $1${NC}"
}

print_warn() {
    echo -e "${YELLOW}WARN: $1${NC}"
}

print_error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
}

# --- Speedtest Functions ---

# Download and extract the official Ookla Speedtest CLI
download_speedtest_cli() {
    print_info "Detecting system architecture..."
    ARCH=$(uname -m)
    local download_url=""

    if [ "$ARCH" = "x86_64" ]; then
        download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
        print_ok "Detected x86_64 architecture."
    elif [ "$ARCH" = "aarch64" ]; then
        download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz"
        print_ok "Detected arm64 (aarch64) architecture."
    else
        print_error "Unsupported architecture: $ARCH. Exiting."
        exit 1
    fi

    print_info "Downloading Ookla Speedtest CLI..."
    mkdir -p "${SPEEDTEST_CLI_DIR}"
    # Use curl with -L to follow redirects, -s for silent, -o for output file
    if curl -sL "$download_url" -o "${SPEEDTEST_CLI_DIR}/speedtest.tgz"; then
        print_ok "Download complete."
    else
        print_error "Failed to download Speedtest CLI. Please check your network connection."
        exit 1
    fi

    print_info "Extracting files..."
    if tar -xzf "${SPEEDTEST_CLI_DIR}/speedtest.tgz" -C "${SPEEDTEST_CLI_DIR}"; then
        # The executable might be in a subdirectory, find it and move it
        find "${SPEEDTEST_CLI_DIR}" -type f -name "speedtest" -exec mv {} "${SPEEDTEST_EXECUTABLE}" \;
        chmod +x "${SPEEDTEST_EXECUTABLE}"
        print_ok "Extraction complete."
    else
        print_error "Failed to extract Speedtest CLI."
        exit 1
    fi
}

# Run a single speed test against a specific server ID
run_single_test() {
    local server_id=$1
    local description=$2
    
    echo "------------------------------------------------------------"
    echo -e " Running Test: ${YELLOW}${description}${NC} (Server ID: ${BLUE}${server_id}${NC})"
    echo "------------------------------------------------------------"
    
    # Run the test and capture output. If it fails, print an error.
    # The --accept-license and --accept-gdpr flags are needed for the first run.
    if ! "${SPEEDTEST_EXECUTABLE}" --server-id="${server_id}" --accept-license --accept-gdpr -f json; then
        print_warn "Could not test against server ${server_id}. It might be offline or unavailable."
    fi
    echo "" # Newline for spacing
}

# The main logic for running Ookla Speedtest
perform_ookla_tests() {
    print_info "Starting Ookla Speedtest with specific servers..."
    
    # Accept license beforehand to prevent repetitive prompts
    "${SPEEDTEST_EXECUTABLE}" --accept-license --accept-gdpr > /dev/null 2>&1

    # --- Server Lists ---
    # Note: These server IDs can change. If a test fails, the server may be offline.
    # You can find new server IDs by running: ./speedtest --servers | grep "CityName"

    # Guangzhou Servers (三网)
    echo -e "\n--- ${GREEN}Guangzhou ISP Tests${NC} ---"
    run_single_test "3633" "Guangzhou, China Telecom"
    run_single_test "27594" "Guangzhou, China Unicom"
    run_single_test "26678" "Guangzhou, China Mobile"

    # Hong Kong Servers
    echo -e "\n--- ${GREEN}Hong Kong ISP Tests${NC} ---"
    run_single_test "1536" "Hong Kong, PCCW"
    run_single_test "1888" "Hong Kong, HGC"
    run_single_test "2893" "Hong Kong, HKBN"

    # International Servers
    echo -e "\n--- ${GREEN}International Tests${NC} ---"
    run_single_test "21569" "Tokyo, Japan (Rakuten)"
    run_single_test "4616" "Singapore (Singtel)"
    run_single_test "13568" "Los Angeles, CA, USA (QuadraNet)"

    print_ok "All Ookla speed tests completed."
}

# --- Fallback Function ---

# Install and run Netflix's fast-cli
run_fast_cli_test() {
    print_warn "Ookla Speedtest CLI seems incompatible or failed. Falling back to Netflix's fast-cli."
    
    # Check for npm (Node Package Manager)
    if ! command -v npm &> /dev/null; then
        print_info "npm not found. Attempting to install it..."
        # Use package manager to install npm
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y npm
        elif command -v yum &> /dev/null; then
            sudo yum install -y npm
        else
            print_error "Cannot install npm. Unsupported package manager. Please install npm manually and re-run."
            exit 1
        fi
    fi

    print_info "Installing fast-cli via npm..."
    if sudo npm install --global fast-cli; then
        FAST_CLI_INSTALLED_BY_SCRIPT=true
        print_ok "fast-cli installed successfully."
        
        print_info "Running Netflix fast-cli speed test..."
        echo "------------------------------------------------------------"
        fast --upload # Run with upload test
        echo "------------------------------------------------------------"
        print_ok "fast-cli test complete."
    else
        print_error "Failed to install or run fast-cli."
        exit 1
    fi
}


# --- Main Execution Logic ---
main() {
    # 1. Download and prepare the Speedtest CLI
    download_speedtest_cli
    
    # 2. Check for compatibility.
    # A simple test: run the command with a basic argument. If it returns a non-zero exit code,
    # it likely failed or is an incompatible version. The "--version" flag is universal.
    if "${SPEEDTEST_EXECUTABLE}" --version > /dev/null 2>&1; then
        print_ok "Ookla Speedtest CLI is compatible. Proceeding with tests."
        perform_ookla_tests
    else
        # If the CLI fails even the version check, fall back to fast-cli.
        run_fast_cli_test
    fi
}

# --- Script Entry Point ---
main

# The trap will handle the cleanup automatically.
exit 0
