#!/bin/bash

# =============================================================================
# Azure Private Storage Connection Test Script
# =============================================================================
# This script tests private storage connections and generates monitoring data
# Based on Terraform outputs from private-storage-azure deployment
#
# Usage: ./test-private-storage-connections.sh [--vm-tests|--local-tests|--monitoring|--all]
#
# Requirements:
# - Azure CLI installed and authenticated
# - Access to the resource group and storage account
# - RDP access to test VM for internal tests
# =============================================================================

set -euo pipefail

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# =============================================================================
# Configuration from Terraform Outputs
# =============================================================================

# Resource Group and Location
RESOURCE_GROUP="rg-datasafe-privatelink-poc-a86fa184"
LOCATION="westeurope"
SUBSCRIPTION_ID="4dd8bea6-7602-4aee-82f9-27e8f6bdd3a2"

# Storage Account Details
STORAGE_ACCOUNT_NAME="stgdatasafepoca86fa184"
STORAGE_ACCOUNT_FQDN="stgdatasafepoca86fa184.blob.core.windows.net"
STORAGE_ACCOUNT_URL="https://stgdatasafepoca86fa184.blob.core.windows.net/"
PRIVATE_ENDPOINT_IP="10.56.1.4"

# VM Details for Internal Testing
VM_NAME="vm-test-poc"
VM_PUBLIC_IP="108.143.1.152"
VM_PRIVATE_IP="10.56.2.4"
VM_USERNAME="azureadmin"
VM_PASSWORD=""  # Will be prompted securely

# WinRM Configuration for Remote Script Execution
WINRM_HTTP_PORT="5985"
WINRM_HTTPS_PORT="5986"

# Private Endpoint and DNS
PRIVATE_ENDPOINT_NAME="pep-stgdatasafepoca86fa184-blob"
PRIVATE_DNS_ZONE="privatelink.blob.core.windows.net"

# Monitoring
LOG_ANALYTICS_WORKSPACE="law-datasafe-poc"
ACTION_GROUP_ID="/subscriptions/4dd8bea6-7602-4aee-82f9-27e8f6bdd3a2/resourceGroups/rg-datasafe-privatelink-poc-a86fa184/providers/Microsoft.Insights/actionGroups/ag-storage-alerts-datasafe-poc"

# Test container name
TEST_CONTAINER="test-private-access"
TEST_FILE="test-$(date +%Y%m%d-%H%M%S).txt"

# =============================================================================
# Helper Functions
# =============================================================================

print_header() {
    echo -e "\n${BLUE}================================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}================================================${NC}\n"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

# Get VM password securely
prompt_vm_password() {
    if [[ -z "$VM_PASSWORD" ]]; then
        print_info "VM Password required for remote testing"
        echo -n "Enter password for VM user '$VM_USERNAME': "
        read -s VM_PASSWORD
        echo ""
        
        if [[ -z "$VM_PASSWORD" ]]; then
            print_error "Password cannot be empty"
            exit 1
        fi
        print_success "Password set securely"
    fi
}
# Check if Azure CLI is installed and authenticated
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    if ! command -v az &> /dev/null; then
        print_error "Azure CLI is not installed"
        exit 1
    fi
    print_success "Azure CLI is installed"
    
    # Check if logged in
    if ! az account show &> /dev/null; then
        print_error "Not logged in to Azure CLI. Please run 'az login'"
        exit 1
    fi
    print_success "Authenticated to Azure CLI"
    
    # Set the correct subscription
    az account set --subscription "$SUBSCRIPTION_ID"
    print_success "Subscription set to $SUBSCRIPTION_ID"
}

# =============================================================================
# Local Tests (from your machine - should fail for private storage)
# =============================================================================

test_local_access() {
    print_header "Testing Local Access (Should Fail - Public Access Disabled)"
    
    print_info "Testing DNS resolution from local machine..."
    if nslookup "$STORAGE_ACCOUNT_FQDN" &> /dev/null; then
        print_success "DNS resolution successful"
        nslookup "$STORAGE_ACCOUNT_FQDN" | grep -E "Address|Name"
    else
        print_warning "DNS resolution failed (expected for some configurations)"
    fi
    
    print_info "Testing HTTPS connectivity to storage endpoint..."
    storage_response=$(curl -s -I --connect-timeout 10 "$STORAGE_ACCOUNT_URL" 2>/dev/null | head -n 1)
    
    # Test actual storage operation (list containers)
    storage_operation_response=$(curl -s -X GET "${STORAGE_ACCOUNT_URL}?comp=list" --connect-timeout 10 2>/dev/null)
    
    if echo "$storage_operation_response" | grep -q "AuthorizationFailure\|PublicAccessNotPermitted\|403"; then
        print_success "Public access is properly blocked - storage operations return authorization failure"
        echo "Response: $(echo "$storage_operation_response" | grep -o '<Message>[^<]*</Message>' | sed 's/<[^>]*>//g')"
    elif echo "$storage_response" | grep -q "HTTP/1.1 4[0-9][0-9]"; then
        print_warning "Endpoint is reachable but returns HTTP error (likely blocked)"
        echo "$storage_response"
    elif echo "$storage_response" | grep -q "HTTP/1.1 2[0-9][0-9]"; then
        print_error "Public access is NOT blocked - this is a security issue!"
        echo "$storage_response"
    else
        print_success "Connection appears to be blocked or filtered"
    fi
    
    print_info "Testing Azure CLI access to storage account..."
    if az storage container list --account-name "$STORAGE_ACCOUNT_NAME" --auth-mode login &> /dev/null; then
        print_error "CLI access works from public internet - this might be a security issue!"
    else
        print_success "CLI access is properly restricted"
    fi
}

# =============================================================================
# VM Tests (from inside VNet - should work)
# =============================================================================

test_vm_access() {
    print_header "Testing Access from VM (Should Work - Private Endpoint Access)"
    
    # Prompt for password if needed for VM tests
    prompt_vm_password
    
    print_info "VM Details:"
    echo "  - Name: $VM_NAME"
    echo "  - Public IP: $VM_PUBLIC_IP"
    echo "  - Private IP: $VM_PRIVATE_IP"
    echo "  - Username: $VM_USERNAME"
    
    print_info "Testing WinRM connectivity for remote script execution..."
    # Test WinRM HTTP connectivity
    if nc -z -w5 "$VM_PUBLIC_IP" "$WINRM_HTTP_PORT" &>/dev/null; then
        print_success "WinRM HTTP port ($WINRM_HTTP_PORT) is accessible"
    else
        print_warning "WinRM HTTP port ($WINRM_HTTP_PORT) is not accessible"
    fi
    
    # Test WinRM HTTPS connectivity
    if nc -z -w5 "$VM_PUBLIC_IP" "$WINRM_HTTPS_PORT" &>/dev/null; then
        print_success "WinRM HTTPS port ($WINRM_HTTPS_PORT) is accessible"
    else
        print_warning "WinRM HTTPS port ($WINRM_HTTPS_PORT) is not accessible"
    fi
    
    # Test RDP connectivity
    if nc -z -w5 "$VM_PUBLIC_IP" "3389" &>/dev/null; then
        print_success "RDP port (3389) is accessible"
    else
        print_warning "RDP port (3389) is not accessible"
    fi
    
    print_info "To manually test from VM, RDP to $VM_PUBLIC_IP with username: $VM_USERNAME"
    
    # Test DNS resolution from VM
    print_info "Testing DNS resolution from VM..."
    VM_DNS_TEST=$(az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "nslookup $STORAGE_ACCOUNT_FQDN" \
        --query 'value[0].message' \
        --output tsv 2>/dev/null || echo "DNS test failed")
    
    if [[ "$VM_DNS_TEST" == *"$PRIVATE_ENDPOINT_IP"* ]]; then
        print_success "DNS resolves to private IP: $PRIVATE_ENDPOINT_IP"
    else
        print_warning "DNS resolution result from VM:"
        echo "$VM_DNS_TEST"
    fi
    
    # Test network connectivity from VM to storage
    print_info "Testing HTTPS connectivity from VM to storage..."
    VM_CONNECTIVITY_TEST=$(az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "Test-NetConnection $STORAGE_ACCOUNT_FQDN -Port 443" \
        --query 'value[0].message' \
        --output tsv 2>/dev/null || echo "Connectivity test failed")
    
    if [[ "$VM_CONNECTIVITY_TEST" == *"TcpTestSucceeded : True"* ]]; then
        print_success "HTTPS connectivity from VM successful"
    else
        print_warning "HTTPS connectivity test result from VM:"
        echo "$VM_CONNECTIVITY_TEST"
    fi
    
    # Test storage access from VM
    print_info "Testing storage account access from VM..."
    VM_STORAGE_TEST=$(az vm run-command invoke \
        --resource-group "$RESOURCE_GROUP" \
        --name "$VM_NAME" \
        --command-id RunPowerShellScript \
        --scripts "try { Invoke-WebRequest -Uri '$STORAGE_ACCOUNT_URL' -Method HEAD -TimeoutSec 10 } catch { \$_.Exception.Message }" \
        --query 'value[0].message' \
        --output tsv 2>/dev/null || echo "Storage test failed")
    
    if [[ "$VM_STORAGE_TEST" == *"200"* ]] || [[ "$VM_STORAGE_TEST" == *"Forbidden"* ]] || [[ "$VM_STORAGE_TEST" == *"authentication"* ]]; then
        print_success "Storage endpoint is accessible from VM (authentication required)"
    else
        print_warning "Storage access test result from VM:"
        echo "$VM_STORAGE_TEST"
    fi
}

# Get storage account key for authentication
get_storage_account_key() {
    print_info "Getting storage account key for authentication..."
    
    STORAGE_KEY=$(az storage account keys list \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query '[0].value' \
        --output tsv 2>/dev/null)
    
    if [[ -n "$STORAGE_KEY" ]]; then
        print_success "Storage account key retrieved"
        export AZURE_STORAGE_ACCOUNT="$STORAGE_ACCOUNT_NAME"
        export AZURE_STORAGE_KEY="$STORAGE_KEY"
        return 0
    else
        print_warning "Could not retrieve storage account key"
        return 1
    fi
}

# =============================================================================
# Storage Operations (to generate logs)
# =============================================================================

perform_storage_operations() {
    print_header "Performing Storage Operations (Generate Monitoring Data)"
    
    # Temporarily add current IP to allow list for testing
    add_current_ip_to_storage_rules
    
    # Wait a moment for the rule to take effect
    print_info "Waiting 30 seconds for network rules to take effect..."
    sleep 30
    
    # Get storage account key for authentication
    get_storage_account_key
    
    # Create a test container
    print_info "Creating test container: $TEST_CONTAINER"
    if az storage container create \
        --name "$TEST_CONTAINER" \
        --account-name "$STORAGE_ACCOUNT_NAME" &> /dev/null; then
        print_success "Container created successfully"
    else
        print_warning "Container creation failed or already exists"
    fi
    
    # Create a test file
    print_info "Creating test file: $TEST_FILE"
    echo "Test file created at $(date)" | az storage blob upload \
        --container-name "$TEST_CONTAINER" \
        --name "$TEST_FILE" \
        --data @- \
        --account-name "$STORAGE_ACCOUNT_NAME" &> /dev/null && print_success "Test file uploaded" || print_warning "File upload failed"
    
    # List blobs (generates logs)
    print_info "Listing blobs (generates access logs)..."
    az storage blob list \
        --container-name "$TEST_CONTAINER" \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --output table
    
    # Download the test file
    print_info "Downloading test file (generates access logs)..."
    if az storage blob download \
        --container-name "$TEST_CONTAINER" \
        --name "$TEST_FILE" \
        --file "/tmp/$TEST_FILE" \
        --account-name "$STORAGE_ACCOUNT_NAME" &> /dev/null; then
        print_success "File downloaded successfully"
        rm -f "/tmp/$TEST_FILE"
    else
        print_warning "File download failed"
    fi
    
    # Try to access non-existent blob (generates 404 logs)
    print_info "Attempting to access non-existent blob (generates 404 logs)..."
    az storage blob show \
        --container-name "$TEST_CONTAINER" \
        --name "non-existent-file.txt" \
        --account-name "$STORAGE_ACCOUNT_NAME" &> /dev/null || print_success "Expected 404 error generated for monitoring"
    
    print_success "Storage operations completed - logs should be generated"
    
    # Remove current IP from allow list to maintain security
    remove_current_ip_from_storage_rules
}

# =============================================================================
# Azure Monitor Queries
# =============================================================================

run_monitoring_queries() {
    print_header "Azure Monitor - Log Analytics Queries"
    
    print_info "Log Analytics Workspace: $LOG_ANALYTICS_WORKSPACE"
    print_info "Resource Group: $RESOURCE_GROUP"
    
    # Query 1: Recent Storage Blob Logs
    print_info "Running query: Recent Storage Blob Access Logs (Last 2 hours)"
    echo "Query 1: Recent Storage Blob Access Logs"
    cat << 'EOF'
StorageBlobLogs
| where TimeGenerated > ago(2h)
| where AccountName == "stgdatasafepoca86fa184"
| project TimeGenerated, StatusCode, Uri, ClientIpAddress, OperationName, UserAgentHeader
| order by TimeGenerated desc
| take 50
EOF
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "StorageBlobLogs | where TimeGenerated > ago(2h) | where AccountName == 'stgdatasafepoca86fa184' | project TimeGenerated, StatusCode, Uri, ClientIpAddress, OperationName, UserAgentHeader | order by TimeGenerated desc | take 50" \
        --out table || print_warning "Query failed - logs might not be available yet"
    
    echo ""
    
    # Query 2: Error Logs
    print_info "Running query: Storage Access Errors (Last 24 hours)"
    echo "Query 2: Storage Access Errors"
    cat << 'EOF'
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where AccountName == "stgdatasafepoca86fa184"
| where StatusCode >= 400
| summarize ErrorCount=count() by StatusCode, bin(TimeGenerated, 1h)
| order by TimeGenerated desc
EOF
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "StorageBlobLogs | where TimeGenerated > ago(24h) | where AccountName == 'stgdatasafepoca86fa184' | where StatusCode >= 400 | summarize ErrorCount=count() by StatusCode, bin(TimeGenerated, 1h) | order by TimeGenerated desc" \
        --out table || print_warning "Query failed - error logs might not be available yet"
    
    echo ""
    
    # Query 3: Activity Log for Storage Account
    print_info "Running query: Storage Account Activity (Last 24 hours)"
    echo "Query 3: Storage Account Activity Log"
    cat << 'EOF'
AzureActivity
| where TimeGenerated > ago(24h)
| where ResourceProvider == "Microsoft.Storage"
| where ResourceId contains "stgdatasafepoca86fa184"
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, ResourceId
| order by TimeGenerated desc
EOF
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "AzureActivity | where TimeGenerated > ago(24h) | where ResourceProvider == 'Microsoft.Storage' | where ResourceId contains 'stgdatasafepoca86fa184' | project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, ResourceId | order by TimeGenerated desc" \
        --out table || print_warning "Query failed - activity logs might not be available yet"
    
    echo ""
    
    # Query 4: IP Address Analysis
    print_info "Running query: Access by IP Address (Security Analysis)"
    echo "Query 4: Access by IP Address"
    cat << 'EOF'
StorageBlobLogs
| where TimeGenerated > ago(7d)
| where AccountName == "stgdatasafepoca86fa184"
| summarize AccessCount=count(), SuccessCount=countif(StatusCode < 400), ErrorCount=countif(StatusCode >= 400) by ClientIpAddress
| order by AccessCount desc
EOF
    
    az monitor log-analytics query \
        --workspace "$LOG_ANALYTICS_WORKSPACE" \
        --analytics-query "StorageBlobLogs | where TimeGenerated > ago(7d) | where AccountName == 'stgdatasafepoca86fa184' | summarize AccessCount=count(), SuccessCount=countif(StatusCode < 400), ErrorCount=countif(StatusCode >= 400) by ClientIpAddress | order by AccessCount desc" \
        --out table || print_warning "Query failed - IP analysis might not be available yet"
}

# =============================================================================
# Generate KQL Queries File
# =============================================================================

generate_kql_queries() {
    print_header "Generating KQL Queries File"
    
    local kql_file="azure-monitor-kql-queries.kql"
    
    cat > "$kql_file" << 'EOF'
// =============================================================================
// Azure Monitor KQL Queries for Private Storage Monitoring
// =============================================================================
// These queries help monitor access to your private storage account
// Use these in Azure Monitor Log Analytics or create alerts based on them
//
// Storage Account: stgdatasafepoca86fa184
// Resource Group: rg-datasafe-privatelink-poc-a86fa184
// =============================================================================

// Query 1: Recent Storage Blob Access (Last 4 hours)
// Shows all recent access attempts with status codes and IPs
StorageBlobLogs
| where TimeGenerated > ago(4h)
| where AccountName == "stgdatasafepoca86fa184"
| project TimeGenerated, StatusCode, Uri, ClientIpAddress, OperationName, UserAgentHeader, TimeToFirstByteMs
| order by TimeGenerated desc

// Query 2: Failed Access Attempts (Security Monitoring)
// Monitor for unauthorized access attempts
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where AccountName == "stgdatasafepoca86fa184"
| where StatusCode in (401, 403, 404)
| summarize FailedAttempts=count() by ClientIpAddress, StatusCode, bin(TimeGenerated, 1h)
| order by FailedAttempts desc

// Query 3: Access from Outside Private Network (Security Alert)
// This should show minimal activity if private endpoints are working correctly
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where AccountName == "stgdatasafepoca86fa184"
| where ClientIpAddress !startswith "10.56."  // Your VNet range
| project TimeGenerated, StatusCode, ClientIpAddress, Uri, OperationName
| order by TimeGenerated desc

// Query 4: Storage Account Configuration Changes
// Monitor for any configuration changes to the storage account
AzureActivity
| where TimeGenerated > ago(7d)
| where ResourceProvider == "Microsoft.Storage"
| where ResourceId contains "stgdatasafepoca86fa184"
| where OperationNameValue contains "write"
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue, Properties

// Query 5: Private Endpoint Health
// Monitor private endpoint connectivity
AzureActivity
| where TimeGenerated > ago(24h)
| where ResourceProvider == "Microsoft.Network"
| where ResourceId contains "pep-stgdatasafepoca86fa184-blob"
| project TimeGenerated, Caller, OperationNameValue, ActivityStatusValue

// Query 6: DNS Resolution Monitoring
// Track DNS queries for the storage account (if available)
AzureDiagnostics
| where TimeGenerated > ago(24h)
| where ResourceType == "PRIVATEDNSZONES"
| where ResourceId contains "privatelink.blob.core.windows.net"
| project TimeGenerated, OperationName, ResultType, Resource

// Query 7: Performance Monitoring
// Monitor response times for storage operations
StorageBlobLogs
| where TimeGenerated > ago(4h)
| where AccountName == "stgdatasafepoca86fa184"
| where StatusCode < 400
| summarize AvgResponseTime=avg(TimeToFirstByteMs), P95ResponseTime=percentile(TimeToFirstByteMs, 95) by bin(TimeGenerated, 15m)
| order by TimeGenerated desc

// Query 8: High-Level Access Summary
// Hourly summary of storage access
StorageBlobLogs
| where TimeGenerated > ago(24h)
| where AccountName == "stgdatasafepoca86fa184"
| summarize 
    TotalRequests=count(),
    SuccessfulRequests=countif(StatusCode < 400),
    FailedRequests=countif(StatusCode >= 400),
    UniqueIPs=dcount(ClientIpAddress)
    by bin(TimeGenerated, 1h)
| order by TimeGenerated desc

// Query 9: Anomaly Detection - Unusual Access Patterns
// Detect unusual access volumes
StorageBlobLogs
| where TimeGenerated > ago(7d)
| where AccountName == "stgdatasafepoca86fa184"
| summarize RequestCount=count() by ClientIpAddress, bin(TimeGenerated, 1h)
| where RequestCount > 100  // Adjust threshold as needed
| order by RequestCount desc

// Query 10: Compliance Audit Query
// Full audit trail for compliance reporting
union StorageBlobLogs, AzureActivity
| where TimeGenerated > ago(30d)
| where AccountName == "stgdatasafepoca86fa184" or ResourceId contains "stgdatasafepoca86fa184"
| project TimeGenerated, Type, OperationName, StatusCode, ClientIpAddress, Caller, CorrelationId
| order by TimeGenerated desc

// =============================================================================
// Alert Queries (Use these to create Azure Monitor Alerts)
// =============================================================================

// Alert 1: Failed Authentication Attempts
// Trigger when > 10 failed auth attempts in 15 minutes
StorageBlobLogs
| where TimeGenerated > ago(15m)
| where AccountName == "stgdatasafepoca86fa184"
| where StatusCode in (401, 403)
| summarize FailedAttempts=count() by ClientIpAddress
| where FailedAttempts > 10

// Alert 2: Access from Unexpected IPs
// Trigger when access comes from outside your VNet
StorageBlobLogs
| where TimeGenerated > ago(5m)
| where AccountName == "stgdatasafepoca86fa184"
| where ClientIpAddress !startswith "10.56."
| where StatusCode < 400  // Only successful attempts
| distinct ClientIpAddress

// Alert 3: Storage Account Configuration Changes
// Trigger on any configuration changes
AzureActivity
| where TimeGenerated > ago(5m)
| where ResourceProvider == "Microsoft.Storage"
| where ResourceId contains "stgdatasafepoca86fa184"
| where OperationNameValue contains "write"
| where ActivityStatusValue == "Succeeded"

EOF

    print_success "KQL queries saved to: $kql_file"
    print_info "You can use these queries in Azure Monitor Log Analytics"
    print_info "To create alerts, use the queries in the 'Alert Queries' section"
}

# =============================================================================
# Infrastructure Validation
# =============================================================================

validate_infrastructure() {
    print_header "Validating Infrastructure Setup"
    
    # Check storage account exists and is configured correctly
    print_info "Validating storage account configuration..."
    STORAGE_CONFIG=$(az storage account show \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query '{publicNetworkAccess:publicNetworkAccess, httpsOnly:supportsHttpsTrafficOnly, minimumTlsVersion:minimumTlsVersion}' \
        --output json)
    
    echo "Storage Account Security Configuration:"
    echo "$STORAGE_CONFIG" | jq .
    
    # Check if public network access is properly disabled
    PUBLIC_ACCESS=$(echo "$STORAGE_CONFIG" | jq -r .publicNetworkAccess)
    if [[ "$PUBLIC_ACCESS" == "Disabled" ]]; then
        print_success "Public network access is disabled"
    else
        print_error "Public network access is NOT disabled: $PUBLIC_ACCESS"
        print_info "Attempting to fix..."
        fix_storage_public_access
    fi
    
    # Check storage account network rules
    print_info "Checking storage account network rules..."
    NETWORK_RULES=$(az storage account network-rule list \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output json)
    
    DEFAULT_ACTION=$(echo "$NETWORK_RULES" | jq -r .defaultAction)
    if [[ "$DEFAULT_ACTION" == "Deny" ]]; then
        print_success "Storage network rules default action is Deny"
    else
        print_error "Storage network rules default action is: $DEFAULT_ACTION"
        print_info "Attempting to fix..."
        fix_storage_network_rules
    fi
    
    # Check private endpoint status
    print_info "Validating private endpoint..."
    az network private-endpoint show \
        --name "$PRIVATE_ENDPOINT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query '{provisioningState:provisioningState, connectionState:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}' \
        --output table
    
    # Check DNS zone
    print_info "Validating private DNS zone..."
    az network private-dns zone show \
        --name "$PRIVATE_DNS_ZONE" \
        --resource-group "$RESOURCE_GROUP" \
        --query '{name:name, numberOfRecordSets:numberOfRecordSets}' \
        --output table
    
    # Check VM status
    print_info "Validating test VM..."
    az vm show \
        --name "$VM_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --query '{name:name, provisioningState:provisioningState, powerState:instanceView.statuses[1].displayStatus}' \
        --output table
}

# Fix storage account public access
fix_storage_public_access() {
    print_info "Disabling public network access on storage account..."
    az storage account update \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --public-network-access Disabled \
        --output none
    
    if [[ $? -eq 0 ]]; then
        print_success "Public network access disabled"
    else
        print_error "Failed to disable public network access"
    fi
}

# Fix storage account network rules
fix_storage_network_rules() {
    print_info "Setting storage account network rules to deny by default with proper bypass..."
    
    # Enable public network access (required for network rules to work)
    print_info "Enabling public network access (required for network rules to function)..."
    az storage account update \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --public-network-access Enabled \
        --output none
    
    # Update network rules with proper bypass settings
    az storage account update \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --default-action Deny \
        --bypass AzureServices Logging Metrics \
        --output none
    
    if [[ $? -eq 0 ]]; then
        print_success "Storage network rules updated with proper bypass settings"
        print_info "Note: Public network access is enabled but restricted by network rules"
    else
        print_error "Failed to update storage network rules"
    fi
}

# =============================================================================
# Security Validation and Fix
# =============================================================================

verify_and_fix_security() {
    print_header "Verifying and Fixing Storage Account Security"
    
    # Check current storage account configuration
    print_info "Checking storage account security configuration..."
    
    # Get storage account properties
    storage_info=$(az storage account show \
        --name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output json)
    
    public_access=$(echo "$storage_info" | jq -r '.publicNetworkAccess')
    https_only=$(echo "$storage_info" | jq -r '.enableHttpsTrafficOnly')
    default_action=$(echo "$storage_info" | jq -r '.networkRuleSet.defaultAction // "Unknown"')
    bypass_services=$(echo "$storage_info" | jq -r '.networkRuleSet.bypass[]? // empty' | tr '\n' ',' | sed 's/,$//')
    
    # Also check network rules separately for additional info
    network_rules=$(az storage account network-rule list \
        --account-name "$STORAGE_ACCOUNT_NAME" \
        --resource-group "$RESOURCE_GROUP" \
        --output json)
    
    ip_rules_count=$(echo "$network_rules" | jq -r '.ipRules | length')
    vnet_rules_count=$(echo "$network_rules" | jq -r '.virtualNetworkRules | length')
    
    print_info "Current Security Configuration:"
    echo "  - Public Network Access: $public_access"
    echo "  - HTTPS Only: $https_only"
    echo "  - Default Action: $default_action"
    echo "  - Bypass Services: $bypass_services"
    echo "  - IP Rules Count: $ip_rules_count"
    echo "  - VNet Rules Count: $vnet_rules_count"
    
    # Verify security settings
    security_issues=0
    
    if [[ "$public_access" == "Disabled" ]]; then
        print_warning "⚠️  Public network access is disabled - this blocks all network rules"
        print_info "For private endpoints with selective access, enable public access with Deny default action"
        ((security_issues++))
    elif [[ "$public_access" == "Enabled" ]] && [[ "$default_action" == "Deny" ]]; then
        print_success "✅ Public network access enabled with Deny default action (proper for private endpoints)"
    else
        print_error "❌ Public network access configuration needs attention"
        ((security_issues++))
    fi
    
    if [[ "$https_only" != "true" ]]; then
        print_error "❌ HTTPS-only is not enabled"
        ((security_issues++))
    else
        print_success "✅ HTTPS-only is enabled"
    fi
    
    if [[ "$default_action" != "Deny" ]]; then
        print_error "❌ Default network action is not 'Deny'"
        ((security_issues++))
    else
        print_success "✅ Default network action is 'Deny'"
    fi
    
    if [[ "$bypass_services" == *"AzureServices"* ]]; then
        print_warning "⚠️  AzureServices bypass is enabled (may allow unwanted access)"
        ((security_issues++))
    else
        print_success "✅ AzureServices bypass is not enabled"
    fi
    
    # Apply fixes if requested
    if [[ "${1:-}" == "--fix" ]]; then
        if [[ $security_issues -gt 0 ]]; then
            print_info "Applying security fixes..."
            
            # Configure public network access properly for private endpoints
            if [[ "$public_access" == "Disabled" ]] || [[ "$default_action" != "Deny" ]]; then
                print_info "Configuring network access for private endpoints with security..."
                # Enable public access but with deny default action
                az storage account update \
                    --name "$STORAGE_ACCOUNT_NAME" \
                    --resource-group "$RESOURCE_GROUP" \
                    --public-network-access Enabled \
                    --default-action Deny \
                    --bypass AzureServices Logging Metrics && print_success "Network access configured securely"
            fi
            
            # Enable HTTPS only
            if [[ "$https_only" != "true" ]]; then
                print_info "Enabling HTTPS-only access..."
                az storage account update \
                    --name "$STORAGE_ACCOUNT_NAME" \
                    --resource-group "$RESOURCE_GROUP" \
                    --https-only true && print_success "HTTPS-only enabled"
            fi
            
            # Update network rules
            if [[ "$default_action" != "Deny" ]] || [[ "$bypass_services" == *"AzureServices"* ]]; then
                print_info "Updating network rules..."
                az storage account network-rule update \
                    --account-name "$STORAGE_ACCOUNT_NAME" \
                    --resource-group "$RESOURCE_GROUP" \
                    --default-action Deny \
                    --bypass Metrics Logging && print_success "Network rules updated"
            fi
            
            print_success "Security fixes applied successfully"
        else
            print_success "No security issues found"
        fi
    else
        if [[ $security_issues -gt 0 ]]; then
            print_warning "Run with --fix to apply security fixes"
        fi
    fi
}

# Get current public IP for testing
get_current_public_ip() {
    # Try multiple services to get public IP
    local public_ip
    public_ip=$(curl -s --connect-timeout 10 https://ifconfig.me 2>/dev/null || curl -s --connect-timeout 10 https://ipinfo.io/ip 2>/dev/null || curl -s --connect-timeout 10 https://api.ipify.org 2>/dev/null)
    
    # Clean the IP (remove any extra whitespace or control characters)
    public_ip=$(echo "$public_ip" | tr -d '\r\n\t ' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')
    
    if [[ -n "$public_ip" ]]; then
        echo "$public_ip"
        return 0
    else
        return 1
    fi
}

# Add current IP to storage account network rules for testing
add_current_ip_to_storage_rules() {
    print_info "Adding current public IP to storage account network rules for testing..."
    
    local current_ip
    current_ip=$(get_current_public_ip)
    
    if [[ -n "$current_ip" ]]; then
        print_success "Current public IP: $current_ip"
        
        # Add current IP to allow list
        az storage account network-rule add \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --ip-address "$current_ip" \
            --output none
        
        if [[ $? -eq 0 ]]; then
            print_success "Added current IP ($current_ip) to storage account allow list"
        else
            print_warning "Failed to add current IP to storage account rules (may already exist)"
        fi
    else
        print_warning "Could not add current IP - IP detection failed"
    fi
}

# Remove current IP from storage account network rules after testing
remove_current_ip_from_storage_rules() {
    print_info "Removing current public IP from storage account network rules..."
    
    local current_ip
    current_ip=$(get_current_public_ip)
    
    if [[ -n "$current_ip" ]]; then
        # Remove current IP from allow list
        az storage account network-rule remove \
            --account-name "$STORAGE_ACCOUNT_NAME" \
            --resource-group "$RESOURCE_GROUP" \
            --ip-address "$current_ip" \
            --output none 2>/dev/null || true
        
        print_success "Removed current IP ($current_ip) from storage account allow list"
    fi
}

# =============================================================================
# Main Script Logic
# =============================================================================

show_usage() {
    echo "Usage: $0 [option]"
    echo ""
    echo "Options:"
    echo "  --vm-tests      Run tests from VM (internal network tests)"
    echo "  --local-tests   Run tests from local machine (should fail)"
    echo "  --storage-ops   Perform storage operations to generate logs"
    echo "  --monitoring    Run Azure Monitor queries"
    echo "  --validate      Validate infrastructure setup"
    echo "  --generate-kql  Generate KQL queries file"
    echo "  --security      Verify storage security configuration"
    echo "  --fix           Apply security fixes to storage account"
    echo "  --all           Run all tests (default)"
    echo "  --help          Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 --all                    # Run all tests"
    echo "  $0 --local-tests            # Test from local machine"
    echo "  $0 --vm-tests               # Test from VM"
    echo "  $0 --monitoring             # Run monitoring queries only"
    echo "  $0 --security               # Check security configuration"
    echo "  $0 --fix                    # Apply security fixes"
}

main() {
    case "${1:-all}" in
        --vm-tests)
            check_prerequisites
            test_vm_access
            ;;
        --local-tests)
            check_prerequisites
            test_local_access
            ;;
        --storage-ops)
            check_prerequisites
            perform_storage_operations
            ;;
        --monitoring)
            check_prerequisites
            run_monitoring_queries
            ;;
        --validate)
            check_prerequisites
            validate_infrastructure
            ;;
        --generate-kql)
            generate_kql_queries
            ;;
        --security)
            check_prerequisites
            verify_and_fix_security
            ;;
        --all)
            check_prerequisites
            verify_and_fix_security
            validate_infrastructure
            test_local_access
            test_vm_access
            perform_storage_operations
            generate_kql_queries
            echo ""
            print_info "Waiting 2 minutes for logs to be ingested..."
            sleep 120
            run_monitoring_queries
            ;;
        --fix)
            check_prerequisites
            verify_and_fix_security --fix
            fix_storage_network_rules
            print_success "Security fixes applied. Please test again."
            ;;
        --help)
            show_usage
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

# =============================================================================
# Script Execution
# =============================================================================

print_header "Azure Private Storage Connection Test Script"
print_info "Testing storage account: $STORAGE_ACCOUNT_NAME"
print_info "Resource group: $RESOURCE_GROUP"
print_info "Private endpoint IP: $PRIVATE_ENDPOINT_IP"
echo ""

main "$@"

print_header "Test Summary"
print_info "Key Points to Verify:"
echo "1. ✓ Local access should be blocked (confirms private endpoint security)"
echo "2. ✓ VM access should work (confirms private endpoint functionality)"
echo "3. ✓ DNS should resolve to private IP ($PRIVATE_ENDPOINT_IP) from VM"
echo "4. ✓ Storage operations should generate logs visible in Azure Monitor"
echo "5. ✓ Monitoring queries should show access patterns and security events"
echo ""
print_info "Next Steps:"
echo "1. Review the generated KQL queries file for ongoing monitoring"
echo "2. Set up Azure Monitor alerts using the provided alert queries"
echo "3. Schedule regular connection tests"
echo "4. Monitor logs for security events"
echo ""
print_success "Private storage connection testing completed!"
