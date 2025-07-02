# Azure Private Storage Infrastructure with Terraform

![Azure](https://img.shields.io/badge/Azure-Infrastructure-blue)
![Terraform](https://img.shields.io/badge/Terraform-v1.0+-purple)
![License](https://img.shields.io/badge/License-MIT-green)

This Terraform project creates a secure Azure infrastructure with Private Endpoints for storage access, based on the DataSafe Private Link POC architecture.

## 🏗️ Architecture Overview

This project provisions:

- **Resource Group**: Centralized container for all resources
- **Virtual Network**: Isolated network with two subnets
  - `snet-privateendpoints`: Dedicated for Private Endpoints
  - `snet-compute`: For compute resources (VMs)
- **Storage Account**: Configured with private access only
- **Private Endpoint**: Secure connection to blob storage
- **Private DNS Zone**: Name resolution for private endpoints
- **Test Virtual Machine**: For validation and testing
- **Monitoring**: Optional diagnostic settings

## 🔐 Security Features

- ✅ **No Public Storage Access**: Storage account blocks all public traffic
- ✅ **Private Connectivity**: All access via Private Endpoints only
- ✅ **Network Isolation**: Dedicated subnets for different workloads
- ✅ **DNS Resolution**: Private DNS zones for secure name resolution
- ✅ **Minimal Permissions**: Least privilege access patterns

## 📁 Project Structure

```
terraform-azure-private-storage/
├── main.tf                    # Root module configuration
├── variables.tf               # Input variables with validation
├── outputs.tf                 # Output values for integration
├── terraform.tf              # Provider and version constraints
├── locals.tf                  # Local values and calculations
├── terraform.tfvars.example  # Example variable values
├── README.md                  # This documentation
├── modules/
│   ├── networking/            # Virtual network, subnets, DNS
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   ├── storage/              # Storage account with private endpoint
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   └── compute/              # Test virtual machine
│       ├── main.tf
│       ├── variables.tf
│       └── outputs.tf
└── examples/
    └── complete/             # Complete deployment example
        ├── main.tf
        ├── variables.tf
        ├── outputs.tf
        └── terraform.tfvars.example
```

## 🚀 Quick Start

### Prerequisites

- [Terraform](https://www.terraform.io/downloads.html) >= 1.0
- [Azure CLI](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli) >= 2.0
- Azure subscription with appropriate permissions

### Installation

1. **Clone the repository**
   ```bash
   git clone <repository-url>
   cd terraform-azure-private-storage
   ```

2. **Authenticate with Azure**
   ```bash
   az login
   az account set --subscription "your-subscription-id"
   ```

3. **Initialize Terraform**
   ```bash
   terraform init
   ```

4. **Create terraform.tfvars**
   ```bash
   cp terraform.tfvars.example terraform.tfvars
   # Edit terraform.tfvars with your values
   ```

5. **Plan and Apply**
   ```bash
   terraform plan
   terraform apply
   ```

## ⚙️ Configuration

### Required Variables

| Variable | Description | Type | Example |
|----------|-------------|------|---------|
| `location` | Azure region | `string` | `"West Europe"` |
| `environment` | Environment name | `string` | `"poc"` |
| `admin_username` | VM administrator username | `string` | `"azureadmin"` |
| `admin_password` | VM administrator password | `string` | `"YourSecurePassword123!"` |

### Optional Variables

| Variable | Description | Type | Default |
|----------|-------------|------|---------|
| `resource_group_name` | Custom RG name | `string` | `"rg-datasafe-privatelink-{environment}"` |
| `vnet_address_space` | VNet CIDR block | `string` | `"10.10.0.0/16"` |
| `enable_monitoring` | Enable diagnostics | `bool` | `true` |
| `tags` | Resource tags | `map(string)` | `{}` |

## 🔧 Usage Examples

### Basic Deployment

```hcl
module "private_storage" {
  source = "./modules"
  
  location        = "West Europe"
  environment     = "poc"
  admin_username  = "azureadmin"
  admin_password  = "YourSecurePassword123!"
  
  tags = {
    Project     = "DataSafe"
    Environment = "POC"
    Owner       = "Cloud Team"
  }
}
```

### Advanced Configuration

```hcl
module "private_storage" {
  source = "./modules"
  
  location              = "West Europe"
  environment           = "production"
  resource_group_name   = "rg-custom-name"
  vnet_address_space    = "172.16.0.0/16"
  enable_monitoring     = true
  
  admin_username = "azureadmin"
  admin_password = var.admin_password  # From Azure Key Vault or secure input
  
  tags = {
    Project      = "DataSafe"
    Environment  = "Production"
    Owner        = "Cloud Team"
    CostCenter   = "IT-001"
    Compliance   = "SOC2"
  }
}
```

## 🧪 Testing and Validation

After deployment, verify the infrastructure:

### 1. Connect to Test VM

```bash
# Get the VM's public IP from Terraform outputs
terraform output vm_public_ip

# RDP to the VM using the credentials you specified
```

### 2. Test DNS Resolution

From within the VM (PowerShell):

```powershell
# Test private DNS resolution
nslookup <storage-account-name>.blob.core.windows.net

# Expected result: Private IP (10.10.1.x)
```

### 3. Test Storage Connectivity

```powershell
# Test network connectivity
Test-NetConnection <storage-account-name>.blob.core.windows.net -Port 443

# Expected result: TcpTestSucceeded = True
```

### 4. Verify No Public Access

From your local machine:

```bash
# This should fail or timeout
curl https://<storage-account-name>.blob.core.windows.net
```

## 📊 Monitoring and Diagnostics

The project includes optional monitoring features:

- **Storage Account Diagnostics**: Tracks access patterns and security events
- **Network Security Group Flow Logs**: Monitor network traffic
- **Private Endpoint Metrics**: Connection and performance monitoring

Enable monitoring by setting `enable_monitoring = true` in your configuration.

## 🛠️ Customization

### Adding Additional Private Endpoints

To add more private endpoints (e.g., for Table, Queue, File services):

```hcl
# In your terraform.tfvars
additional_private_endpoints = {
  "table" = {
    subresource_names = ["table"]
  }
  "queue" = {
    subresource_names = ["queue"]
  }
}
```

### Custom Network Configuration

```hcl
# Custom subnet configurations
subnets = {
  private_endpoints = {
    address_prefixes = ["10.10.1.0/24"]
    service_endpoints = []
  }
  compute = {
    address_prefixes = ["10.10.2.0/24"]
    service_endpoints = ["Microsoft.Storage"]
  }
  additional = {
    address_prefixes = ["10.10.3.0/24"]
    service_endpoints = []
  }
}
```

## 🔄 CI/CD Integration

### GitHub Actions Example

```yaml
name: 'Terraform'

on:
  push:
    branches: [ main ]
  pull_request:

jobs:
  terraform:
    name: 'Terraform'
    runs-on: ubuntu-latest
    
    steps:
    - name: Checkout
      uses: actions/checkout@v3
      
    - name: Setup Terraform
      uses: hashicorp/setup-terraform@v2
      
    - name: Terraform Init
      run: terraform init
      
    - name: Terraform Plan
      run: terraform plan
      
    - name: Terraform Apply
      if: github.ref == 'refs/heads/main'
      run: terraform apply -auto-approve
```

## 🏷️ Resource Naming Convention

The project follows Azure naming conventions:

- **Resource Groups**: `rg-{project}-{workload}-{environment}`
- **Virtual Networks**: `vnet-{project}-{environment}`
- **Subnets**: `snet-{purpose}`
- **Storage Accounts**: `stg{project}{environment}{random}`
- **Private Endpoints**: `pep-{service}-{subresource}`
- **DNS Zones**: `privatelink.{service}.core.windows.net`

## 🔐 Security Considerations

- Store sensitive variables (passwords, keys) in Azure Key Vault
- Use Azure AD authentication where possible
- Implement network security groups for additional protection
- Regularly review and rotate access keys
- Monitor access logs and security events

## 🆘 Troubleshooting

### Common Issues

1. **DNS Resolution Problems**
   - Verify Private DNS Zone is linked to VNet
   - Check subnet configuration for Private Endpoints
   - Flush DNS cache: `ipconfig /flushdns`

2. **Connection Timeouts**
   - Verify Private Endpoint status is "Approved"
   - Check Network Security Group rules
   - Confirm storage account public access is disabled

3. **Terraform State Issues**
   - Use remote state backend for team collaboration
   - Implement state locking with Azure Storage

## 🤝 Contributing

1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Based on Azure Private Endpoint best practices
- Inspired by the DataSafe Private Link POC architecture
- Terraform Azure Provider documentation
- Azure Well-Architected Framework

## 📞 Support

For questions and support:

- 📧 Email: [your-team@company.com]
- 💬 Slack: #cloud-infrastructure
- 📖 Documentation: [Link to internal docs]
- 🐛 Issues: [GitHub Issues](link-to-issues)

---

**⚠️ Note**: This infrastructure creates resources that may incur Azure costs. Always review the planned resources before applying and clean up when no longer needed.
