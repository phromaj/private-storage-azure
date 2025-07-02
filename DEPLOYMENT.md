# 🚀 DEPLOYMENT GUIDE

This guide walks you through deploying the Azure Private Storage Infrastructure step by step.

## 📋 Prerequisites Checklist

Before you begin, ensure you have:

- [ ] **Azure Subscription** with Contributor permissions
- [ ] **Terraform** >= 1.0 installed ([Download](https://terraform.io/downloads))
- [ ] **Azure CLI** >= 2.0 installed ([Download](https://docs.microsoft.com/cli/azure/install-azure-cli))
- [ ] **Git** for cloning the repository
- [ ] **Text editor** for configuration files

## 🔧 Step-by-Step Deployment

### Step 1: Authentication & Setup

```bash
# Login to Azure
az login

# List your subscriptions
az account list --output table

# Set the subscription you want to use
az account set --subscription "your-subscription-id-or-name"

# Verify the active subscription
az account show
```

### Step 2: Download the Project

```bash
# Clone the repository (or download the files)
git clone <repository-url>
cd terraform-azure-private-storage

# Or if you downloaded the files, navigate to the directory
cd path/to/terraform-azure-private-storage
```

### Step 3: Configure Variables

```bash
# Copy the example variables file
cp terraform.tfvars.example terraform.tfvars

# Edit the configuration file
nano terraform.tfvars
```

**🔑 Critical Configuration Items:**

1. **Change the admin password**:
   ```hcl
   admin_password = "YourVerySecurePassword123!@#"
   ```
   - Must be 12+ characters
   - Include uppercase, lowercase, number, and special character

2. **Set your location** (optional):
   ```hcl
   location = "West Europe"  # or your preferred region
   ```

3. **Configure RDP access** (for testing):
   ```hcl
   enable_rdp_access = true
   rdp_source_address_prefix = "YOUR.PUBLIC.IP.ADDRESS/32"  # More secure than "*"
   ```

### Step 4: Initialize and Plan

```bash
# Initialize Terraform
terraform init

# Review what will be created
terraform plan

# Save the plan for review (optional)
terraform plan -out=deployment.tfplan
```

### Step 5: Deploy Infrastructure

```bash
# Apply the configuration
terraform apply

# Or apply the saved plan
terraform apply deployment.tfplan
```

**⏱️ Deployment Time**: Approximately 10-15 minutes

### Step 6: Validate Deployment

```bash
# Run the validation script
./validate.sh

# Or manually check outputs
terraform output
```

## 🧪 Testing Your Deployment

### Quick Test Commands

```bash
# Get key information
STORAGE_ACCOUNT=$(terraform output -raw storage_account_name)
VM_PUBLIC_IP=$(terraform output -raw vm_public_ip)

echo "Storage Account: $STORAGE_ACCOUNT"
echo "VM Public IP: $VM_PUBLIC_IP"
```

### External Access Test (Should Fail)

```bash
# This should timeout or return 403 (which is what we want)
curl --max-time 10 "https://$STORAGE_ACCOUNT.blob.core.windows.net"
```

### VM Access Test

1. **Connect via RDP**:
   ```bash
   # On Windows
   mstsc /v:$VM_PUBLIC_IP
   
   # On macOS (with Microsoft Remote Desktop)
   open "rdp://full%20address=s:$VM_PUBLIC_IP"
   
   # On Linux (with rdesktop)
   rdesktop $VM_PUBLIC_IP
   ```

2. **Test from within the VM** (PowerShell):
   ```powershell
   # Test DNS resolution (should return private IP)
   nslookup <storage-account-name>.blob.core.windows.net
   
   # Test connectivity (should succeed)
   Test-NetConnection <storage-account-name>.blob.core.windows.net -Port 443
   
   # Install Azure PowerShell (if needed)
   Install-Module -Name Az -Force -AllowClobber
   
   # Test storage access
   Connect-AzAccount
   $ctx = New-AzStorageContext -StorageAccountName "<storage-account-name>" -UseConnectedAccount
   Get-AzStorageContainer -Context $ctx
   ```

## 🎯 Deployment Scenarios

### Scenario 1: Quick POC (Default)

```hcl
# terraform.tfvars
location = "West Europe"
environment = "poc"
admin_password = "YourSecurePassword123!"
```

**Cost**: ~$44/month  
**Use Case**: Learning, testing, demonstrations

### Scenario 2: Development Environment

```hcl
# terraform.tfvars
location = "West Europe"
environment = "dev"
vm_size = "Standard_B1s"
storage_replication_type = "LRS"
create_monitoring = false
log_retention_days = 7

tags = {
  Project = "DataSafe"
  Environment = "Development"
  AutoShutdown = "Enabled"
}
```

**Cost**: ~$25/month  
**Use Case**: Development and testing

### Scenario 3: Production Ready

```hcl
# terraform.tfvars
location = "West Europe"
environment = "prod"
vm_size = "Standard_D4s_v3"
storage_replication_type = "GRS"
enable_rdp_access = false
create_bastion = true
log_retention_days = 90

additional_private_endpoints = {
  "table" = {
    subresource_names = ["table"]
    private_dns_zone = "privatelink.table.core.windows.net"
  }
}

tags = {
  Project = "DataSafe"
  Environment = "Production"
  CostCenter = "IT-001"
  Compliance = "SOC2"
}
```

**Cost**: ~$150/month  
**Use Case**: Production workloads

## 🔧 Customization Options

### Add Additional Storage Services

```hcl
additional_private_endpoints = {
  "table" = {
    subresource_names = ["table"]
    private_dns_zone = "privatelink.table.core.windows.net"
  }
  "queue" = {
    subresource_names = ["queue"]
    private_dns_zone = "privatelink.queue.core.windows.net"
  }
  "file" = {
    subresource_names = ["file"]
    private_dns_zone = "privatelink.file.core.windows.net"
  }
}
```

### Enable Azure Bastion (More Secure)

```hcl
create_bastion = true
enable_rdp_access = false  # Disable direct RDP
```

### Custom Network Configuration

```hcl
vnet_address_space = "172.16.0.0/16"
subnet_address_prefixes = {
  private_endpoints = "172.16.1.0/24"
  compute = "172.16.2.0/24"
}
```

## 🛠️ Troubleshooting

### Common Issues and Solutions

1. **"Password does not meet complexity requirements"**
   ```
   Solution: Ensure password has 12+ chars with upper, lower, number, special char
   ```

2. **"Storage account name already exists"**
   ```
   Solution: Storage account names are globally unique. The template auto-generates
   unique names, but if you specify a custom name, ensure it's globally unique.
   ```

3. **"Private endpoint not working"**
   ```
   Solution: Wait 5-10 minutes for DNS propagation. Check Private DNS Zone
   configuration and VNet links.
   ```

4. **"Cannot connect to VM"**
   ```
   Solution: Check NSG rules, VM status, and public IP assignment.
   For RDP: Ensure port 3389 is allowed from your IP.
   ```

5. **"DNS still resolving to public IP"**
   ```
   Solution: From the VM, run: ipconfig /flushdns
   Then test again: nslookup <storage-account>.blob.core.windows.net
   ```

### Getting Detailed Logs

```bash
# Enable detailed Terraform logging
export TF_LOG=DEBUG
terraform apply

# Check Azure activity logs
az monitor activity-log list --resource-group $(terraform output -raw resource_group_name)
```

## 💰 Cost Management

### Cost Monitoring

```bash
# Check estimated costs (requires Azure CLI extension)
az consumption usage list --top 10

# Set up cost alerts in Azure Portal
# Billing > Cost Management > Budgets
```

### Cost Optimization

1. **Auto-shutdown for VMs**:
   - Configure in Azure Portal: VM > Auto-shutdown

2. **Use B-series VMs** for development:
   ```hcl
   vm_size = "Standard_B1s"  # Burstable, cost-effective
   ```

3. **Reduce monitoring** for short-term testing:
   ```hcl
   create_monitoring = false
   ```

## 🔄 Updates and Maintenance

### Updating the Infrastructure

```bash
# Pull latest changes
git pull

# Plan the update
terraform plan

# Apply updates
terraform apply
```

### Backup Important Data

```bash
# Export Terraform state
terraform show > infrastructure-backup.txt

# Backup any data in storage account before major changes
```

## 🧹 Cleanup

### Complete Cleanup

```bash
# Destroy all resources
terraform destroy

# Verify everything is deleted
az group list --query "[?name=='$(terraform output -raw resource_group_name)']"

# Clean up Terraform state
rm -rf .terraform terraform.tfstate*
```

### Partial Cleanup (Keep Storage)

```bash
# Disable specific resources
terraform apply -var="create_test_vm=false"
```

## 📞 Support

### Self-Help Resources

- **Terraform Outputs**: `terraform output` - Shows all connection details
- **Validation Script**: `./validate.sh` - Comprehensive health check
- **Azure Portal**: Monitor resources and costs
- **Documentation**: Check the README.md files

### Community Support

- **Terraform Azure Provider Issues**: [GitHub Issues](https://github.com/hashicorp/terraform-provider-azurerm/issues)
- **Azure Documentation**: [Microsoft Docs](https://docs.microsoft.com/azure/)

---

🎉 **Congratulations!** You now have a secure, private storage infrastructure running in Azure with Terraform!

---

**Next Steps:**
1. Explore the storage account via private endpoint
2. Test different storage services (blob, table, queue)
3. Implement your application using this secure foundation
4. Consider additional security measures for production use
