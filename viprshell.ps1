###ViPRshell###
#ViPR PowerShell Module#
#Created by Brandon Kvarda#

#Trust all certificates
add-type @"
    using System.Net;
    using System.Security.Cryptography.X509Certificates;
    public class TrustAllCertsPolicy : ICertificatePolicy {
        public bool CheckValidationResult(
            ServicePoint srvPoint, X509Certificate certificate,
            WebRequest request, int certificateProblem) {
            return true;
        }
    }
"@
[System.Net.ServicePointManager]::CertificatePolicy = New-Object TrustAllCertsPolicy

####Token Generation####
Function New-ViPR-Proxy-Token{
[Cmdletbinding()]

Param(
  [string]$ViprIP,
  [string]$Username,
  [string]$Password,
  [string]$Proxyusername,
  [string]$Proxypassword,
  [string]$TokenPath
)

    #If the path doesn't exist, create it
    $result = Test-Path $TokenPath
    if(!$result){

       $created = New-Item $TokenPath -ItemType directory

    }

    $initialloginuri = "https://"+$ViprIP+":4443/login"

    #creating base64 basic authentication header using helper function for initial login
    $headers = Get-AuthHeader -username $Username -password $Password

    #send the initial login request 
    $response = (Invoke-WebRequest -Uri $initialloginuri -Method GET -Headers $headers -ContentType "application/json")
    $authtoken = $response.Headers.'X-SDS-AUTH-TOKEN'
    $headers.add("X-SDS-AUTH-TOKEN",$authtoken)


    $tokenuri = "https://"+$ViprIP+":4443/proxytoken"

    #Now send the request to obtain the proxy token for your user
    $request = Invoke-WebRequest -Uri $tokenuri -WebSession $session -Method GET -ContentType "application/json" -Headers $headers
    $request.Headers.'X-SDS-AUTH-PROXY-TOKEN' | Out-File "$TokenPath/viprproxytoken.txt" -Force


}

Function New-ViprProxyUserAuthToken{
 [Cmdletbinding()]
 Param(
 [Parameter(Mandatory=$true)]
 [string]$ViprIP,
 [Parameter(Mandatory=$true)]
 [string]$TokenPath,
 [Parameter(Mandatory=$true)]
 [string]$ProxyUserName,
 [Parameter(Mandatory=$true)]
 [string]$ProxyUserPassword
 )  

    #If the path doesn't exist, create it
    $result = Test-Path $TokenPath
    if(!$result){

       $created = New-Item $TokenPath -ItemType directory

    }

    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $newheaders = Get-AuthHeader -username $ProxyUserName -password $ProxyUserPassword
    $newheaders.add("X-SDS-AUTH-PROXY-TOKEN",$proxytoken)

    $loginuri = "https://"+$ViprIP+":4443/login"

    #Now get the auth token and proxy token for the proxyuser
    $tokenrequest = Invoke-WebRequest -Uri $loginuri -Method Get -Headers $newheaders -ContentType "application/json"
    $tokenrequest.Headers.'X-SDS-AUTH-TOKEN' | Out-File "$TokenPath/viprauthtoken.txt" -Force

   


}


####Tenant Services####
Function Get-ViPRTenant{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/tenants/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select

}

Function Get-ViPRProject{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/projects/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select


}


####Compute Services####
Function Get-ViPRHost{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/compute/hosts/search?name=$Name"

    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select


}

###Catalog SErvice###
Function Get-ViprCatalogServiceInfo{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$CatalogID,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/catalog/services/$CatalogID"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select


}

Function Get-ViprExportGroup{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/block/exports/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource 


}


####Block Services####
Function Get-ViPRVolume{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/block/volumes/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select
}

####Snapshot Services####
Function Get-ViPRSnapshot{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/block/snapshots/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select


}

####UI Services - Order####

Function Get-ViPROrder{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$ID,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)
    $uri = "https://"+$ViprIP+":4443/catalog/orders/$ID"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

    $response

}
Function New-ViPRSnapshot-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$VolumeName,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName
)

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "CreateBlockSnapshot").id
 $VolumeID = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "VolumeID is $VolumeID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "ProjectID is $ProjectID"

    $jsonbody = '
    {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "volumes",
          "value": "'+$VolumeID+'"
        },
        {
          "label": "type",
          "value": "local"
        },
        {
          "label": "name",
          "value": "'+$SnapshotName+'"
        }

    ],
     "catalog_service": "'+$CatalogID+'"
   }'

    
 
    $body = $jsonbody |ConvertFrom-Json

    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
  
     $response = (Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json")
     $response
  

}

Function Remove-ViprSnapshot-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName
 
)

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "RemoveBlockSnapshot").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "VolumeID is $VolumeID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "ProjectID is $ProjectID"

    $jsonbody = '
    {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "snapshots",
          "value": "'+$SnapshotID+'"
        }

    ],
     "catalog_service": "'+$CatalogID+'"
   }'


    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
  
     $response = (Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json")
     $response
}

Function Export-ViPRSnapshot-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$HostName,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName,
  [Parameter(Mandatory=$true)]
  [string]$HLU,
  [Parameter(Mandatory=$true)]
  [ValidateSet('exclusive','shared')]
  [string]$StorageType
)

 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "ExportSnapshottoaHost").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $HostID = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "Snapshot ID is $SnapshotID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "Host ID is $HostID"
 Write-Verbose "Project ID is $ProjectID"

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $jsonbody = '
 {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "storageType",
          "value": "'+$StorageType+'"
        },
        {
          "label": "host",
          "value": "'+$HostID+'"
        },
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "snapshots",
          "value": "'+$SnapshotID+'"
        },
        {
          "label": "hlu",
          "value": "'+$HLU+'"

        }

    ],
     "catalog_service": "'+$CatalogID+'"}'
    
    
    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
        $response
    
}

Function Unexport-ViPRSnapshot-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$HostName,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName
 
)

 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "UnexportSnapshot").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $ExportID = (Get-ViprExportGroup -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "Snapshot ID is $SnapshotID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "Host ID is $HostID"
 Write-Verbose "Project ID is $ProjectID"

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $jsonbody = '
 {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "export",
          "value": "'+$ExportID+'"
        },
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "snapshot",
          "value": "'+$SnapshotID+'"
        }
    ],
     "catalog_service": "'+$CatalogID+'"}'
    
    
    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
        $response

}

Function Mount-ViPRWindowsVolume-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$HostName,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName,
  [Parameter(Mandatory=$true)]
  [ValidateSet('exclusive','shared')]
  [string]$StorageType,
  [Parameter(Mandatory=$true)]
  [ValidateSet('gpt','mbr')]
  [string]$PartitionType,
  [Parameter(Mandatory=$true)]
  [ValidateSet('ntfs','fat32')]
  [string]$FileSystemType,
  [Parameter()]
  [string]$DriveLabel =" ",
  [Parameter()]
  [string]$MountPoint=" "
)

 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "MountVolumeOnWindows").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $HostID = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "Snapshot ID is $SnapshotID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "Host ID is $HostID"
 Write-Verbose "Project ID is $ProjectID"

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $jsonbody = '
 {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "blockStorageType",
          "value": "'+$StorageType+'"
        },
        {
          "label": "host",
          "value": "'+$HostID+'"
        },
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "volume",
          "value": "'+$SnapshotID+'"
        },
        {
          "label": "fileSystemType",
          "value": "'+$FileSystemType+'"
        },
        {
          "label": "doFormat",
          "value": "false"
        },
        {
          "label": "partitionType",
          "value": "'+$PartitionType+'"
        },
        {
          "label": "blockSize",
          "value": "default"
        },
        {
          "label": "mountPoint",
          "value": "'+$MountPoint+'"
        },
        {
          "label": "label",
          "value": "'+$DriveLabel+'"
        }        
    ],
     "catalog_service": "'+$CatalogID+'"}'
    
    
    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
        $response
    
}

Function Unmount-ViPRWindowsVolume-Order{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$HostName,
  [Parameter(Mandatory=$true)]
  [string]$TenantName,
  [Parameter(Mandatory=$true)]
  [string]$ProjectName,
  [Parameter(Mandatory=$true)]
  [ValidateSet('exclusive','shared')]
  [string]$StorageType
)

 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -ViprIP $ViprIP -Name "MountVolumeOnWindows").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $HostID = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName).id
 $ProjectID = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName).id
 Write-Verbose "Catalog ID is $CatalogID"
 Write-Verbose "Snapshot ID is $SnapshotID"
 Write-Verbose "TenantID is $TenantID"
 Write-Verbose "Host ID is $HostID"
 Write-Verbose "Project ID is $ProjectID"

 $uri = "https://"+$ViprIP+":4443/catalog/orders"
 $jsonbody = '
 {
    "tenantId": "'+$TenantID+'",
    "parameters": [
        {
          "label": "blockStorageType",
          "value": "'+$StorageType+'"
        },
        {
          "label": "host",
          "value": "'+$HostID+'"
        },
        {
          "label": "project",
          "value": "'+$ProjectID+'"
        },
        {
          "label": "volume",
          "value": "'+$SnapshotID+'"
        }        
    ],
     "catalog_service": "'+$CatalogID+'"}'
    
    
    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
        $response
    
}


Function Get-ViPROrderStatus{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$OrderID,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/catalog/orders/$OrderID/execution"
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    
    
    $status = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
    $status
    
}

####UI Services - Catalog Services####
Function Get-ViPRCatalogService{
 [Cmdletbinding()]
 Param(
 [Parameter(Mandatory=$true)]
 [string]$ViprIP,
 [Parameter(Mandatory=$true)]
 [string]$TokenPath,
 [Parameter(Mandatory=$true)]
 [string]$Name
 )

 $uri = "https://"+$ViprIP+":4443/catalog/services/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $response.resource | Where match -eq $Name | Select

}









####Helpers####

#Generates Basic Auth base64 header
Function Get-AuthHeader([string]$username,[string]$password){
 
  $basicAuth = ("{0}:{1}" -f $username,$password)
  $basicAuth = [System.Text.Encoding]::UTF8.GetBytes($basicAuth)
  $basicAuth = [System.Convert]::ToBase64String($basicAuth)
  $headers = @{Authorization=("Basic {0}" -f $basicAuth)}

  return $headers
 
}

Function Get-ViprErrorMsg([AllowNull()][object]$errordata){   
    $ed = $errordata
    
  try{ 
    $ed = $_.Exception.Response.GetResponseStream()
    $reader = New-Object System.IO.StreamReader($ed)
    $responseBody = $reader.ReadToEnd(); 
    $errorcontent = $responseBody | ConvertFrom-Json
    $errormsg = $errorcontent.message

    Write-Host -ForegroundColor Red $errormsg
    return $errorcontent
    
    }
   catch{
    Write-Host ""
    Write-Host -ForegroundColor Red "Probably Auth error"
    
   } 
  
}

Function Snap-And-Mount-Test{
[CmdletBinding()]

#This section defines variables - long term some persistence layer/SQL/PS will handle this - or you can add parameters to this script and load them in from somewhere else.
$ProxyUsername = "proxyuser"
$ProxyUserPassword = "EMCroot1!"
$TokenPath = "C:\vipr\token"
$VolumeToBeSnapped = "CHEXSQLEDW07_DATA6"
$MountHost = "CHEXSQLNRT020"
$SnapshotName = "DEMO_SNAP"
$SnapHLU = "-1"
$TenantName = "Provider Tenant"
$ProjectName = "POC_NRT"
$ViprIP = "10.185.55.135"
$StorageType = "exclusive"
$Attempts = 0

###Authenticate the proxyuser

New-ViprProxyUserAuthToken -ViprIP $ViprIP -TokenPath C:\vipr\token -ProxyUserName $ProxyUsername -ProxyUserPassword $ProxyUserPassword -Verbose

###Take the snapshot
WRite-Verbose "Taking the snapshot"
$order = New-ViPRSnapshot-Order -ViprIP $ViprIP -VolumeName $VolumeToBeSnapped -SnapshotName $SnapshotName -TokenPath $TokenPath -TenantName $TenantName -ProjectName $ProjectName -Verbose


###Monitor the status, wait until it's no longer running
$status = "Pending"

While($status -eq "Pending" -or $status -eq "Execute" -or $status -eq "Executing"){
  $progress = (Get-ViPROrderStatus -ViprIP $ViprIP -OrderID $order.id -TokenPath $TokenPath)
  $status = $progress.execution_status
  $task = $progress.current_task
  Write-Verbose "Current Status: $status"
  Write-Verbose "Current Task: $task" 
  Start-Sleep -Seconds 5
}
###Get the order, should return all of the things we need including the final status and new resource IDs
If($status -eq "FAILED"){
    Write-Error "Snapshot failed"
    Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath
    Exit
}


#Return the order and don't quit
Write-Verbose "Snapshot Completed Successfuly"
Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath

###Once complete, Map to target
Write-Verbose "Mapping to target Host"
$order = Export-ViPRSnapshot-Order -ViprIP $ViprIP -SnapshotName $SnapshotName -TokenPath $TokenPath -HostName $MountHost -TenantName $TenantName -ProjectName $ProjectName -HLU $SnapHLU -StorageType $StorageType -Verbose


###Monitor the status, wait until it's no longer running
$status = "Pending"

While($status -eq "Pending" -or $status -eq "Execute" -or $status -eq "Executing"){
  $progress = (Get-ViPROrderStatus -ViprIP $ViprIP -OrderID $order.id -TokenPath $TokenPath)
  $status = $progress.execution_status
  $task = $progress.current_task
  Write-Verbose "Current Status: $status"
  Write-Verbose "Current Task: $task" 
  Start-Sleep -Seconds 5
}
###Get the order, should return all of the things we need including the final status and new resource IDs. Exit if failed

If($status -eq "FAILED"){
    Write-Error "Snapshot failed"
    Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath
    Exit
}

#Return the order info
Write-Verbose "Map to target completed successfully"
Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath

#Mount it to the desired host
Write-Verbose "Mounting to desired host"
$order = Mount-ViPRWindowsVolume-Order -ViprIP $ViprIP -SnapshotName $SnapshotName -TokenPath $TokenPath -HostName $MountHost -TenantName $TenantName -ProjectName $ProjectName -StorageType $StorageType -PartitionType gpt -FileSystemType ntfs -Verbose

###Get the order, should return all of the things we need including the final status and new resource IDs. Exit if failed

If($status -eq "FAILED"){
    Write-Error "Snapshot failed"
    Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath
    Exit
}

While($status -eq "Pending" -or $status -eq "Execute" -or $status -eq "Executing"){
  $progress = (Get-ViPROrderStatus -ViprIP $ViprIP -OrderID $order.id -TokenPath $TokenPath)
  $status = $progress.execution_status
  $task = $progress.current_task
  Write-Verbose "Current Status: $status"
  Write-Verbose "Current Task: $task" 
  Start-Sleep -Seconds 5
}

#Return the order info
Write-Verbose "Mount completed successfully"
Write-Verbose "Snap and Mount process completed!"
Get-ViPROrder -ViprIP $ViprIP -ID $order.id -TokenPath $TokenPath

}