#!/bin/bash

# =============================================================================
# AZURE PRIVATE STORAGE INFRASTRUCTURE - VALIDATION SCRIPT
# =============================================================================
# This script helps validate that the private endpoint infrastructure is 
# working correctly after deployment.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

print_header() {
    echo -e "\n${BLUE}==============================================================================${NC}"
    echo -e "${BLUE} $1${NC}"
    echo -e "${BLUE}==============================================================================${NC}\n"
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
print_header "CHECKING PREREQUISITES"

if ! command_exists terraform; then
    print_status $RED "❌ Terraform is not installed or not in PATH"
    exit 1
else
    print_status $GREEN "✅ Terraform found: $(terraform version --json | jq -r '.terraform_version')"
fi

if ! command_exists az; then
    print_status $RED "❌ Azure CLI is not installed or not in PATH"
    exit 1
else
    print_status $GREEN "✅ Azure CLI found: $(az version --query '\"azure-cli\"' -o tsv)"
fi

# Check Azure login
print_header "CHECKING AZURE AUTHENTICATION"

if ! az account show >/dev/null 2>&1; then
    print_status $RED "❌ Not logged into Azure"
    print_status $YELLOW "Run: az login"
    exit 1
else
    SUBSCRIPTION_NAME=$(az account show --query 'name' -o tsv)
    SUBSCRIPTION_ID=$(az account show --query 'id' -o tsv)
    print_status $GREEN "✅ Logged into Azure"
    print_status $BLUE "   Subscription: $SUBSCRIPTION_NAME ($SUBSCRIPTION_ID)"
fi

# Check if terraform is initialized
print_header "CHECKING TERRAFORM STATE"

if [ ! -d ".terraform" ]; then
    print_status $YELLOW "⚠️ Terraform not initialized. Running terraform init..."
    terraform init
fi

# Get terraform outputs
print_header "RETRIEVING INFRASTRUCTURE INFORMATION"

if ! terraform output >/dev/null 2>&1; then
    print_status $RED "❌ No terraform state found. Please run 'terraform apply' first."
    exit 1
fi

# Extract key information
RESOURCE_GROUP=$(terraform output -raw resource_group_name 2>/dev/null || echo "")
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name 2>/dev/null || echo "")
VM_PUBLIC_IP=$(terraform output -raw vm_public_ip 2>/dev/null || echo "")
VM_PRIVATE_IP=$(terraform output -raw vm_private_ip 2>/dev/null || echo "")
PRIVATE_ENDPOINT_IP=$(terraform output -raw storage_account_private_endpoint_ip 2>/dev/null || echo "")

if [ -z "$RESOURCE_GROUP" ] || [ -z "$STORAGE_ACCOUNT" ]; then
    print_status $RED "❌ Unable to retrieve infrastructure information from terraform"
    exit 1
fi

print_status $GREEN "✅ Infrastructure information retrieved:"
print_status $BLUE "   Resource Group: $RESOURCE_GROUP"
print_status $BLUE "   Storage Account: $STORAGE_ACCOUNT"
print_status $BLUE "   VM Public IP: ${VM_PUBLIC_IP:-"Not assigned"}"
print_status $BLUE "   VM Private IP: ${VM_PRIVATE_IP:-"Unknown"}"
print_status $BLUE "   Private Endpoint IP: ${PRIVATE_ENDPOINT_IP:-"Unknown"}"

# Test 1: Check resource group exists
print_header "TEST 1: RESOURCE GROUP VALIDATION"

if az group show --name "$RESOURCE_GROUP" >/dev/null 2>&1; then
    print_status $GREEN "✅ Resource group '$RESOURCE_GROUP' exists"
else
    print_status $RED "❌ Resource group '$RESOURCE_GROUP' not found"
    exit 1
fi

# Test 2: Check storage account exists and is private
print_header "TEST 2: STORAGE ACCOUNT VALIDATION"

STORAGE_INFO=$(az storage account show --name "$STORAGE_ACCOUNT" --resource-group "$RESOURCE_GROUP" --query '{publicAccess:publicNetworkAccess,httpsOnly:supportsHttpsTrafficOnly}' -o json 2>/dev/null || echo "{}")

if [ "$STORAGE_INFO" = "{}" ]; then
    print_status $RED "❌ Storage account '$STORAGE_ACCOUNT' not found"
    exit 1
fi

PUBLIC_ACCESS=$(echo "$STORAGE_INFO" | jq -r '.publicAccess // "Unknown"')
HTTPS_ONLY=$(echo "$STORAGE_INFO" | jq -r '.httpsOnly // false')

print_status $GREEN "✅ Storage account '$STORAGE_ACCOUNT' exists"

if [ "$PUBLIC_ACCESS" = "Disabled" ]; then
    print_status $GREEN "✅ Public network access is disabled"
else
    print_status $RED "❌ Public network access is enabled (should be disabled)"
fi

if [ "$HTTPS_ONLY" = "true" ]; then
    print_status $GREEN "✅ HTTPS-only traffic is enforced"
else
    print_status $YELLOW "⚠️ HTTPS-only traffic is not enforced"
fi

# Test 3: Check private endpoint exists
print_header "TEST 3: PRIVATE ENDPOINT VALIDATION"

PRIVATE_ENDPOINTS=$(az network private-endpoint list --resource-group "$RESOURCE_GROUP" --query "[?contains(privateLinkServiceConnections[0].privateLinkServiceId, '$STORAGE_ACCOUNT')].{name:name,state:privateLinkServiceConnections[0].privateLinkServiceConnectionState.status}" -o json)

if [ "$(echo "$PRIVATE_ENDPOINTS" | jq '. | length')" -eq 0 ]; then
    print_status $RED "❌ No private endpoints found for storage account"
    exit 1
fi

ENDPOINT_COUNT=$(echo "$PRIVATE_ENDPOINTS" | jq '. | length')
print_status $GREEN "✅ Found $ENDPOINT_COUNT private endpoint(s) for storage account"

echo "$PRIVATE_ENDPOINTS" | jq -r '.[] | "   - \(.name): \(.state)"' | while read line; do
    if [[ "$line" == *"Approved"* ]]; then
        print_status $GREEN "✅ $line"
    else
        print_status $YELLOW "⚠️ $line"
    fi
done

# Test 4: Check private DNS zone
print_header "TEST 4: PRIVATE DNS ZONE VALIDATION"

DNS_ZONES=$(az network private-dns zone list --resource-group "$RESOURCE_GROUP" --query "[?contains(name, 'privatelink.blob.core.windows.net')].name" -o tsv)

if [ -z "$DNS_ZONES" ]; then
    print_status $RED "❌ Private DNS zone for blob storage not found"
else
    print_status $GREEN "✅ Private DNS zone found: $DNS_ZONES"
    
    # Check DNS records
    DNS_RECORDS=$(az network private-dns record-set a list --resource-group "$RESOURCE_GROUP" --zone-name "$DNS_ZONES" --query "[?contains(name, '$STORAGE_ACCOUNT')].{name:name,ip:aRecords[0].ipv4Address}" -o json)
    
    if [ "$(echo "$DNS_RECORDS" | jq '. | length')" -gt 0 ]; then
        print_status $GREEN "✅ DNS A record found for storage account"
        echo "$DNS_RECORDS" | jq -r '.[] | "   - \(.name): \(.ip)"' | while read line; do
            print_status $BLUE "   $line"
        done
    else
        print_status $YELLOW "⚠️ No DNS A record found for storage account (may still be propagating)"
    fi
fi

# Test 5: Check VM (if exists)
print_header "TEST 5: VIRTUAL MACHINE VALIDATION"

if [ -n "$VM_PRIVATE_IP" ] && [ "$VM_PRIVATE_IP" != "null" ]; then
    VM_INFO=$(az vm list --resource-group "$RESOURCE_GROUP" --query "[0].{name:name,state:powerState}" -o json 2>/dev/null || echo "{}")
    
    if [ "$VM_INFO" != "{}" ]; then
        VM_NAME=$(echo "$VM_INFO" | jq -r '.name // "Unknown"')
        VM_STATE=$(echo "$VM_INFO" | jq -r '.state // "Unknown"')
        
        print_status $GREEN "✅ Virtual machine '$VM_NAME' found"
        
        if [[ "$VM_STATE" == *"running"* ]]; then
            print_status $GREEN "✅ VM is running"
        else
            print_status $YELLOW "⚠️ VM state: $VM_STATE"
        fi
        
        if [ -n "$VM_PUBLIC_IP" ] && [ "$VM_PUBLIC_IP" != "null" ]; then
            print_status $BLUE "   Public IP: $VM_PUBLIC_IP"
            print_status $BLUE "   RDP Command: mstsc /v:$VM_PUBLIC_IP"
        fi
        
        print_status $BLUE "   Private IP: $VM_PRIVATE_IP"
    else
        print_status $YELLOW "⚠️ No virtual machine found in resource group"
    fi
else
    print_status $YELLOW "⚠️ No virtual machine configured"
fi

# Test 6: External access test (should fail)
print_header "TEST 6: EXTERNAL ACCESS VALIDATION"

print_status $BLUE "Testing external access to storage account (should fail)..."

EXTERNAL_TEST_RESULT=$(curl -s -w "%{http_code}" --max-time 10 "https://$STORAGE_ACCOUNT.blob.core.windows.net" -o /dev/null 2>/dev/null || echo "timeout")

if [ "$EXTERNAL_TEST_RESULT" = "timeout" ] || [ "$EXTERNAL_TEST_RESULT" = "403" ] || [ "$EXTERNAL_TEST_RESULT" = "000" ]; then
    print_status $GREEN "✅ External access properly blocked (HTTP: $EXTERNAL_TEST_RESULT)"
else
    print_status $RED "❌ External access not blocked (HTTP: $EXTERNAL_TEST_RESULT)"
fi

# Summary
print_header "VALIDATION SUMMARY"

print_status $GREEN "✅ Infrastructure validation completed!"
print_status $BLUE ""
print_status $BLUE "Next steps:"
print_status $BLUE "1. Connect to the VM via RDP (if configured)"
print_status $BLUE "2. Test DNS resolution from within the VM:"
print_status $BLUE "   nslookup $STORAGE_ACCOUNT.blob.core.windows.net"
print_status $BLUE "3. Test connectivity from within the VM:"
print_status $BLUE "   Test-NetConnection $STORAGE_ACCOUNT.blob.core.windows.net -Port 443"
print_status $BLUE "4. Install Azure PowerShell and test storage access"
print_status $BLUE ""
print_status $YELLOW "Remember: Storage is only accessible via private endpoint from within the VNet!"

print_header "VALIDATION COMPLETE"
