#!/bin/bash

#===============================================================================================
#   System Required: CentOS 7+, Debian 8+, Ubuntu 16+
#   Description: A comprehensive and robust VPS speed test script
#   Author: AI Assistant
#   Version: 3.0 (Dynamic Server Discovery)
#
#   Features:
#   - Auto-detects architecture (x86_64, aarch64) and downloads the official Ookla Speedtest CLI.
#   - Dynamically finds best available servers by keyword, avoiding fixed/outdated server IDs.
#   - Automatically installs 'jq' dependency for server list parsing if not present.
#   - Falls back to Netflix's fast-cli if Ookla Speedtest CLI is incompatible.
#   - Tests Guangzhou (3 ISPs), Hong Kong (3 ISPs), and key international locations.
#   - Cleans up all downloaded files and dependencies automatically upon exit.
#===============================================================================================

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# --- Global Variables ---
TEMP_DIR="/tmp/speedtest_$$"
SPEEDTEST_EXECUTABLE="${TEMP_DIR}/speedtest"
FAST_CLI_INSTALLED_BY_SCRIPT=false
JQ_INSTALLED_BY_SCRIPT=false

# --- Cleanup Function ---
cleanup() {
    echo -e "${YELLOW}\nCleaning up temporary files and dependencies...${NC}"
    rm -rf "${TEMP_DIR}"
    if [ "$FAST_CLI_INSTALLED_BY_SCRIPT" = true ] && command -v npm &> /dev/null; then
        echo -e "${YELLOW}Uninstalling fast-cli...${NC}"
        npm uninstall --global fast-cli &> /dev/null
    fi
    if [ "$JQ_INSTALLED_BY_SCRIPT" = true ]; then
        echo -e "${YELLOW}Uninstalling jq...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get remove -y jq &> /dev/null
        elif command -v yum &> /dev/null; then
            yum remove -y jq &> /dev/null
        fi
    fi
    echo -e "${GREEN}Cleanup complete.${NC}"
}

trap cleanup EXIT INT TERM

# --- Helper Functions ---
print_info() { echo -e "${BLUE}INFO: $1${NC}"; }
print_ok() { echo -e "${GREEN}OK: $1${NC}"; }
print_warn() { echo -e "${YELLOW}WARN: $1${NC}"; }
print_error() { echo -e "${RED}ERROR: $1${NC}" >&2; }

# --- Dependency Installation ---
install_dependency() {
    local cmd=$1
    local package=$2
    if ! command -v $cmd &> /dev/null; then
        print_info "Dependency '$cmd' not found. Attempting to install package '$package'..."
        if command -v apt-get &> /dev/null; then
            apt-get update -y > /dev/null && apt-get install -y $package
        elif command -v yum &> /dev/null; then
            yum install -y $package
        else
            print_error "Unsupported package manager. Please install '$package' manually."
            exit 1
        fi
        if ! command -v $cmd &> /dev/null; then
             print_error "Failed to install '$package'. Please install it manually."
             exit 1
        fi
        # Mark for cleanup
        [[ "$package" == "jq" ]] && JQ_INSTALLED_BY_SCRIPT=true
        print_ok "'$package' installed successfully."
    fi
}


# --- Speedtest Functions ---
download_speedtest_cli() {
    print_info "Detecting system architecture..."
    ARCH=$(uname -m)
    local download_url=""

    if [[ "$ARCH" == "x86_64" ]]; then
        download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
        print_ok "Detected x86_64 architecture."
    elif [[ "$ARCH" == "aarch64" ]]; then
        download_url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz"
        print_ok "Detected arm64 (aarch64) architecture."
    else
        print_error "Unsupported architecture: $ARCH. Exiting."
        exit 1
    fi

    print_info "Downloading Ookla Speedtest CLI..."
    mkdir -p "${TEMP_DIR}"
    if curl -sL "$download_url" -o "${TEMP_DIR}/speedtest.tgz"; then
        print_ok "Download complete."
    else
        print_error "Failed to download Speedtest CLI."
        exit 1
    fi

    print_info "Extracting files..."
    tar -xzf "${TEMP_DIR}/speedtest.tgz" -C "${TEMP_DIR}"
    chmod +x "${SPEEDTEST_EXECUTABLE}"
    print_ok "Extraction complete."
}

# Dynamically finds a server ID and runs the test
run_dynamic_test() {
    local keyword="$1"
    local location="$2"
    local description="$location, $keyword"
    
    echo "------------------------------------------------------------"
    echo -e " Searching for server: ${YELLOW}${description}${NC}"
    
    # Find server ID using keyword search with jq
    # We use a trick: search for sponsor, location, and name to increase chances
    local server_id=$($SPEEDTEST_EXECUTABLE --servers -f json | jq -r --arg kw "$keyword" --arg loc "$location" '
        .servers[] | 
        select(
            (.sponsor | test($kw; "i")) or 
            (.name | test($kw; "i"))
        ) | 
        select(.country == $loc or .name | test($loc; "i")) |
        .id' | head -n 1)

    if [[ -n "$server_id" ]]; then
        echo -e " ${GREEN}Found Server ID:${NC} ${BLUE}${server_id}${NC}. Running test..."
        echo "------------------------------------------------------------"
        $SPEEDTEST_EXECUTABLE --server-id="$server_id" --accept-license --accept-gdpr
    else
        print_warn "No available server found for '$description'. Skipping."
    fi
    echo "" # Newline for spacing
}

perform_ookla_tests() {
    print_info "Starting Ookla Speedtest with dynamic server discovery..."
    
    # Accept license beforehand
    $SPEEDTEST_EXECUTABLE --accept-license --accept-gdpr > /dev/null 2>&1

    # Install jq for parsing
    install_dependency "jq" "jq"

    # --- Test Cases ---
    echo -e "\n--- ${GREEN}Guangzhou ISP Tests${NC} ---"
    run_dynamic_test "China Telecom" "Guangzhou"
    run_dynamic_test "China Unicom" "Guangzhou"
    run_dynamic_test "China Mobile" "Guangzhou"

    echo -e "\n--- ${GREEN}Hong Kong ISP Tests${NC} ---"
    run_dynamic_test "PCCW" "Hong Kong"
    run_dynamic_test "HGC" "Hong Kong"
    run_dynamic_test "HKBN" "Hong Kong"

    echo -e "\n--- ${GREEN}International Tests${NC} ---"
    run_dynamic_test "Rakuten" "Tokyo"
    run_dynamic_test "Singtel" "Singapore"
    run_dynamic_test "QuadraNet" "Los Angeles"

    print_ok "All Ookla speed tests completed."
}

# --- Fallback Function ---
run_fast_cli_test() {
    print_warn "Ookla Speedtest CLI seems incompatible. Falling back to Netflix's fast-cli."
    install_dependency "npm" "npm"
    print_info "Installing fast-cli via npm..."
    if npm install --global fast-cli; then
        FAST_CLI_INSTALLED_BY_SCRIPT=true
        print_ok "fast-cli installed. Running test..."
        echo "------------------------------------------------------------"
        fast --upload
        echo "------------------------------------------------------------"
    else
        print_error "Failed to install or run fast-cli."
    fi
}

# --- Main Execution Logic ---
main() {
    download_speedtest_cli
    
    if $SPEEDTEST_EXECUTABLE --version > /dev/null 2>&1; then
        print_ok "Ookla Speedtest CLI is compatible."
        perform_ookla_tests
    else
        run_fast_cli_test
    fi
}

# --- Script Entry Point ---
main
exit 0
