# IBM Storage Virtualize PowerShell Toolkit

[![License](https://img.shields.io/badge/License-IBM-blue.svg)](LICENSE)

The **IBM Storage Virtualize PowerShell Toolkit** enables automation and management of IBM Storage Virtualize family products using PowerShell.

It provides a modern, scriptable interface over the REST API, allowing administrators to manage configuration efficiently and consistently.

Designed for both interactive use and automation scenarios, the toolkit supports secure authentication, idempotent operations for safe repeatable execution, and enterprise-grade logging.


## Requirements

- **PowerShell**: Version 5.1 or later

## Installation

1. Download or clone the repository
2. Run the installation script:

```powershell
.\Install-Module.ps1
```
> [!NOTE] 
> If you encounter an execution policy error, run:
> ```powershell
> Unblock-File -Path .\Install-Module.ps1
> ```
> Then rerun:
> ```powershell
> .\Install-Module.ps1
> ```


### Verify Installation

```powershell
# Check installed version
Get-Module -Name IBMStorageVirtualize -ListAvailable

# View available cmdlets
Get-Command -Module IBMStorageVirtualize
```

## Getting Started

### Quick Start Example

```powershell
# Import module
Import-Module IBMStorageVirtualize

# Connect to your IBM Storage Virtualize system
$cred = Get-Credential
Connect-IBMStorageVirtualize -Cluster "1.1.1.1" -Credential $cred -Primary

# Get system information
Get-IBMSVInfo -ObjectType System

# Create a new volume
New-IBMSVVolume -Name "TestVol01" -Size 100 -Unit gb -Pool "Pool1"

# Get information about specific volume
Get-IBMSVVolume -ObjectName "TestVol01"

# Disconnect session
Disconnect-IBMStorageVirtualize
```

## Authentication

The toolkit supports three authentication modes:

### 1. Standard Credential Authentication (Default)

Credentials are used only for authentication and are NOT stored in session. When the token expires, you must reconnect.

```powershell
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $(ConvertTo-SecureString -Force -AsPlainText $Password)
Connect-IBMStorageVirtualize -Cluster "1.1.1.1" -Credential $cred
```

### 2. Credential Caching

Credentials are stored in memory for automatic token refresh.

```powershell
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $(ConvertTo-SecureString -Force -AsPlainText $Password)
Connect-IBMStorageVirtualize -Cluster "1.1.1.1" -Credential $cred -AllowCredentialCaching
```

### 3. Secret-Based Authentication

Use PowerShell SecretManagement module for secure, non-interactive authentication.

This method stores credentials in a secure vault instead of memory, enabling automatic token refresh without exposing credentials in scripts or session state.

#### How It Works
- Credentials are stored securely in a vault (e.g., SecretStore, Azure Key Vault)
- Only a reference (SecretName) is stored in the session

#### Supported Vaults

The toolkit uses PowerShell SecretManagement, which supports multiple vault providers, you can specify a vault explicitly using -VaultName, or use the default vault.

#### Setup SecretManagement

```powershell
# Install SecretManagement module
Install-Module Microsoft.PowerShell.SecretManagement -Scope CurrentUser

# Install a vault extension (e.g., SecretStore)
Install-Module Microsoft.PowerShell.SecretStore -Scope CurrentUser

# Register a vault
# Vaults are scoped per user. Setup is required only once per machine/user 
Register-SecretVault -Name "LocalStore" -ModuleName Microsoft.PowerShell.SecretStore -DefaultVault

# For non-interactive execution
Set-SecretStoreConfiguration -Authentication None -Interaction None

# Store credentials
$cred = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $Username, $(ConvertTo-SecureString -Force -AsPlainText $Password)
Set-Secret -Name "IBMSVCluster1" -Secret $cred -Vault "LocalStore"
```

#### Connect Using Secret

```powershell
Connect-IBMStorageVirtualize -Cluster "1.1.1.1" -SecretName "IBMSVCluster1" -VaultName "LocalStore"
```

### Managing Multiple Clusters

> [!NOTE]
> - The `-Primary` parameter designates the session as the default context for subsequent cmdlet execution.
> - Cmdlets automatically target the primary session unless the `-Cluster` parameter is explicitly specified.
> - Only one primary session can be active at a time, attempting to establish another primary session without disconnecting the existing one will result in an error.

```powershell
# Connect to multiple clusters
Connect-IBMStorageVirtualize -Cluster "1.1.1.1" -SecretName "1.1.1.1" -Primary
Connect-IBMStorageVirtualize -Cluster "1.1.1.2" -SecretName "1.1.1.2"

# View active sessions
Get-IBMSVSession

# View active primary session
Get-IBMSVSession -Primary

# View active session for specific cluster (1.1.1.2)
Get-IBMSVSession -Cluster "1.1.1.2"

# Use default cluster for operations
Get-IBMSVInfo -ObjectType System

# Use specific cluster for operations
Get-IBMSVInfo -ObjectType System -Cluster "1.1.1.2"

# Disconnect specific cluster
Disconnect-IBMStorageVirtualize -Cluster "1.1.1.2"

# Disconnect all clusters
Disconnect-IBMStorageVirtualize
```

## Logging

The toolkit includes a comprehensive logging framework for troubleshooting and auditing.

### Configure Logging

```powershell
# Set log level to DEBUG for detailed output
Set-IBMSVLogger -Level DEBUG

# Set log level to ERROR for minimal output
Set-IBMSVLogger -Level ERROR

# Specify custom log file
Set-IBMSVLogger -Level INFO -LogFile "C:\Logs\ibmsv.log"

# Configure log rotation
Set-IBMSVLogger -LogFile "C:\Logs\ibmsv.log" -MaxLogSizeMB 50 -MaxArchiveFiles 10

# View current logger configuration
Set-IBMSVLogger -ShowConfig
```

### Log Level Explanation

The logger uses the following level order, from least to most verbose:

`ERROR` -> `WARN` -> `INFO` -> `DEBUG`

The configured level acts as the minimum level to record, and it also includes all higher-priority messages above it in the same chain:

- If you set **ERROR**, only error messages are logged.
- If you set **WARN**, warning and error messages are logged.
- If you set **INFO**, informational, warning, and error messages are logged.
- If you set **DEBUG**, all messages are logged, including debug, informational, warning, and error messages.

### Default Logger Settings

When the module is imported, the default logger configuration is:

- **Level**: `INFO`
- **Log file path**: `./IBMSV_powershell.log` in the current PowerShell working directory at import time
- **Max log size**: `10 MB`
- **Max archive files**: `5`

### Log File Path

Use `-LogFile` to write logs to a custom file path.

- If the target directory does not exist, the module attempts to create it automatically.
- If `-LogFile` is not specified, the default log file is `IBMSV_powershell.log` in the current working directory.

### Log Rotation

The logger supports automatic log rotation.

- **MaxLogSizeMB** defines the maximum log file size in MB before rotation occurs.
- **MaxArchiveFiles** defines how many archived log files are retained.
- When the active log file reaches the configured size limit, it is renamed with a timestamp and a new log file is created.
- If **MaxLogSizeMB** is set to `0`, log rotation is disabled.
- If **MaxArchiveFiles** is set to `0`, all archived log files are retained.


## Testing

The toolkit includes comprehensive Pester tests for all cmdlets. Test scripts are located in the [`Tests/`](https://github.com/IBM/IBM-SV-PowerShell/tree/main/Tests) directory.

### Run Tests

```powershell
# Run all tests
.\Tests\Invoke-Test.ps1

# Run tests for specific cmdlet
.\Tests\Invoke-Test.ps1 -TestFile ".\Tests\IBMStorageVirtualize\Public\Volume\New-IBMSVVolume.Tests.ps1"

# Run tests for specific object
.\Tests\Invoke-Test.ps1 -TestFolder ".\Tests\IBMStorageVirtualize\Public\Volume"
```

## Limitations

The toolkit uses REST APIs to communicate with IBM Storage Virtualize systems. The following limitations apply:

- The toolkit was developed and tested with IBM Storage Virtualize version 8.7.0.0.
- IPv6 addresses are not supported for REST API access.
- Listing more than 2000 objects may cause API service interruption due to memory constraints.

## Contributing

Currently we are not accepting community contributions. Though, you may periodically review this content to learn when and how contributions can be made in the future.

## Support

### Documentation

- **Cmdlet Help**: Use `Get-Help <cmdlet-name> -Full` for detailed documentation
- **Examples**: Use `Get-Help <cmdlet-name> -Examples` for usage examples

### Reporting Issues

If you encounter any issues or have feature request:

1. Check existing [issues](https://github.com/IBM/IBM-SV-PowerShell/issues)
2. Create a [new issue](https://github.com/IBM/IBM-SV-PowerShell/issues/new) with detailed information:
   - PowerShell version
   - IBM Storage Virtualize version
   - Steps to reproduce
   - Error messages and logs

### Getting Help

- **IBM Support**: Contact IBM Support for product-related issues

## License

Copyright © 2026 IBM CORPORATION.
