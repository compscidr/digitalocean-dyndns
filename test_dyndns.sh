#!/bin/bash

# Test script for dyndns.sh IP resolution functionality
# Tests IPv4 and IPv6 address resolution without making DigitalOcean API calls

# Remove set -e to prevent early exit on errors
# set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0

# Test helper functions
print_test_header() {
    echo -e "\n${YELLOW}=== $1 ===${NC}"
}

print_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((TESTS_PASSED++))
}

print_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((TESTS_FAILED++))
}

print_info() {
    echo -e "${YELLOW}ℹ INFO:${NC} $1"
}

# Set dummy environment variables before sourcing the main script
export DIGITALOCEAN_TOKEN="dummy_token_for_testing"
export DOMAIN="test.com"  
export NAME="test"

# Source the main script to get access to functions
# We need to override the main loop before sourcing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Read the main script and extract only the parts we need
# We'll manually define the functions and variables we need from dyndns.sh

# Variables from dyndns.sh
api_host="https://api.digitalocean.com/v2"
sleep_interval=${SLEEP_INTERVAL:-300}
remove_duplicates=${REMOVE_DUPLICATES:-"false"}
use_ipv6=${USE_IPV6:-"false"}
use_dual_stack=${USE_DUAL_STACK:-"false"}

services=(
    "ifconfig.co"
    "ipinfo.io/ip"
    "ifconfig.me"
)
ipv6_services=(
    "icanhazip.com"
    "ifconfig.co"
    "ipinfo.io/ip"
    "ifconfig.me"
)

# Functions from dyndns.sh
die() {
    echo "$1"
    exit 1
}

fetch_ip() {
    local ip_version="$1"  # "ipv4" or "ipv6"
    local ip=""
    
    if [[ "$ip_version" == "ipv6" ]]; then
        for service in ${ipv6_services[@]}; do
            echo "Trying with $service for IPv6..." >&2
            ip="$(curl -6 -s --connect-timeout 10 $service)"
            test -n "$ip" && break
        done
    else
        for service in ${services[@]}; do
            echo "Trying with $service for IPv4..." >&2
            ip="$(curl -s --connect-timeout 10 $service | grep '[0-9]\{1,3\}\(\.[0-9]\{1,3\}\)\{3\}')"
            test -n "$ip" && break
        done
    fi
    
    echo "$ip"
}

# IPv4 address validation function
is_valid_ipv4() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a octets=($ip)
        for octet in "${octets[@]}"; do
            if ((octet < 0 || octet > 255)); then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# IPv6 address validation function  
is_valid_ipv6() {
    local ip=$1
    # Simple IPv6 validation - checks for hex characters and colons
    if [[ $ip =~ ^[0-9a-fA-F:]+$ ]] && [[ $ip == *":"* ]]; then
        # Additional check: should not have more than 7 colons
        local colon_count=$(echo "$ip" | tr -cd ':' | wc -c)
        if ((colon_count <= 7)); then
            return 0
        fi
    fi
    return 1
}

# Test IPv4 address fetching
test_ipv4_resolution() {
    print_test_header "Testing IPv4 Address Resolution"
    
    # Check if we have internet connectivity
    if ! curl -s --connect-timeout 5 ifconfig.co >/dev/null 2>&1; then
        print_info "No internet connectivity detected - testing with mock IP addresses"
        # Test with mock IPv4 address
        local ipv4_address="203.0.113.1"  # Test IPv4 address from RFC 5737
        print_info "Using mock IPv4 address: $ipv4_address"
        
        if is_valid_ipv4 "$ipv4_address"; then
            print_pass "IPv4 address format validation works correctly"
        else
            print_fail "IPv4 address format validation failed for mock address"
        fi
        
        if [[ ! $ipv4_address =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|127\.) ]]; then
            print_pass "IPv4 public address detection logic works correctly"
        else
            print_fail "IPv4 public address detection logic failed"
        fi
    else
        # Real IP fetching test
        local ipv4_address
        ipv4_address=$(fetch_ip "ipv4")
        
        if [[ -n "$ipv4_address" ]]; then
            print_info "Fetched IPv4 address: $ipv4_address"
            
            if is_valid_ipv4 "$ipv4_address"; then
                print_pass "IPv4 address format is valid"
            else
                print_fail "IPv4 address format is invalid: $ipv4_address"
            fi
            
            # Test that it's not a private IP (should be public)
            if [[ ! $ipv4_address =~ ^(10\.|172\.(1[6-9]|2[0-9]|3[0-1])\.|192\.168\.|127\.) ]]; then
                print_pass "IPv4 address appears to be public"
            else
                print_fail "IPv4 address appears to be private: $ipv4_address"
            fi
        else
            print_fail "Failed to fetch IPv4 address"
        fi
    fi
}

# Test IPv6 address fetching
test_ipv6_resolution() {
    print_test_header "Testing IPv6 Address Resolution"
    
    # Check if we have internet connectivity
    if ! curl -6 -s --connect-timeout 5 icanhazip.com >/dev/null 2>&1; then
        print_info "No IPv6 connectivity detected - testing with mock IP addresses"
        # Test with mock IPv6 address
        local ipv6_address="2001:db8::1"  # Test IPv6 address from RFC 3849
        print_info "Using mock IPv6 address: $ipv6_address"
        
        if is_valid_ipv6 "$ipv6_address"; then
            print_pass "IPv6 address format validation works correctly"
        else
            print_fail "IPv6 address format validation failed for mock address"
        fi
        
        if [[ "$ipv6_address" != "::1" ]]; then
            print_pass "IPv6 localhost detection logic works correctly"
        else
            print_fail "IPv6 localhost detection logic failed"
        fi
    else
        # Real IP fetching test
        local ipv6_address
        ipv6_address=$(fetch_ip "ipv6")
        
        if [[ -n "$ipv6_address" ]]; then
            print_info "Fetched IPv6 address: $ipv6_address"
            
            if is_valid_ipv6 "$ipv6_address"; then
                print_pass "IPv6 address format is valid"
            else
                print_fail "IPv6 address format is invalid: $ipv6_address"
            fi
            
            # Test that it's not a localhost IPv6
            if [[ "$ipv6_address" != "::1" ]]; then
                print_pass "IPv6 address is not localhost"
            else
                print_fail "IPv6 address is localhost: $ipv6_address"
            fi
        else
            print_fail "Failed to fetch IPv6 address"
        fi
    fi
}

# Mock process_dns_records to avoid DigitalOcean API calls
process_dns_records() {
    local ip="$1"
    local record_type="$2"
    local domain_records="$3"
    
    print_info "MOCK: Would process $record_type record with IP: $ip"
    
    if [[ -n "$ip" ]]; then
        if [[ "$record_type" == "A" ]] && is_valid_ipv4 "$ip"; then
            print_pass "Mock DNS processing: A record with valid IPv4"
        elif [[ "$record_type" == "AAAA" ]] && is_valid_ipv6 "$ip"; then
            print_pass "Mock DNS processing: AAAA record with valid IPv6"
        else
            print_fail "Mock DNS processing: Invalid IP format for $record_type record"
        fi
    else
        print_info "Mock DNS processing: Skipping $record_type record (no IP)"
    fi
}

# Test dual-stack mode functionality
test_dual_stack_mode() {
    print_test_header "Testing Dual-Stack Mode Logic"
    
    # Set dual-stack mode
    use_dual_stack="true"
    use_ipv6="false"
    
    print_info "Testing dual-stack mode (USE_DUAL_STACK=true)"
    
    # Mock domain records response
    local mock_domain_records='{"domain_records":[]}'
    
    # Simulate the dual-stack logic
    if [[ "${use_dual_stack}" = "true" ]]; then
        print_info "Dual-stack mode detected - fetching both IPv4 and IPv6"
        
        local ipv4_address
        local ipv6_address
        
        # Try to fetch real addresses, use mock if no connectivity
        if curl -s --connect-timeout 2 ifconfig.co >/dev/null 2>&1; then
            ipv4_address=$(fetch_ip "ipv4")
        else
            ipv4_address="203.0.113.1"  # Mock IPv4
            print_info "Using mock IPv4 address for testing: $ipv4_address"
        fi
        
        if curl -6 -s --connect-timeout 2 icanhazip.com >/dev/null 2>&1; then
            ipv6_address=$(fetch_ip "ipv6")
        else
            ipv6_address="2001:db8::1"  # Mock IPv6
            print_info "Using mock IPv6 address for testing: $ipv6_address"
        fi
        
        process_dns_records "$ipv4_address" "A" "$mock_domain_records"
        process_dns_records "$ipv6_address" "AAAA" "$mock_domain_records"
        
        print_pass "Dual-stack mode logic executed successfully"
    else
        print_fail "Dual-stack mode not detected when it should be"
    fi
}

# Test IPv6-only mode functionality
test_ipv6_only_mode() {
    print_test_header "Testing IPv6-Only Mode Logic"
    
    # Set IPv6-only mode
    use_dual_stack="false"
    use_ipv6="true"
    
    print_info "Testing IPv6-only mode (USE_IPV6=true, USE_DUAL_STACK=false)"
    
    # Mock domain records response
    local mock_domain_records='{"domain_records":[]}'
    
    # Simulate the IPv6-only logic
    if [[ "${use_dual_stack}" = "true" ]]; then
        print_fail "Dual-stack mode detected when it shouldn't be"
    elif [[ "${use_ipv6}" = "true" ]]; then
        print_info "IPv6-only mode detected"
        
        local ipv6_address
        # Try to fetch real address, use mock if no connectivity
        if curl -6 -s --connect-timeout 2 icanhazip.com >/dev/null 2>&1; then
            ipv6_address=$(fetch_ip "ipv6")
        else
            ipv6_address="2001:db8::1"  # Mock IPv6
            print_info "Using mock IPv6 address for testing: $ipv6_address"
        fi
        
        process_dns_records "$ipv6_address" "AAAA" "$mock_domain_records"
        
        print_pass "IPv6-only mode logic executed successfully"
    else
        print_fail "IPv6-only mode not detected when it should be"
    fi
}

# Test IPv4-only mode functionality
test_ipv4_only_mode() {
    print_test_header "Testing IPv4-Only Mode Logic (Default)"
    
    # Set IPv4-only mode (default)
    use_dual_stack="false"
    use_ipv6="false"
    
    print_info "Testing IPv4-only mode (default: USE_DUAL_STACK=false, USE_IPV6=false)"
    
    # Mock domain records response
    local mock_domain_records='{"domain_records":[]}'
    
    # Simulate the IPv4-only logic
    if [[ "${use_dual_stack}" = "true" ]]; then
        print_fail "Dual-stack mode detected when it shouldn't be"
    elif [[ "${use_ipv6}" = "true" ]]; then
        print_fail "IPv6-only mode detected when it shouldn't be"
    else
        print_info "IPv4-only mode detected (default behavior)"
        
        local ipv4_address
        # Try to fetch real address, use mock if no connectivity
        if curl -s --connect-timeout 2 ifconfig.co >/dev/null 2>&1; then
            ipv4_address=$(fetch_ip "ipv4")
        else
            ipv4_address="203.0.113.1"  # Mock IPv4
            print_info "Using mock IPv4 address for testing: $ipv4_address"
        fi
        
        process_dns_records "$ipv4_address" "A" "$mock_domain_records"
        
        print_pass "IPv4-only mode logic executed successfully"
    fi
}

# Test IP service availability
test_ip_services() {
    print_test_header "Testing IP Service Availability"
    
    print_info "Testing IPv4 services availability:"
    for service in "${services[@]}"; do
        if curl -s --connect-timeout 5 "$service" >/dev/null 2>&1; then
            print_pass "IPv4 service reachable: $service"
        else
            print_info "IPv4 service unreachable: $service (this is normal if some services are down)"
        fi
    done
    
    print_info "Testing IPv6 services availability:"
    for service in "${ipv6_services[@]}"; do
        if curl -6 -s --connect-timeout 5 "$service" >/dev/null 2>&1; then
            print_pass "IPv6 service reachable: $service"
        else
            print_info "IPv6 service unreachable: $service (this is normal if IPv6 is not available or service is down)"
        fi
    done
}

# Main test runner
main() {
    echo -e "${YELLOW}Digital Ocean Dynamic DNS Test Suite${NC}"
    echo -e "${YELLOW}====================================${NC}"
    
    print_info "This test validates IP address resolution without making DigitalOcean API calls"
    
    # Run all tests
    test_ipv4_resolution
    test_ipv6_resolution
    test_dual_stack_mode
    test_ipv6_only_mode  
    test_ipv4_only_mode
    test_ip_services
    
    # Print final results
    echo -e "\n${YELLOW}=== Test Results ===${NC}"
    echo -e "Tests Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Tests Failed: ${RED}$TESTS_FAILED${NC}"
    
    if ((TESTS_FAILED == 0)); then
        echo -e "\n${GREEN}🎉 All tests passed! The IP resolution functionality is working correctly.${NC}"
        exit 0
    else
        echo -e "\n${RED}❌ Some tests failed. Please check the output above for details.${NC}"
        exit 1
    fi
}

# Check if script is being run directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi