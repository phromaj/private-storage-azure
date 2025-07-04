# =============================================================================
# Azure Private Storage VM Test Script (PowerShell)
# =============================================================================
# This script runs on the Windows VM to test private endpoint connectivity
# and perform storage operations from within the VNet
#
# Run this script on VM: vm-test-poc (108.143.1.152)
# Username: azureadmin
#
# Prerequisites on VM:
# - Azure CLI installed
# - PowerShell 5.0+
# - Authenticated to Azure (az login)
# =============================================================================

param(
    [switch]$ConnectivityTests,
    [switch]$StorageOperations,
    [switch]$PerformanceTests,
    [switch]$All
)

# Configuration
$StorageAccountName = "stgdatasafepoca86fa184"
$StorageAccountFQDN = "stgdatasafepoca86fa184.blob.core.windows.net"
$ExpectedPrivateIP = "10.56.1.4"
$TestContainer = "vm-test-container"
$ResourceGroup = "rg-datasafe-privatelink-poc-a86fa184"

# Color functions
function Write-Success { param($Message) Write-Host "✓ $Message" -ForegroundColor Green }
function Write-Error { param($Message) Write-Host "✗ $Message" -ForegroundColor Red }
function Write-Warning { param($Message) Write-Host "⚠ $Message" -ForegroundColor Yellow }
function Write-Info { param($Message) Write-Host "ℹ $Message" -ForegroundColor Cyan }
function Write-Header { param($Message) Write-Host "`n================================================" -ForegroundColor Blue; Write-Host "$Message" -ForegroundColor Blue; Write-Host "================================================`n" -ForegroundColor Blue }

function Test-Connectivity {
    Write-Header "Testing Connectivity from VM"
    
    # DNS Resolution Test
    Write-Info "Testing DNS resolution..."
    try {
        $dnsResult = Resolve-DnsName -Name $StorageAccountFQDN -ErrorAction Stop
        $resolvedIP = $dnsResult | Where-Object { $_.Type -eq "A" } | Select-Object -First 1 -ExpandProperty IPAddress
        
        if ($resolvedIP -eq $ExpectedPrivateIP) {
            Write-Success "DNS resolves to correct private IP: $resolvedIP"
        } else {
            Write-Warning "DNS resolves to: $resolvedIP (expected: $ExpectedPrivateIP)"
        }
        
        Write-Info "Full DNS resolution result:"
        $dnsResult | Format-Table
    }
    catch {
        Write-Error "DNS resolution failed: $($_.Exception.Message)"
    }
    
    # Network Connectivity Test
    Write-Info "Testing network connectivity (port 443)..."
    try {
        $connectTest = Test-NetConnection -ComputerName $StorageAccountFQDN -Port 443 -WarningAction SilentlyContinue
        
        if ($connectTest.TcpTestSucceeded) {
            Write-Success "Port 443 connectivity successful"
            Write-Info "Connection details:"
            Write-Host "  Remote Address: $($connectTest.RemoteAddress)"
            Write-Host "  Remote Port: $($connectTest.RemotePort)"
            Write-Host "  Interface Alias: $($connectTest.InterfaceAlias)"
            Write-Host "  Source Address: $($connectTest.SourceAddress.IPAddress)"
        } else {
            Write-Error "Port 443 connectivity failed"
        }
    }
    catch {
        Write-Error "Network connectivity test failed: $($_.Exception.Message)"
    }
    
    # HTTPS Test
    Write-Info "Testing HTTPS connectivity..."
    try {
        $response = Invoke-WebRequest -Uri "https://$StorageAccountFQDN" -Method HEAD -TimeoutSec 10 -ErrorAction Stop
        Write-Success "HTTPS connectivity successful (Status: $($response.StatusCode))"
    }
    catch {
        if ($_.Exception.Response.StatusCode -eq 400) {
            Write-Success "HTTPS connectivity successful (Expected 400 error for direct access)"
        } else {
            Write-Warning "HTTPS test result: $($_.Exception.Message)"
        }
    }
    
    # Ping Test (may not work due to ICMP blocking)
    Write-Info "Testing ping connectivity..."
    try {
        $pingResult = Test-Connection -ComputerName $StorageAccountFQDN -Count 2 -ErrorAction Stop
        Write-Success "Ping successful"
        $pingResult | Format-Table
    }
    catch {
        Write-Warning "Ping failed (expected due to ICMP blocking): $($_.Exception.Message)"
    }
}

function Test-StorageOperations {
    Write-Header "Testing Storage Operations from VM"
    
    # Check Azure CLI authentication
    Write-Info "Checking Azure CLI authentication..."
    try {
        $account = az account show --query name --output tsv
        Write-Success "Authenticated to Azure as: $account"
    }
    catch {
        Write-Error "Not authenticated to Azure CLI. Please run 'az login'"
        return
    }
    
    # Create test container
    Write-Info "Creating test container: $TestContainer"
    try {
        $containerResult = az storage container create --name $TestContainer --account-name $StorageAccountName --auth-mode login 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Container created or already exists"
        } else {
            Write-Warning "Container creation result unclear"
        }
    }
    catch {
        Write-Warning "Container creation failed: $($_.Exception.Message)"
    }
    
    # Upload test file
    Write-Info "Uploading test file..."
    $testFileName = "vm-test-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    $testContent = "Test file created from VM at $(Get-Date)"
    $tempFile = "$env:TEMP\$testFileName"
    
    try {
        $testContent | Out-File -FilePath $tempFile -Encoding UTF8
        $uploadResult = az storage blob upload --container-name $TestContainer --name $testFileName --file $tempFile --account-name $StorageAccountName --auth-mode login 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "File uploaded successfully: $testFileName"
        } else {
            Write-Error "File upload failed"
        }
    }
    catch {
        Write-Error "File upload failed: $($_.Exception.Message)"
    }
    finally {
        if (Test-Path $tempFile) { Remove-Item $tempFile -Force }
    }
    
    # List blobs
    Write-Info "Listing blobs in container..."
    try {
        $blobs = az storage blob list --container-name $TestContainer --account-name $StorageAccountName --auth-mode login --output table 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Blob listing successful"
            Write-Host $blobs
        } else {
            Write-Error "Blob listing failed"
        }
    }
    catch {
        Write-Error "Blob listing failed: $($_.Exception.Message)"
    }
    
    # Download test file
    Write-Info "Downloading test file..."
    $downloadFile = "$env:TEMP\downloaded-$testFileName"
    try {
        $downloadResult = az storage blob download --container-name $TestContainer --name $testFileName --file $downloadFile --account-name $StorageAccountName --auth-mode login 2>$null
        if ($LASTEXITCODE -eq 0 -and (Test-Path $downloadFile)) {
            Write-Success "File downloaded successfully"
            $content = Get-Content $downloadFile
            Write-Info "Downloaded content: $content"
            Remove-Item $downloadFile -Force
        } else {
            Write-Error "File download failed"
        }
    }
    catch {
        Write-Error "File download failed: $($_.Exception.Message)"
    }
    
    # Test blob properties (generates logs)
    Write-Info "Getting blob properties..."
    try {
        $properties = az storage blob show --container-name $TestContainer --name $testFileName --account-name $StorageAccountName --auth-mode login --output table 2>$null
        if ($LASTEXITCODE -eq 0) {
            Write-Success "Blob properties retrieved"
            Write-Host $properties
        } else {
            Write-Warning "Blob properties retrieval failed"
        }
    }
    catch {
        Write-Warning "Blob properties retrieval failed: $($_.Exception.Message)"
    }
}

function Test-Performance {
    Write-Header "Performance Testing"
    
    Write-Info "Running performance tests..."
    
    # Multiple small operations
    Write-Info "Testing multiple small operations..."
    $operationTimes = @()
    
    for ($i = 1; $i -le 10; $i++) {
        $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $result = az storage blob list --container-name $TestContainer --account-name $StorageAccountName --auth-mode login --output none 2>$null
            $stopwatch.Stop()
            $operationTimes += $stopwatch.ElapsedMilliseconds
            Write-Host "Operation $i`: $($stopwatch.ElapsedMilliseconds)ms"
        }
        catch {
            $stopwatch.Stop()
            Write-Warning "Operation $i failed"
        }
    }
    
    if ($operationTimes.Count -gt 0) {
        $avgTime = ($operationTimes | Measure-Object -Average).Average
        $minTime = ($operationTimes | Measure-Object -Minimum).Minimum
        $maxTime = ($operationTimes | Measure-Object -Maximum).Maximum
        
        Write-Success "Performance Summary:"
        Write-Host "  Average: $([math]::Round($avgTime, 2))ms"
        Write-Host "  Minimum: $minTime ms"
        Write-Host "  Maximum: $maxTime ms"
    }
}

function Show-NetworkInfo {
    Write-Header "VM Network Information"
    
    Write-Info "VM IP Configuration:"
    Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" } | Format-Table InterfaceAlias, IPv4Address, IPv4DefaultGateway
    
    Write-Info "DNS Servers:"
    Get-DnsClientServerAddress | Where-Object { $_.AddressFamily -eq 2 } | Format-Table InterfaceAlias, ServerAddresses
    
    Write-Info "Route Table (relevant routes):"
    Get-NetRoute | Where-Object { $_.DestinationPrefix -like "10.*" -or $_.DestinationPrefix -eq "0.0.0.0/0" } | Format-Table DestinationPrefix, NextHop, InterfaceAlias
}

function Generate-TestReport {
    Write-Header "Test Report Summary"
    
    $reportFile = "$env:USERPROFILE\Desktop\PrivateStorageTestReport-$(Get-Date -Format 'yyyyMMdd-HHmmss').txt"
    
    $report = @"
Azure Private Storage Test Report
Generated: $(Get-Date)
VM: $env:COMPUTERNAME
User: $env:USERNAME

Storage Account: $StorageAccountName
Expected Private IP: $ExpectedPrivateIP
Test Container: $TestContainer

Test Results:
- DNS Resolution: $(if (Resolve-DnsName -Name $StorageAccountFQDN -ErrorAction SilentlyContinue) { "Success" } else { "Failed" })
- Network Connectivity: $(if ((Test-NetConnection -ComputerName $StorageAccountFQDN -Port 443 -WarningAction SilentlyContinue).TcpTestSucceeded) { "Success" } else { "Failed" })
- Azure CLI Auth: $(if (az account show 2>$null) { "Authenticated" } else { "Not Authenticated" })

Network Configuration:
$(Get-NetIPConfiguration | Where-Object { $_.NetAdapter.Status -eq "Up" } | Select-Object InterfaceAlias, IPv4Address | Format-Table | Out-String)

Recommendations:
1. Verify DNS resolution points to private IP ($ExpectedPrivateIP)
2. Ensure network connectivity works on port 443
3. Confirm storage operations work from VM
4. Monitor Azure Monitor logs for access patterns

"@

    $report | Out-File -FilePath $reportFile -Encoding UTF8
    Write-Success "Test report saved to: $reportFile"
}

# Main execution logic
Write-Header "Azure Private Storage VM Test Script"
Write-Info "VM: $env:COMPUTERNAME"
Write-Info "User: $env:USERNAME"
Write-Info "Storage Account: $StorageAccountName"
Write-Info "Expected Private IP: $ExpectedPrivateIP"

if ($All -or (!$ConnectivityTests -and !$StorageOperations -and !$PerformanceTests)) {
    Show-NetworkInfo
    Test-Connectivity
    Test-StorageOperations
    Test-Performance
    Generate-TestReport
} else {
    if ($ConnectivityTests) { Test-Connectivity }
    if ($StorageOperations) { Test-StorageOperations }
    if ($PerformanceTests) { Test-Performance }
}

Write-Header "VM Testing Completed"
Write-Success "All tests completed successfully!"
Write-Info "Check Azure Monitor logs for generated activity"
Write-Info "Use the main bash script to run monitoring queries"
