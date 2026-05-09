# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [1.0.0] - 2026-05-09

### Added
- Initial release of IBM Storage Virtualize PowerShell Toolkit

#### Authentication & Session Management
- `Connect-IBMStorageVirtualize`, `Disconnect-IBMStorageVirtualize`, `Get-IBMSVSession`
- Support for multiple authentication modes (credential, cached credential, secret-based)
- REST API integration with token-based authentication

#### Resource Management
- Volume management: `New-IBMSVVolume`, `Set-IBMSVVolume`, `Remove-IBMSVVolume`
- Host management: `New-IBMSVHost`, `Set-IBMSVHost`, `Remove-IBMSVHost`
- Volume-to-host mapping: `New-IBMSVVolToHostMap`, `Remove-IBMSVVolToHostMap`
- Storage pool management: `New-IBMSVPool`, `Set-IBMSVPool`, `Remove-IBMSVPool`
- MDisk management: `New-IBMSVMDisk`, `Set-IBMSVMDisk`, `Remove-IBMSVMDisk`
- Volume group management: `New-IBMSVVolumeGroup`, `Set-IBMSVVolumeGroup`, `Remove-IBMSVVolumeGroup`

#### System & Configuration
- Object information: `Get-IBMSVInfo`, `Get-IBMSVArrayRecommendation`
- Initial setup: `Set-IBMSVLicense`, `Set-IBMSVSystemProperty`
- DNS configuration: `New-IBMSVDNSServer`, `Set-IBMSVDNSServer`, `Remove-IBMSVDNSServer`
- Call home configuration: `Set-IBMSVCloudCallhome`, `Set-IBMSVEmail`

#### Cmdlet Design
- Dynamic generation of `Get-IBMSV*` cmdlets at runtime for broad API coverage
- `Get-IBMSVArrayRecommendation` implemented as a static cmdlet
