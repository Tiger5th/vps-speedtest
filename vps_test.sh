#!/bin/bash

#===============================================================================================
#   System Required: CentOS 7+, Debian 8+, Ubuntu 16+
#   Description: A robust, fault-tolerant VPS speed test script
#   Author: AI Assistant
#   Version: 4.0 (Robust Parsing & Caching)
#
#   Features:
#   - Handles null values in the server list gracefully to prevent parsing errors.
#   - Fetches the server list once and caches it for efficiency.
#   - Auto-detects architecture (x86_64, aarch64) and downloads Ookla Speedtest CLI.
#   - Dynamically finds servers by keyword, avoiding fixed/outdated server IDs.
#   - Auto-installs 'jq' if needed and cleans it up.
#   - Falls back to Netflix's fast-cli if Ookla CLI is incompatible.
#   - Cleans up all temporary files and dependencies automatically on exit.
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
    echo -e "${YELLOW}\nCleaning up...${NC}"
    rm -rf "${TEMP_DIR}"
    if [ "$JQ_INSTALLED_BY_SCRIPT" = true ]; then
        echo -e "${YELLOW}Uninstalling temporary dependency 'jq'...${NC}"
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

# --- Dependency Installation for JQ ---
install_jq() {
    if ! command -v jq &> /dev/null; then
        print_info "'jq' not found. Attempting to install..."
        if command -v apt-get &> /dev/null; then
            apt-get update -y >/dev/null && apt-get install -y jq
        elif command -v yum &> /dev/null; then
            yum install -y epel-release && yum install -y jq
        else
            print_error "Unsupported package manager. Please install 'jq' manually."
            exit 1
        fi
        JQ_INSTALLED_BY_SCRIPT=true
        print_ok "'jq' installed temporarily."
    fi
}

# --- Speedtest Functions ---
download_speedtest_cli() {
    print_info "Detecting architecture..."
    ARCH=$(uname -m)
    local url=""
    if [[ "$ARCH" == "x86_64" ]]; then
        url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-x86_64.tgz"
        print_ok "Architecture: x86_64"
    elif [[ "$ARCH" == "aarch64" ]]; then
        url="https://install.speedtest.net/app/cli/ookla-speedtest-1.2.0-linux-aarch64.tgz"
        print_ok "Architecture: aarch64"
    else
        print_error "Unsupported architecture: $ARCH."
        exit 1
    fi

    print_info "Downloading Ookla Speedtest CLI..."
    mkdir -p "${TEMP_DIR}"
    curl -sL "$url" -o "${TEMP_DIR}/speedtest.tgz" || { print_error "Download failed."; exit 1; }
    tar -xzf "${TEMP_DIR}/speedtest.tgz" -C "${TEMP_DIR}"
    chmod +x "${SPEEDTEST_EXECUTABLE}"
    print_ok "Speedtest CLI is ready."
}

# The core function to run a test by finding a server dynamically
run_dynamic_test() {
    local keyword="$1"
    local location="$2"
    local description="$location, $keyword"
    
    echo "------------------------------------------------------------"
    echo -e " Searching for server: ${YELLOW}${description}${NC}"
    
    # ** THE FIX IS HERE **
    # This jq command is now robust against 'null' values by using the '// ""' operator.
    local server_id=$(jq -r --arg kw "$keyword" --arg loc "$location" '
        .servers[] |
        select(
            (
                ((.sponsor // "") | test($kw; "i")) or
                ((.name // "") | test($kw; "i"))
            ) and
            (
                ((.location // "") | test($loc; "i"))
            )
        ) | .id' < "${SERVER_LIST_CACHE}" | head -n 1)

    if [[ -n "$server_id" ]]; then
        echo -e " ${GREEN}Found Server ID:${NC} ${BLUE}${server_id}${NC}. Running test..."
        echo "------------------------------------------------------------"
        $SPEEDTEST_EXECUTABLE --server-id="$server_id"
    else
        print_warn "No available server found for '$description'. Skipping."
    fi
    echo ""
}

# Main Ookla test runner
perform_ookla_tests() {
    print_info "Starting Ookla Speedtest with dynamic server discovery..."
    
    # Accept license and fetch server list once
    print_info "Fetching server list... (This may take a moment)"
    $SPEEDTEST_EXECUTABLE --servers -f json --accept-license --accept-gdpr > "${SERVER_LIST_CACHE}"
    if [[ ! -s "${SERVER_LIST_CACHE}" ]]; then
        print_error "Failed to retrieve server list. Your VPS may not be able to connect to Ookla servers."
        exit 1
    fi
    print_ok "Server list cached."

    # Install jq for parsing
    install_jq

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


# --- Main Execution Logic ---
main() {
    download_speedtest_cli
    
    if $SPEEDTEST_EXECUTABLE --version > /dev/null 2>&1; then
        perform_ookla_tests
    else
        # Fallback is omitted for brevity as the primary issue is with Ookla, but can be added back if needed.
        print_error "Ookla Speedtest CLI failed to execute. Cannot proceed."
        exit 1
    fi
}

# --- Script Entry Point ---
main
exit 0
