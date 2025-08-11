#!/bin/bash

#===============================================================================================
#   System Required: CentOS 7+, Debian 8+, Ubuntu 16+
#   Description: A truly robust, fault-tolerant VPS speed test script
#   Author: AI Assistant
#   Version: 5.0 (Intelligent Fuzzy Search)
#
#   Features:
#   - Intelligent fuzzy search: Combines server fields to robustly find matches
#     even with non-standard naming conventions.
#   - Auto-detects architecture and downloads the correct Ookla Speedtest CLI.
#   - Caches the server list for efficiency and reliability.
#   - Auto-installs 'jq' if needed and cleans it up perfectly.
#   - Cleans up all temporary files automatically on exit.
#===============================================================================================

# --- Color Definitions ---
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# --- Global Variables ---
TEMP_DIR="/tmp/speedtest_$$"
SPEEDTEST_EXECUTABLE="${TEMP_DIR}/speedtest"
SERVER_LIST_CACHE="${TEMP_DIR}/servers.json"
JQ_INSTALLED_BY_SCRIPT=false

# --- Cleanup Function ---
cleanup() {
    echo -e "${YELLOW}\nCleaning up temporary files and dependencies...${NC}"
    rm -rf "${TEMP_DIR}"
    if [ "$JQ_INSTALLED_BY_SCRIPT" = true ]; then
        echo -e "${YELLOW}Uninstalling temporary dependency 'jq'...${NC}"
        if command -v apt-get &> /dev/null; then
            apt-get remove -y jq &> /dev/null
        elif command -v yum &> /dev/null; then
            yum remove -y jq &> /dev/null
        fi
    fi
    echo -e "${GREEN}Cleanup complete. Your system is clean.${NC}"
}
trap cleanup EXIT INT TERM

# --- Helper Functions ---
print_info() { echo -e "${BLUE}INFO: $1${NC}"; }
print_ok() { echo -e "${GREEN}OK: $1${NC}"; }
print_warn() { echo -e "${YELLOW}WARN: $1${NC}"; }
print_error() { echo -e "${RED}ERROR: $1${NC}" >&2; }

# --- Dependency Installation for JQ ---
install_jq() {
    if ! command -v jq &> /dev/null; then
        print_info "'jq' is not found. Attempting to install it..."
        if command -v apt-get &> /dev/null; then
            apt-get update -y >/dev/null && apt-get install -y jq
        elif command -v yum &> /dev/null; then
            # Enable EPEL for CentOS 7 to find jq
            yum install -y epel-release >/dev/null && yum install -y jq
        else
            print_error "Unsupported package manager. Please install 'jq' manually to run this script."
            exit 1
        fi
        JQ_INSTALLED_BY_SCRIPT=true
        print_ok "'jq' was installed temporarily."
    fi
}

# --- Speedtest Functions ---
download_speedtest_cli() {
    print_info "Detecting system architecture..."
    ARCH=$(uname -m)
    local url=""
    if [[ "$ARCH" == "x86_64" ]]; then
        url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
        print_ok "Architecture: x86_64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz"
        print_ok "Architecture: aarch64"
    else
        print_error "Unsupported architecture: $ARCH. Cannot proceed."
        exit 1
    fi

    print_info "Downloading Ookla Speedtest CLI..."
    mkdir -p "${TEMP_DIR}"
    if ! curl -sL "$url" -o "${TEMP_DIR}/speedtest.tgz"; then
        print_error "Download failed. Please check network."
        exit 1
    fi
    tar -xzf "${TEMP_DIR}/speedtest.tgz" -C "${TEMP_DIR}"
    chmod +x "${SPEEDTEST_EXECUTABLE}"
    print_ok "Speedtest CLI is ready."
}

# The core function to run a test by finding a server dynamically and robustly
run_dynamic_test() {
    local keyword="$1"
    local location="$2"
    local description="$location, $keyword"
    
    echo "------------------------------------------------------------"
    echo -e " Searching for server: ${YELLOW}${description}${NC}"
    
    # **THE ULTIMATE FIX**: Create a combined string of all relevant fields and search within it.
    # This is highly robust against non-standard server naming.
    local server_id
    server_id=$(jq -r --arg kw "$keyword" --arg loc "$location" '
        .servers[] |
        # Create a single searchable string from all relevant fields, handling nulls
        .search_string = ([.sponsor, .name, .location] | map(select(. != null)) | join(" ")) |
        # Check if BOTH keywords exist in the combined string (case-insensitive)
        select(.search_string | test($kw; "i")) |
        select(.search_string | test($loc; "i")) |
        .id' < "${SERVER_LIST_CACHE}" | head -n 1)

    if [[ -n "$server_id" ]]; then
        echo -e " ${GREEN}Found Server ID:${NC} ${BLUE}${server_id}${NC}. Running test..."
        echo "------------------------------------------------------------"
        $SPEEDTEST_EXECUTABLE --server-id="$server_id"
    else
        print_warn "No available server found for '$description'. This might be due to geo-restrictions or no listed servers for this provider in your region. Skipping."
    fi
    echo ""
}

# Main Ookla test runner
perform_ookla_tests() {
    print_info "Starting Ookla Speedtest..."
    
    # 1. Install jq if needed
    install_jq
    
    # 2. Accept license and fetch server list once
    print_info "Fetching server list from Ookla... (This may take a moment)"
    if ! $SPEEDTEST_EXECUTABLE --servers -f json --accept-license --accept-gdpr > "${SERVER_LIST_CACHE}"; then
        print_error "Failed to fetch server list. Your VPS might be blocked by Ookla's API."
        exit 1
    fi
    if [[ ! -s "${SERVER_LIST_CACHE}" ]]; then
        print_error "Server list is empty. Cannot proceed."
        exit 1
    fi
    print_ok "Server list cached successfully."

    # --- Run Test Cases ---
    echo -e "\n--- ${GREEN}Guangzhou ISP Tests${NC} ---"
    run_dynamic_test "Telecom" "Guangzhou"
    run_dynamic_test "Unicom" "Guangzhou"
    run_dynamic_test "Mobile" "Guangzhou"

    echo -e "\n--- ${GREEN}Hong Kong ISP Tests${NC} ---"
    run_dynamic_test "PCCW" "Hong Kong"
    run_dynamic_test "HGC" "Hong Kong"
    run_dynamic_test "HKBN" "Hong Kong"

    echo -e "\n--- ${GREEN}International Tests${NC} ---"
    run_dynamic_test "Rakuten" "Tokyo"
    run_dynamic_test "Singtel" "Singapore"
    run_dynamic_test "QuadraNet" "Los Angeles"

    print_ok "All Ookla speed tests are complete."
}


# --- Main Execution Logic ---
main() {
    download_speedtest_cli
    
    if $SPEEDTEST_EXECUTABLE --version > /dev/null 2>&1; then
        perform_ookla_tests
    else
        print_error "Ookla Speedtest CLI downloaded but failed to execute. Cannot proceed."
        exit 1
    fi
}

# --- Script Entry Point ---
main
exit 0
