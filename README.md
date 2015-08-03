# ViPRShell 

ViPRShell wraps ViPR REST API calls into PowerShell functions. This is currently intended for Snapshot workflows, but is being extended. You can use the module to retrieve information about 
projects, tenants, volumes, snapshots, hosts, and exports; Create orders for snapshots, exporting snapshots to hosts, mounting snapshots to hosts, and deleting snapshots; Get and set volume and snapshot tags.  

## Installation

Place all contents into your [PowerShell Module folder](https://msdn.microsoft.com/en-us/library/dd878350%28v=vs.85%29.aspx), or use [Import-Module](https://technet.microsoft.com/en-us/library/hh849725.aspx)
It is expected to see Warnings when importing the module, as some non-standard verbs were used in this module to better represent the functionality of certain functions. 
##Usage

Below is a list of commands that can currently be leveraged by using this module. For help regarding each command, import the module and leverage the 'Get-Help' functionality of PowerShell.
For example, "Get-Help Get-ViPRHost -All" will return a description of the command, the parameters and information about each parameter, as well as examples. 
```
Export-ViPRSnapshot-Order
```
```
Get-ViPRCatalogService
```
```
Get-ViprExportGroup
```
```
Get-ViPRHost
```
```
Get-ViPROrder
```
```
Get-ViPROrderStatus
```
```
Get-ViPRProject
```
```
Get-ViPRSnapshot
```
```
Get-ViPRSnapshots
```
```
Get-ViPRSnapshotTags
```
```
Get-ViPRTenant
```
```
Get-ViPRVolume
```
```
Get-ViPRVolumes
```
```
Get-ViPRVolumeTags
```
```
Mount-ViPRWindowsVolume-Order
```
```
New-ViPRProxyToken
```
```
New-ViprProxyUserAuthToken
```
```
New-ViPRSnapshot-Order
```
```
Remove-ViprSnapshot-Order
```
```
Set-ViPRSnapshotTag
```
```
Set-ViPRVolumeTag
```
```
Unexport-ViPRSnapshot-Order
```
```
Unmount-ViPRWindowsVolume-Order
```


##Support
Please file bugs and issues at the Github issues page. For more general discussions you can contact the EMC Code team at <https://groups.google.com/forum/#!forum/emccode-users>. The code and 
documentation are released with no warranties or SLAs and are intended to be supported through a community driven process.  

##Licensing
The MIT License (MIT)

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.