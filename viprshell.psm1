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

#Creates the proxy token - this will be a one-time setup typically
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
#Authenticates the proxy user using the proxy token that was already created
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
    
    $result = try {
                     $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
                     $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                     if(!$id){
                     $id = "13413FAILEDPLACEHOLDER1341313"
                     }

                     $uri = "https://"+$ViprIP+":4443/tenants/$id"

                     $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                     $response
                   }
                catch{
                $_.Exception.Response

                }
            $result

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
  
 

    $id = ($response.resource | Where match -eq $Name | Select).id

    $uri = "https://"+$ViprIP+":4443/projects/$id"

    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

    $response


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
        
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "13413FAILEDPLACEHOLDER1341313"
                    }
                    
                    $uri = "https://"+$ViprIP+":4443/compute/hosts/$id"

                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

                $_.Exception.Response
            }

         $result
 
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
  
 

    $id = ($response.resource).id

    $uri = "https://"+$ViprIP+":4443/block/exports/$id"

    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

    $response 


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
  
 

    $id = ($response.resource | Where match -eq $Name | Select id)

    $uri = "https://"+$ViprIP+":4443/block/volumes/$id"

    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

    $response
}

#Returns array of Volume objects 
Function Get-ViPRVolumes{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)
    $object = @()
    $uri = "https://"+$ViprIP+":4443/block/volumes/bulk"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
   
 
     $response | ForEach-Object{ 
        $id = ($response.resource | Where match -eq $Name | Select).id
        $uri = "https://"+$ViprIP+":4443/block/volumes/$id"
        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        $object += $response
    }
    $object
}

####Snapshot Services####
#Gets Snapshot information based on a name 
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
  
 

    $id = ($response.resource | Where match -eq $Name | Select).id

    $uri = "https://"+$ViprIP+":4443/block/snapshots/$id"

    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

    $response


}

#Gets all Snapshot information 
Function Get-ViPRSnapshots{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$ParentVolumeName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

  $relatedsnaps = @()
  $parentvolume = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName)

    $uri = "https://"+$ViprIP+":4443/block/snapshots/bulk"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
   
 
     $response | ForEach-Object{ 
        $id = ($response.resource | Where match -eq $Name | Select).id
        $uri = "https://"+$ViprIP+":4443/block/snapshots/$id"
        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        if($response.parent.id -eq $parentvolume.id){
        $relatedsnaps += $response
        }
    }

    $relatedsnaps

}

#Gets Tags for a Snapshot
Function Get-ViPRSnapshotTags{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

  $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
  $uri = "https://"+$ViprIP+":4443/block/snapshots/$SnapshotID/tags"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
  $response

}

#Gets Tags for a Snapshot
Function Set-ViPRSnapshotTag{
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$Tag,
  [Parameter(Mandatory=$true)]
  [ValidateSet('Add','Remove')]
  [string]$Action,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

  $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
  $uri = "https://"+$ViprIP+":4443/block/snapshots/$SnapshotID/tags"
  if($Action -eq 'Add'){
     
      $jsonbody = '
       {
        "add": [
          "'+$Tag+'"
        ],
        "remove": [
          ""
        ]
      }'
  }
  elseif($Action -eq 'Remove'){
      $jsonbody = '
       {
        "add": [
          ""
        ],
        "remove": [
          "'+$Tag+'"
        ]
      }'

  }
    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $response = Invoke-RestMethod -Uri $uri -Method PUT -Body $jsonbody -Headers $headers -ContentType "application/json"
  
  $response

}
####UI Services - Order####

#Returns the order information given an order ID which will show status 
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "CreateBlockSnapshot").id
 $VolumeID = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName).id
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -TenantID $TenantID -ViprIP $ViprIP -Name "RemoveBlockSnapshot").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "ExportSnapshottoaHost").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "UnexportSnapshot").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "MountVolumeOnWindows").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
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
 $TenantID = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName).id
 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "UnmountVolumeOnWindows").id
 $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
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
          "label": "volumes",
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

#Checks order status until it has a successful or failure state, then returns the order information
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

     ###Monitor the status, wait until it's no longer running
    $status = "Pending"

    While($status -eq "Pending" -or $status -eq "Execute" -or $status -eq "Executing"){
      $progress = (Get-ViPROrder -ViprIP $ViprIP -ID $OrderID -TokenPath $TokenPath)
      $status = $progress.order_status
  
      Write-Verbose "Current Status: $status"
  
      Start-Sleep -Seconds 5
    }
    ###Get the order, should return all of the things we need including the final status and new resource IDs
    If($status -eq "FAILED" -or $status -eq "ERROR"){
        Write-Error "Snapshot failed"
        Get-ViPROrder -ViprIP $ViprIP -ID $OrderID -TokenPath $TokenPath
    }

    #Return the order, it completed
    Write-Verbose "Snapshot Completed Successfuly"
    Get-ViPROrder -ViprIP $ViprIP -ID $OrderID -TokenPath $TokenPath
    
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
 [string]$Name,
 [Parameter(Mandatory=$true)]
 [string]$TenantID
 )

 $uri = "https://"+$ViprIP+":4443/catalog/services/search?name=$Name"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $catalogservices = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
  
 

    $catalogservices.resource | ForEach-Object{
        $href = $_.link.href
       
        $serviceuri = "https://"+$ViprIP+":4443$href"
       
        $response = Invoke-RestMethod -Uri $serviceuri -Method GET -Headers $headers -ContentType "application/json"
        
        $categoryhref = $response.catalog_category.link.href
        $categoryuri = "https://"+$ViprIP+":4443$categoryhref"
        

        $response = Invoke-RestMethod -Uri $categoryuri -Method GET -Headers $headers -ContentType "application/json"
        
        if($response.tenant.id -eq $TenantID){
             return $_
            
        }

        
    }

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

#Can be used to determine API errors
Function Get-ViPRErrorMsg([AllowNull()][object]$errordata){   
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
    Write-Host -ForegroundColor Red "Possible authentication or IP resolution error."
    
   } 
  
}
