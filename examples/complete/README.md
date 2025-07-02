# Complete Private Storage Infrastructure Example

This example demonstrates a complete deployment of Azure Private Storage Infrastructure with Private Endpoints. It showcases all features and provides a fully functional environment for testing and learning.

## 🏗️ What This Example Deploys

This complete example creates:

- **Resource Group**: Container for all resources
- **Virtual Network**: With dedicated subnets for private endpoints and compute
- **Storage Account**: Configured with private access only
- **Private Endpoint**: Secure connection to blob storage
- **Private DNS Zone**: For private name resolution
- **Test Virtual Machine**: Windows Server with pre-installed tools
- **Monitoring**: Log Analytics workspace and diagnostics
- **Security**: Network Security Groups with appropriate rules

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.0
- Azure subscription with Contributor permissions

### Step 1: Authentication

```bash
# Login to Azure
az login

# Set your subscription
az account set --subscription "your-subscription-id"
```

### Step 2: Clone and Navigate

```bash
# Navigate to the complete example
cd examples/complete
```

### Step 3: Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the file with your preferred settings
nano terraform.tfvars
```

**⚠️ Important**: Make sure to change the `admin_password` variable to a secure password that meets Azure requirements.

### Step 4: Deploy

```bash
# Initialize Terraform
terraform init

# Review the plan
terraform plan

# Deploy the infrastructure
terraform apply
```

### Step 5: Test the Infrastructure

After deployment, use the outputs to test the setup:

```bash
# Get the outputs
terraform output

# Connect to the VM using the provided RDP information
terraform output vm_public_ip
```

## 🧪 Testing and Validation

### 1. DNS Resolution Test

Connect to the VM via RDP and run:

```powershell
# Should resolve to a private IP (10.10.1.x)
nslookup <storage-account-name>.blob.core.windows.net
```

### 2. Connectivity Test

```powershell
# Should succeed
Test-NetConnection <storage-account-name>.blob.core.windows.net -Port 443
```

### 3. External Access Test

From your local machine (should fail):

```bash
# This should timeout or be blocked
curl https://<storage-account-name>.blob.core.windows.net
```

### 4. Storage Access Test

From the VM:

```powershell
# Install Azure PowerShell (if not already installed)
Install-Module -Name Az -Force -AllowClobber

# Connect using your Azure credentials
Connect-AzAccount

# List storage containers (should work via private endpoint)
$ctx = New-AzStorageContext -StorageAccountName "<storage-account-name>" -UseConnectedAccount
Get-AzStorageContainer -Context $ctx
```

## ⚙️ Configuration Options

### Basic Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `location` | Azure region | `"West Europe"` |
| `environment` | Environment name | `"poc"` |
| `project_name` | Project name | `"datasafe"` |

### Security Configuration

| Variable | Description | Default |
|----------|-------------|---------|
| `enable_rdp_access` | Enable RDP to VM | `true` |
| `rdp_source_address_prefix` | RDP source IPs | `"*"` |
| `admin_username` | VM admin username | `"azureadmin"` |
| `admin_password` | VM admin password | `"ChangeMe123!@#"` |

### Advanced Features

```hcl
# Add additional private endpoints
additional_private_endpoints = {
  "table" = {
    subresource_names = ["table"]
    private_dns_zone  = "privatelink.table.core.windows.net"
  }
  "queue" = {
    subresource_names = ["queue"]
    private_dns_zone  = "privatelink.queue.core.windows.net"
  }
}
```

## 🔧 Customization Examples

### Production-Ready Configuration

```hcl
# terraform.tfvars for production
environment = "prod"
storage_replication_type = "GRS"
vm_size = "Standard_D4s_v3"
create_bastion = true
enable_rdp_access = false
rdp_source_address_prefix = "10.0.0.0/8"
log_retention_days = 90

tags = {
  Project     = "DataSafe"
  Environment = "Production"
  Owner       = "Cloud Team"
  CostCenter  = "IT-001"
  Compliance  = "SOC2"
}
```

### Development Configuration

```hcl
# terraform.tfvars for development
environment = "dev"
storage_replication_type = "LRS"
vm_size = "Standard_B1s"
create_monitoring = false
log_retention_days = 7

tags = {
  Project     = "DataSafe"
  Environment = "Development"
  Owner       = "Dev Team"
  AutoShutdown = "Enabled"
}
```

## 📊 Cost Optimization

### Estimated Monthly Costs (West Europe)

- **Storage Account (LRS, 1GB)**: ~$0.05
- **Private Endpoint**: ~$7.30
- **VM Standard_B2s**: ~$31.00
- **Public IP**: ~$3.65
- **Log Analytics (1GB)**: ~$2.30

**Total**: ~$44.30/month

### Cost Reduction Tips

1. **Use smaller VM sizes** for testing:
   ```hcl
   vm_size = "Standard_B1s"  # Reduces cost by ~50%
   ```

2. **Disable monitoring** for short-term testing:
   ```hcl
   create_monitoring = false
   ```

3. **Use Spot VMs** (add to compute module):
   ```hcl
   priority = "Spot"
   eviction_policy = "Deallocate"
   ```

## 🛡️ Security Best Practices

### Network Security

- Private endpoints ensure storage is not accessible from internet
- NSGs restrict traffic to necessary ports only
- VM has public IP only for testing (use Bastion in production)

### Access Control

- Storage account keys are managed securely
- VM uses strong password authentication
- All traffic uses HTTPS with TLS 1.2 minimum

### Monitoring

- Storage access logs are collected
- Network flow logs provide traffic visibility
- Security events are centralized in Log Analytics

## 🔄 CI/CD Integration

### GitHub Actions Example

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy Private Storage Infrastructure

on:
  workflow_dispatch:
    inputs:
      environment:
        description: 'Environment to deploy'
        required: true
        default: 'poc'
        type: choice
        options:
        - poc
        - dev
        - prod

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
    - uses: actions/checkout@v3
    
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      
    - name: Azure Login
      uses: azure/login@v1
      with:
        creds: ${{ secrets.AZURE_CREDENTIALS }}
        
    - name: Terraform Init
      run: terraform init
      working-directory: ./examples/complete
      
    - name: Terraform Plan
      run: terraform plan -var="environment=${{ github.event.inputs.environment }}"
      working-directory: ./examples/complete
      
    - name: Terraform Apply
      run: terraform apply -auto-approve -var="environment=${{ github.event.inputs.environment }}"
      working-directory: ./examples/complete
```

## 🆘 Troubleshooting

### Common Issues

1. **VM Creation Fails**
   ```
   Error: Password does not meet complexity requirements
   ```
   **Solution**: Ensure password has uppercase, lowercase, number, and special character

2. **Private Endpoint Not Working**
   ```
   Error: Storage account still accessible from internet
   ```
   **Solution**: Wait 5-10 minutes for DNS propagation, then test again

3. **DNS Resolution Issues**
   ```
   nslookup returns public IP instead of private IP
   ```
   **Solution**: Check Private DNS Zone is linked to VNet, flush DNS cache

### Getting Help

- Check Terraform outputs for connection details
- Review Azure Portal for resource status
- Check NSG rules if connectivity fails
- Verify Private DNS Zone configuration

## 🧹 Cleanup

```bash
# Destroy all resources
terraform destroy

# Confirm destruction
terraform show
```

**Note**: This will remove all resources and cannot be undone.

## 📚 Additional Resources

- [Azure Private Endpoint Documentation](https://docs.microsoft.com/en-us/azure/private-link/private-endpoint-overview)
- [Terraform Azure Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)
- [Azure Storage Security Guide](https://docs.microsoft.com/en-us/azure/storage/common/storage-security-guide)

---

**⚠️ Security Notice**: This example includes a test VM with public RDP access for demonstration purposes. In production environments, use Azure Bastion or VPN for secure access.
