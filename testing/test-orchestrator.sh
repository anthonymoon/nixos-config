#!/usr/bin/env bash
# NixOS Agent-Based Test Orchestrator
# Complete automation of NixOS profile testing with real-time monitoring

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
VM_MANAGER="$SCRIPT_DIR/vm-manager.sh"
STREAM_RUNNER="$SCRIPT_DIR/stream-runner.sh"
AGENT_MONITOR="$SCRIPT_DIR/agent-monitor.py"
CONFIG_ROOT="$(dirname "$SCRIPT_DIR")"

# Test configuration
PROFILES=("vm" "workstation" "server")
PARALLEL_TESTS=false
LOG_DIR="/tmp/nixos-testing/logs"
REPORT_DIR="/tmp/nixos-testing/reports"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Test results tracking
declare -A test_results
declare -A test_durations
declare -A test_logs

log() { echo -e "${GREEN}[ORCHESTRATOR]${NC} $1"; }
warn() { echo -e "${YELLOW}[ORCHESTRATOR]${NC} $1"; }
error() { echo -e "${RED}[ORCHESTRATOR]${NC} $1"; }
info() { echo -e "${BLUE}[ORCHESTRATOR]${NC} $1"; }

# Banner display
show_banner() {
    echo -e "${CYAN}"
    echo "╔═══════════════════════════════════════════════════════════════════╗"
    echo "║                    🤖 NixOS Agent-Based Testing                  ║"
    echo "║                     Real-Time Installation Monitor               ║"
    echo "╚═══════════════════════════════════════════════════════════════════╝"
    echo -e "${NC}"
    echo ""
    echo -e "${BLUE}Configuration Repository:${NC} $CONFIG_ROOT"
    echo -e "${BLUE}Test Profiles:${NC} ${PROFILES[*]}"
    echo -e "${BLUE}Parallel Testing:${NC} $PARALLEL_TESTS"
    echo -e "${BLUE}Log Directory:${NC} $LOG_DIR"
    echo ""
}

# Prerequisites check
check_prerequisites() {
    log "Checking prerequisites..."
    
    # Check required tools
    local missing_tools=()
    
    for tool in virsh virt-install qemu-img python3 rsync wget; do
        if ! command -v "$tool" >/dev/null; then
            missing_tools+=("$tool")
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        error "Missing required tools: ${missing_tools[*]}"
        echo "Please install the missing tools and try again."
        exit 1
    fi
    
    # Check Python modules
    if ! python3 -c "import subprocess, threading, json, re" 2>/dev/null; then
        error "Required Python modules not available"
        exit 1
    fi
    
    # Check libvirt access
    if ! virsh list >/dev/null 2>&1; then
        error "Cannot access libvirt. Check permissions and libvirtd service."
        echo "Try: sudo usermod -a -G libvirt \$USER"
        exit 1
    fi
    
    # Create directories
    mkdir -p "$LOG_DIR" "$REPORT_DIR"
    
    log "Prerequisites check passed ✓"
}

# Setup test environment
setup_environment() {
    log "Setting up test environment..."
    
    # Initialize VM infrastructure
    if ! "$VM_MANAGER" ip >/dev/null 2>&1; then
        log "Setting up base VM infrastructure..."
        "$VM_MANAGER" setup
    else
        log "VM infrastructure already exists"
    fi
    
    log "Test environment ready ✓"
}

# Run a single profile test with full monitoring
test_single_profile() {
    local profile="$1"
    local timestamp=$(date '+%Y%m%d_%H%M%S')
    local test_log="$LOG_DIR/test_${profile}_${timestamp}.log"
    local start_time=$(date +%s)
    
    log "Starting agent-monitored test for profile: $profile"
    
    # Create test-specific log file
    touch "$test_log"
    test_logs["$profile"]="$test_log"
    
    # Run the test with agent monitoring
    if python3 "$AGENT_MONITOR" "$profile" \
       bash "$STREAM_RUNNER" "$profile" 2>&1 | tee "$test_log"; then
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        test_results["$profile"]="SUCCESS"
        test_durations["$profile"]="$duration"
        
        log "✅ Profile $profile: SUCCESS (${duration}s)"
        return 0
    else
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        test_results["$profile"]="FAILED"
        test_durations["$profile"]="$duration"
        
        error "❌ Profile $profile: FAILED (${duration}s)"
        return 1
    fi
}

# Run tests sequentially
run_sequential_tests() {
    log "Running sequential tests for all profiles..."
    
    local failed_tests=()
    local total_start_time=$(date +%s)
    
    for profile in "${PROFILES[@]}"; do
        echo ""
        echo -e "${PURPLE}═══ Testing Profile: $profile ═══${NC}"
        
        if ! test_single_profile "$profile"; then
            failed_tests+=("$profile")
        fi
        
        # Brief pause between tests
        sleep 5
    done
    
    local total_end_time=$(date +%s)
    local total_duration=$((total_end_time - total_start_time))
    
    generate_test_report "$total_duration" "${failed_tests[@]}"
    
    return ${#failed_tests[@]}
}

# Run tests in parallel (experimental)
run_parallel_tests() {
    log "Running parallel tests (experimental)..."
    warn "Parallel testing requires multiple VMs - not yet implemented"
    
    # For now, fall back to sequential
    run_sequential_tests
}

# Generate comprehensive test report
generate_test_report() {
    local total_duration="$1"
    shift
    local failed_tests=("$@")
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local report_file="$REPORT_DIR/test_report_$(date +%Y%m%d_%H%M%S).json"
    local summary_file="$REPORT_DIR/test_summary_$(date +%Y%m%d_%H%M%S).txt"
    
    log "Generating test report..."
    
    # Create JSON report
    cat > "$report_file" << EOF
{
  "timestamp": "$timestamp",
  "total_duration_seconds": $total_duration,
  "profiles_tested": [$(printf '"%s",' "${PROFILES[@]}" | sed 's/,$//')],
  "results": {
EOF
    
    # Add individual results
    local first=true
    for profile in "${PROFILES[@]}"; do
        if [[ "$first" == "true" ]]; then
            first=false
        else
            echo "," >> "$report_file"
        fi
        
        echo -n "    \"$profile\": {" >> "$report_file"
        echo -n "\"status\": \"${test_results[$profile]:-UNKNOWN}\"," >> "$report_file"
        echo -n "\"duration_seconds\": ${test_durations[$profile]:-0}," >> "$report_file"
        echo -n "\"log_file\": \"${test_logs[$profile]:-}\""  >> "$report_file"
        echo -n "}" >> "$report_file"
    done
    
    echo "" >> "$report_file"
    echo "  }," >> "$report_file"
    echo "  \"summary\": {" >> "$report_file"
    echo "    \"total_tests\": ${#PROFILES[@]}," >> "$report_file"
    echo "    \"passed\": $((${#PROFILES[@]} - ${#failed_tests[@]}))," >> "$report_file"
    echo "    \"failed\": ${#failed_tests[@]}" >> "$report_file"
    echo "  }" >> "$report_file"
    echo "}" >> "$report_file"
    
    # Create human-readable summary
    cat > "$summary_file" << EOF
NixOS Agent-Based Testing Summary
Generated: $timestamp

═══════════════════════════════════════
TEST OVERVIEW
═══════════════════════════════════════
Total Duration: ${total_duration}s
Profiles Tested: ${#PROFILES[@]}
Passed: $((${#PROFILES[@]} - ${#failed_tests[@]}))
Failed: ${#failed_tests[@]}

═══════════════════════════════════════
INDIVIDUAL RESULTS
═══════════════════════════════════════
EOF
    
    for profile in "${PROFILES[@]}"; do
        local status="${test_results[$profile]:-UNKNOWN}"
        local duration="${test_durations[$profile]:-0}"
        local icon="❓"
        
        case "$status" in
            "SUCCESS") icon="✅" ;;
            "FAILED") icon="❌" ;;
        esac
        
        echo "$icon $profile: $status (${duration}s)" >> "$summary_file"
    done
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        echo "" >> "$summary_file"
        echo "═══════════════════════════════════════" >> "$summary_file"
        echo "FAILED TESTS" >> "$summary_file"
        echo "═══════════════════════════════════════" >> "$summary_file"
        
        for failed_profile in "${failed_tests[@]}"; do
            echo "❌ $failed_profile - Check log: ${test_logs[$failed_profile]}" >> "$summary_file"
        done
    fi
    
    # Display summary
    echo ""
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    echo -e "${CYAN}           TEST RESULTS SUMMARY        ${NC}"
    echo -e "${CYAN}═══════════════════════════════════════${NC}"
    
    cat "$summary_file" | tail -n +4
    
    echo ""
    echo -e "${BLUE}📊 Detailed report:${NC} $report_file"
    echo -e "${BLUE}📄 Summary report:${NC} $summary_file"
    
    # Show final status
    if [[ ${#failed_tests[@]} -eq 0 ]]; then
        echo -e "${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}💥 ${#failed_tests[@]} test(s) failed${NC}"
        return 1
    fi
}

# Cleanup function
cleanup() {
    log "Cleaning up test environment..."
    
    # Stop any running VMs
    if "$VM_MANAGER" ip >/dev/null 2>&1; then
        "$VM_MANAGER" clean
    fi
    
    log "Cleanup complete"
}

# Main help function
show_help() {
    echo "NixOS Agent-Based Test Orchestrator"
    echo ""
    echo "Usage: $0 [OPTIONS] [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  test [profile]    Run tests (all profiles or specific profile)"
    echo "  setup            Setup test environment only"
    echo "  cleanup          Clean up test environment"
    echo "  status           Show current test environment status"
    echo "  help             Show this help"
    echo ""
    echo "Options:"
    echo "  --parallel       Run tests in parallel (experimental)"
    echo "  --profiles LIST  Specify profiles to test (comma-separated)"
    echo ""
    echo "Examples:"
    echo "  $0 test                    # Test all profiles sequentially"
    echo "  $0 test vm                 # Test only VM profile"
    echo "  $0 --profiles vm,server test  # Test specific profiles"
    echo "  $0 setup                   # Setup environment only"
}

# Parse command line arguments
parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --parallel)
                PARALLEL_TESTS=true
                shift
                ;;
            --profiles)
                IFS=',' read -ra PROFILES <<< "$2"
                shift 2
                ;;
            test)
                if [[ -n "${2:-}" && "$2" != --* ]]; then
                    PROFILES=("$2")
                    shift 2
                else
                    shift
                fi
                COMMAND="test"
                ;;
            setup)
                COMMAND="setup"
                shift
                ;;
            cleanup)
                COMMAND="cleanup"
                shift
                ;;
            status)
                COMMAND="status"
                shift
                ;;
            help|--help|-h)
                show_help
                exit 0
                ;;
            *)
                error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

# Main execution
main() {
    local COMMAND="test"
    
    # Parse arguments
    parse_args "$@"
    
    # Setup signal handlers
    trap cleanup EXIT
    trap 'cleanup; exit 130' INT
    
    # Show banner
    show_banner
    
    case "$COMMAND" in
        "setup")
            check_prerequisites
            setup_environment
            log "Environment setup complete"
            ;;
        "test")
            check_prerequisites
            setup_environment
            
            if [[ "$PARALLEL_TESTS" == "true" ]]; then
                run_parallel_tests
            else
                run_sequential_tests
            fi
            ;;
        "cleanup")
            cleanup
            ;;
        "status")
            info "Test Environment Status:"
            if "$VM_MANAGER" ip >/dev/null 2>&1; then
                local vm_ip=$("$VM_MANAGER" ip)
                echo "  VM Status: Running (IP: $vm_ip)"
            else
                echo "  VM Status: Stopped"
            fi
            echo "  Log Directory: $LOG_DIR"
            echo "  Report Directory: $REPORT_DIR"
            ;;
        *)
            error "Unknown command: $COMMAND"
            show_help
            exit 1
            ;;
    esac
}

main "$@"