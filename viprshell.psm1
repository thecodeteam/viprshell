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
Function New-ViPRProxyToken{

<#
     .DESCRIPTION
      Creates a ViPR Proxy Token for a particular user which can be used in scripting. Typically done once. More info here: https://www.emc.com/techpubs/vipr/run_rest_api_script_proxy_user-1.htm

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Username
      Username used to login to ViPR

      .PARAMETER $Password
      Password used to login to ViPR

      .PARAMETER $ProxyUsername
      Username of the proxy user in ViPR. Today, proxyuser is the default and can not be changed

      .PARAMETER $ProxyPassword
      Password of the proxy user in ViPR

      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      New-ViPRProxyToken -ViprIP 10.1.1.20 -Username root -Password changeme -ProxyUsername proxyuser -ProxyPassword p@ssw0rd! -TokenPath C:\temp\tokens

  #>
[Cmdletbinding()]

Param(
  [string]$ViprIP,
  [string]$Username,
  [string]$Password,
  [string]$ProxyUsername,
  [string]$ProxyPassword,
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

<#
     .DESCRIPTION
      Authenticates and creates proxyuser authentication token used for subsequent calls. This expires after ~8 hours. More info here: https://www.emc.com/techpubs/vipr/run_rest_api_script_proxy_user-1.htm

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $ProxyUsername
      Username of the proxy user in ViPR. Today, proxyuser is the default and can not be changed

      .PARAMETER $ProxyUserPassword
      Password of the proxy user in ViPR

      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      New-ViPRProxyUserAuthToken -ViprIP 10.1.1.20 -ProxyUsername proxyuser -ProxyUserPassword p@ssw0rd! -TokenPath C:\temp\tokens

  #>
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

<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Tenant

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Name
      Name of the tenant 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprTenant -ViprIP 10.1.1.20 -Name "Provider Tenant" -TokenPath C:\temp\tokens

  #>
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
    
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "$Name"
                    }
                    
                    $uri = "https://"+$ViprIP+":4443/tenants/$id"

                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

                Get-ViPRErrorMsg -errordata $result
            }

    $result
}

Function Get-ViPRProject{

<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Project

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Name
      Name of the project 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprTenant -ViprIP 10.1.1.20 -Name Project123 -TokenPath C:\temp\tokens

  #>
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
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "$Name"
                    }
                    
                    $uri = "https://"+$ViprIP+":4443/projects/$id"

                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

                Get-ViPRErrorMsg -errordata $result
            }

         $result

 
}


####Compute Services####
Function Get-ViPRHost{
<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Host

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Name
      Name of the host
      
      .PARAMETER $HostType
      Type of Host. Either cluster or standalone - used to determine which endpoint to look for the host in.  
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprHost -ViprIP 10.1.1.20 -Name host123 -HostType Standalone -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$Name,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [ValidateSet('Cluster','Standalone')]
  [string]$HostType
)
    if($HostType -eq 'Standalone'){
    $uri = "https://"+$ViprIP+":4443/compute/hosts/search?name=$Name"
    }
    else{
    $uri = "https://"+$ViprIP+":4443/compute/clusters/search?name=$Name"
    }


        $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
        $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
        $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
        
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "$Name"
                    }
                    
                    if($HostType -eq 'Standalone'){
                    $uri = "https://"+$ViprIP+":4443/compute/hosts/$id"
                    }
                    else{
                    $uri = "https://"+$ViprIP+":4443/compute/clusters/$id"
                    }
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

                Get-ViPRErrorMsg -errordata $result
            }

         $result
 
}


Function Get-ViprExportGroup{

<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Export Group. Currently relies on a Snapshot Name to ensure correct groups are returned, soon will also include Volume Names. 

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $HostName
      Name of the host 

      .PARAMETER $SnapshotName
      Name of the snapshot that an export must contain. Because hosts can have many export groups, we are looking for only those that contain the correct snapshots/volumes. 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprExportGroup -ViprIP 10.1.1.20 -HostName host123 -SnapshotName snapshot123 -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$HostName,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

    $uri = "https://"+$ViprIP+":4443/block/exports/search?name=$HostName"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                    $numexports = ($response.resource.count)   
                    $snapshot = Get-ViPRSnapshot -ViprIP $ViprIP -Name $SnapshotName -TokenPath $TokenPath
                    $snapshotid = $snapshot.id
                    
                    if($snapshot.code){
                    
                      return $snapshot
                    }  
                           
                           
                            $found = $null
                            $exports = @()

                            foreach ($export in $response.resource){
                                $exportid = $export.id 
                            
                                $uri = "https://"+$ViprIP+":4443/block/exports/$exportid"
                            
                                $exportdata = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                        
                                $exportvolumes = $exportdata.volumes.id
                                $containsvolume = $exportvolumes.Contains($snapshotid)
                            
                                #add export object to the exports array if it contains the snapshot we're looking for
                                if($containsvolume){
                                  $found = $true
                                  $exports += $exportdata
                                  
                                  
                                }
                            }

                            #this returns an error code
                            if(!$found){
                               $uri = "https://"+$ViprIP+":4443/block/exports/$HostName"

                               Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                            }
                            else{
                               #return the list of exports
                               $exports


                            }
                  
                }
            catch{
                
                Get-ViPRErrorMsg -errordata $result
            }

         $result
   
}


####Block Services####
Function Get-ViPRVolume{

<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Volume

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Name
      Name of the volume 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprVolume -ViprIP 10.1.1.20 -Name Volume123 -TokenPath C:\temp\tokens

  #>
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
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "$Name"
                    }
                    
                    $uri = "https://"+$ViprIP+":4443/block/volumes/$id"

                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

               Get-ViPRErrorMsg -errordata $result
            }

         $result
}

#Returns array of Volume objects 
Function Get-ViPRVolumes{

<#
     .DESCRIPTION
      Retrieves all IDs of ViPR Volumes

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprVolumes -ViprIP 10.1.1.20 -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)
    
    $uri = "https://"+$ViprIP+":4443/block/volumes/bulk"

    
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
   
    $result = try{  
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"  
                    $response 
                    
                }
              catch{
                
                    Get-ViPRErrorMsg -errordata $result

              }
    $result
 }

#Gets Tags for a Volume
Function Get-ViPRVolumeTags{

<#
     .DESCRIPTION
      Retrieves tags for a ViPR Volume

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $VolumeName
      Name of the volume 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprVolumeTags -ViprIP 10.1.1.20 -VolumeName Volume123 -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$VolumeName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

  
  

    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    
    $result = try{  
                    $VolumeID = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName).id
                    $uri = "https://"+$ViprIP+":4443/block/volumes/$VolumeID/tags"
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                    $response
                }
               catch{
                    Get-ViPRErrorMsg -errordata $result
               }
    $result
}

#Gets Tags for a Snapshot
Function Set-ViPRVolumeTag{

<#
     .DESCRIPTION
      Adds or Removes a tag for a ViPR Volume

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $VolumeName
      Name of the volume 

      .PARAMETER $Tag
      Tag that you want to be removed or added

      .PARAMETER $Action
      Tells the function to either add or remove the given tag
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Set-ViprVolumetag -ViprIP 10.1.1.20 -VolumeName Volume123 -Tag testtag -Action Add -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$VolumeName,
  [Parameter(Mandatory=$true)]
  [string]$Tag,
  [Parameter(Mandatory=$true)]
  [ValidateSet('Add','Remove')]
  [string]$Action,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

  $result = try{
                  $VolumeID = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName).id
                  $uri = "https://"+$ViprIP+":4443/block/volumes/$VolumeID/tags"
                  if($Action -eq 'Add'){
     
                      $jsonbody = '
                       {
                        "add": [
                          "'+$Tag+'"
                        ]
                      }'
                  }
                  elseif($Action -eq 'Remove'){
                      $jsonbody = '
                       {
                        "remove": [
                          "'+$Tag+'"
                        ]
                      }'

                  }
                    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
                    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
                    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
                    if($VolumeID){
                        $response = Invoke-RestMethod -Uri $uri -Method PUT -Body $jsonbody -Headers $headers -ContentType "application/json"
                        $response
                    }
                  }
            catch{
              Get-ViPRErrorMsg -errordata $result
            }
    $result
}

####Snapshot Services####
#Gets Snapshot information based on a name 
Function Get-ViPRSnapshot{

<#
     .DESCRIPTION
      Retrieves information about a particular ViPR Snapshot

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $Name
      Name of the Snapshot
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprSnapshot -ViprIP 10.1.1.20 -Name Volume123 -TokenPath C:\temp\tokens

  #>
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
    $result = try{ 
    
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
        
                    $id = ($response.resource | Where match -eq $Name | Select).id

                     #Uses bogus ID if no match was found to trigger error
                    if(!$id){
                    $id = "$Name"
                    }
                    
                    $uri = "https://"+$ViprIP+":4443/block/snapshots/$id"

                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                }
            catch{

                Get-ViPRErrorMsg -errordata $result
            }

         $result

}

#Gets all snapshots related to a parent volume
Function Get-ViPRSnapshotsByParent{

<#
     .DESCRIPTION
      Retrieves all children snapshots of a given parent volume

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $ParentVolumeName
      Name of the Snapshot
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprSnapshotsByParent -ViprIP 10.1.1.20 -ParentVolumeName Volume123 -TokenPath C:\temp\tokens

  #>
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
  
  $result = try {   
                    
                    $parentvolume = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $ParentVolumeName)
                    
                    $uri = "https://"+$ViprIP+":4443/block/snapshots/bulk"
                    
    
                    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
                    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
                    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
                    
                   if($parentvolume){
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                    $snapshots = ($response.id) -split " "
                    Write-Output $snapshots
                    
                     $snapshots | ForEach{ 
                        $id = $_
                        $uri = "https://"+$ViprIP+":4443/block/snapshots/$id"
                        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                        if($response.parent.id -eq $parentvolume.id){
                        $relatedsnaps += $response
                        }
                    }

                    $relatedsnaps
                    }
                }
            
            catch{

                Get-ViPRErrorMsg -errordata $result
            }
    $result

}

#Gets Tags for a Snapshot
Function Get-ViPRSnapshotTags{

<#
     .DESCRIPTION
      Retrieves tags for a ViPR Snapshot

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $SnapshotName
      Name of the volume 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprSnapshotTags -ViprIP 10.1.1.20 -VolumeName Volume123 -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

     
    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
    $result = try{  
                    
                    $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
                    $uri = "https://"+$ViprIP+":4443/block/snapshots/$SnapshotID/tags"
                    if($SnapshotID){
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                    $response
                    }
                }
               catch{
                    Get-ViPRErrorMsg -errordata $result
               }
    $result

}

#Gets Tags for a Snapshot
Function Set-ViPRSnapshotTag{

<#
     .DESCRIPTION
      Adds or Removes a tag for a ViPR Snapshot

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $VolumeName
      Name of the volume 

      .PARAMETER $Tag
      Tag that you want to be removed or added

      .PARAMETER $Action
      Tells the function to either add or remove the given tag
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Set-ViprSnapshotTag -ViprIP 10.1.1.20 -SnapshotName Volume123 -Tag testtag -Action Add -TokenPath C:\temp\tokens

  #>
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

  
  $result = try{
                  $SnapshotID = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName).id
                  $uri = "https://"+$ViprIP+":4443/block/snapshots/$SnapshotID/tags"
                  if($Action -eq 'Add'){
     
                      $jsonbody = '
                       {
                        "add": [
                          "'+$Tag+'"
                        ]
                      }'
                  }
                  elseif($Action -eq 'Remove'){
                      $jsonbody = '
                       {
                        "remove": [
                          "'+$Tag+'"
                        ]
                      }'

                  }
                    $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
                    $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
                    $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }
                    if($SnapshotID){
                        $response = Invoke-RestMethod -Uri $uri -Method PUT -Body $jsonbody -Headers $headers -ContentType "application/json"
                        $response
                    }
                  }
            catch{
              Get-ViPRErrorMsg -errordata $result
            }
    $result

}

###Returns all exports for a given snapshot name###
Function Get-ViPRSnapshotExports{

<#
     .DESCRIPTION
      Retrieves exports for a ViPR Snapshot

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $SnapshotName
      Name of the volume 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprSnapshotExports -ViprIP 10.1.1.20 -SnapshotName Volume123 -TokenPath C:\temp\tokens

  #>
[CmdletBinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath,
  [Parameter(Mandatory=$true)]
  [string]$SnapshotName
)

        $result = try{

                        $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                        $SnapshotID = $Snapshot.id

                        if($Snapshot.code){
                            return $Snapshot

                        }

                        $uri = "https://"+$ViprIP+":4443/block/snapshots/$SnapshotID/exports"
                           
                        $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
                        $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
                        $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

                        $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"
                        $response


        }
        catch{

            Get-ViPRErrorMsg -errordata $result

        }
  $result



}
####UI Services - Order####

#Returns the order information given an order ID which will show status 
Function Get-ViPROrder{

<#
     .DESCRIPTION
      Retrieves the status for an order

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $ID
      Order ID. Typically returned after executing an order.  
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprOrder -ViprIP 10.1.1.20 -ID 1ladkj4310834alakf -TokenPath C:\temp\tokens

  #>
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
    
    $result = try {
                    $response = Invoke-RestMethod -Uri $uri -Method GET -Headers $headers -ContentType "application/json"

                    $response
                 }
              catch{

                Get-ViPRErrorMsg -errordata $result

              }
    $result

}
Function New-ViPRSnapshot-Order{

<#
     .DESCRIPTION
      Executes the Snapshot Order as seen in ViPR GUI. Takes a snapshot of a given volume and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $VolumeName
      Name of the volume that you want to take a snapshot of
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      New-ViprSnapshotOrder -ViprIP 10.1.1.20 -VolumeName parentvolume123 -SnapshotName snapshot123 -TenantName "Provider Tenant" -ProjectName testproject -TokenPath C:\temp\tokens

  #>
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
 
 $result = try { 
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }

                 if($TenantID){
                 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "CreateBlockSnapshot").id
                 }

                 $Volume = (Get-ViPRVolume -TokenPath $TokenPath -ViprIP $ViprIP -Name $VolumeName)
                 $VolumeID = $Volume.id

                 if($Volume.code){
                     return $Volume
                    }
                 
                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id

                 if($Project.code){
                    return $Project
                 }
 

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

                    


                   if($TenantID -and $VolumeID -and $CatalogID -and $ProjectID){
                     $response = (Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json")
                     $response
                     }
                    
                    
               }
            catch{
                
                
                Get-ViPRErrorMsg -errordata $result
                
            }
    $result

}

Function Remove-ViprSnapshot-Order{

<#
     .DESCRIPTION
      Executes the Remove Snapshot Order as seen in ViPR GUI. Removes a snapshot and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Remove-ViprSnapshot-Order -ViprIP 10.1.1.20 -SnapshotName snapshot123 -TenantName "Provider Tenant" -ProjectName testproject -TokenPath C:\temp\tokens

  #>
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
 
 $result = try {
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }

                 if($TenantID){
                    $CatalogID = (Get-ViPRCatalogService -TokenPath $TokenPath -TenantID $TenantID -ViprIP $ViprIP -Name "RemoveBlockSnapshot").id
                 }
                 
                 $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                 $SnapshotID = $Snapshot.id

                 if($Snapshot.code){
                   return $Snapshot

                 }

                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id
                

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
                    if($TenantID -and $ProjectID -and $SnapshotID -and $CatalogID){
                         $response = (Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json")
                         $response
                    }
                    
               }
            catch{

              Get-ViPRErrorMsg -errordata $result
            }
    $result
}

Function Export-ViPRSnapshot-Order{
<#
     .DESCRIPTION
      Executes the Export Snapshot Order as seen in ViPR GUI. Exports snapshot to a given host and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $HostName
      Name of the host you would like to export the snapshot to
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating

      .PARAMETER $HLU
      HLU the exported volume should be assigned to on the host. Use -1 for the next available. 
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Export-ViPRSnapshot-Order -ViprIP 10.1.1.20 -SnapshotName snapshot123 -TenantName "Provider Tenant" -ProjectName testproject -TokenPath C:\temp\tokens

  #>
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
  if($StorageType -eq 'exclusive'){
  $HostType = 'Standalone'
  }
  else{
  $HostType = 'Cluster'
  }
  $result = try {
                 
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }


                 if($TenantID){
                 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "ExportSnapshottoaHost").id
                 }

                 $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                 $SnapshotID =$Snapshot.id


                 if($Snapshot.code){
                    return $Snapshot
                 }
                 

                 $Host = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName -HostType $HostType)
                 $HostID = $Host.id

                 if($Host.code){

                    return $Host
                 }
                 
                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id

                 if($Project.code){

                    return $Project
                 }
 

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
                    if($HostID -and $ProjectID -and $SnapshotID -and $TenantID -and $CatalogID){
                        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
                        $response
                    }
                    
                }
           catch{

                Get-ViPRErrorMsg -errordata $result
           }
    $result
    
}

Function Unexport-ViPRSnapshot-Order{

<#
     .DESCRIPTION
      Executes the Unexport Snapshot Order as seen in ViPR GUI. Unexports a given snapshot from a host and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $HostName
      Name of the host you would like to export the snapshot to
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Unexport-ViPRSnapshot-Order -ViprIP 10.1.1.20 -SnapshotName snapshot123 -HostName host1234 -TenantName "Provider Tenant" -ProjectName testproject -TokenPath C:\temp\tokens

  #>
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
 $result = try {
                 
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }
                 
                 if($TenantID){
                 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "UnexportSnapshot").id
                 }
                 
                 $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                 $SnapshotID = $Snapshot.id

                 if($Snapshot.code){

                    return $Snapshot
                 }

                 $ExportList = (Get-ViprExportGroup -TokenPath $TokenPath -ViprIP $ViprIP -HostName $HostName -SnapshotName $SnapshotName)
                 

                 if($ExportList.code){

                    return $ExportList
                 }

                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id
 

                 $uri = "https://"+$ViprIP+":4443/catalog/orders"
                 $orderlist = @()
                 
                 #do this once for each export in the list
                 foreach($Export in $ExportList){
                 $ExportID = $Export.id
                
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
                    
                    if($TenantID -and $ExportID -and $ProjectID -and $SnapshotID -and $CatalogID){
                        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
                        $orderlist += $response
                    }
                    
                }

                if($TenantID -and $ExportID -and $ProjectID -and $SnapshotID -and $CatalogID){
                        #return the array of export order objects
                        $orderlist
                   }
          }
          catch {

            Get-ViPRErrorMsg -errordata $result
          }
    $result

}

Function Mount-ViPRWindowsVolume-Order{
<#
     .DESCRIPTION
      Executes the Mount Windows Volume Order as seen in ViPR GUI. Mounts a snapshot to a Windows host and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $HostName
      Name of the host you would like to export the snapshot to
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating

      .PARAMETER $StorageType
      Sets the type of storage. Set 'exclusive' for standalone hosts, or 'shared' for shared volumes.
      
      .PARAMETER $PartitionType
      Set to gpt or mbr
      
      .PARAMETER $FileSystemType
      Set to NTFS or FAT32
      
      .PARAMETER $DriveLabel
      Optional. Sets a label for the snapshot mounted to the Windows Host
      
      .PARAMETER $MountPoint
      Optional. Sets a mount point for the snapshot mounted to the Windows Host  
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Mount-ViPRWindowsVolume-Order -ViprIP 10.1.1.20 -SnapshotName snapshot123 -TenantName "Provider Tenant" -ProjectName testproject -StorageType exclusive -PartitionType gpt -FileSystemType ntfs -TokenPath C:\temp\tokens

  #>
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

if($StorageType -eq 'exclusive'){
  $HostType = 'Standalone'
  }
  else{
  $HostType = 'Cluster'
  }

  $result = try {
                 
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }


                 if($TenantID){
                    $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "MountVolumeOnWindows").id
                 }

                 $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                 $SnapshotID = $Snapshot.id

                 if($Snapshot.code){
                    return $Snapshot
                 }

                 $Host = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName -HostType $HostType)
                 $HostID = $Host.id

                 if($Host.code){
                    return $Host
                 }

                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id

                 if($Project.code){
                    return $Project
                 }
                

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
                    if($ProjectID -and $CatalogID -and $TenantID -and $HostID -and $SnapshotID){
                        $response = Invoke-RestMethod -Uri $uri -Method POST -Body $jsonbody -Headers $headers -ContentType "application/json"
                        $response
                    }
                    
               }
        catch{
            
            Get-ViPRErrorMsg -errordata $result

        }
   $result
    
}

Function Unmount-ViPRWindowsVolume-Order{

<#
     .DESCRIPTION
      Executes the Export Snapshot Order as seen in ViPR GUI. Takes a snapshot of a given volume and returns an order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $HostName
      Name of the host you would like to export the snapshot to
      
      .PARAMETER $SnapshotName
      Name of the snapshot you will be creating

      .PARAMETER $StorageType
      Type of storage the Snapshot is. Set 'exclusive' for standalone host, or 'shared' for shared/cluster. 
      
      .PARAMETER $TenantName
      Name of the Vipr Tenant that is executing the Snapshot Order
      
      .PARAMETER $ProjectName
      Name of the Project the snapshot will belong to 
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Unmount-ViPRWindowsVolume-Order -ViprIP 10.1.1.20 -SnapshotName snapshot123 -TenantName "Provider Tenant" -ProjectName testproject -StorageType exclusive -TokenPath C:\temp\tokens

  #>
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

if($StorageType -eq 'exclusive'){
  $HostType = 'Standalone'
  }
  else{
  $HostType = 'Cluster'
  }
                
   $result = try {           
                 
                 $Tenant = (Get-ViPRTenant -TokenPath $TokenPath -ViprIP $ViprIP -Name $TenantName)
                 $TenantID = $Tenant.id

                 if($Tenant.code){
                    return $Tenant
                 }

                 if($TenantID){
                 $CatalogID = (Get-ViPRCatalogService -TenantID $TenantID -TokenPath $TokenPath -ViprIP $ViprIP -Name "UnmountVolumeOnWindows").id
                 }

                 $Snapshot = (Get-ViPRSnapshot -TokenPath $TokenPath -ViprIP $ViprIP -Name $SnapshotName)
                 $SnapshotID = $Snapshot.id

                 if($Snapshot.code){
                    return $Snapshot
                 }

                 $Host = (Get-ViPRHost -TokenPath $TokenPath -ViprIP $ViprIP -Name $HostName -HostType $HostType)
                 $HostID = $Host.id

                 if($Host.code){
                    return $Host
                 }

                 $Project = (Get-ViPRProject -TokenPath $TokenPath -ViprIP $ViprIP -Name $ProjectName)
                 $ProjectID = $Project.id

                 if($Project.code){
                    return $Project
                 }
                 

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
        catch {
            
            Get-ViPRErrorMsg -errordata $result

        }
    $result
    
}

#Checks order status until it has a successful or failure state, then returns the order information
Function Get-ViPROrderStatus{

<#
     .DESCRIPTION
      Takes an Order ID returned from an Order function and looks up the status in a loop until the order has either failed or completed. Returns the final order object.  

      .PARAMETER $ViprIP
      IP Address or hostname for ViPR Instance

      .PARAMETER $OrderID
      ID of the order to track
   
      .PARAMETER $TokenPath
      Directory where token files will be stored. These are used for all commands in this module

      .EXAMPLE
      Get-ViprOrderStatus -ViprIP 10.1.1.20 -OrderID 1a234adflkajaldfj -TokenPath C:\temp\tokens

  #>
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
      $summary = $progress.summary
      $parameters = $progress.parameters
      $date = Get-Date -Format s
      Write-Verbose "$date Currently Executing: $summary"
      Write-Verbose "$date Current Status: $status"
  
      Start-Sleep -Seconds 5
    }
    $ordernumber = $progress.order_number
    ###Get the order, should return all of the things we need including the final status and new resource IDs
    If($status -eq "FAILED" -or $status -eq "ERROR"){
        $date = Get-Date -Format s
        $message = $progress.message
        Write-Verbose "$date ERROR: $summary failed for Order Number $ordernumber - ID $OrderID"
        Write-Verbose "$date ERROR: $message"
        Get-ViPROrder -ViprIP $ViprIP -ID $OrderID -TokenPath $TokenPath
    }
    else{

    #Return the order, it completed
    $date = Get-Date -Format s
    Write-Verbose "$date $summary Completed Successfuly for Order Number $ordernumber - ID $OrderID "
    Get-ViPROrder -ViprIP $ViprIP -ID $OrderID -TokenPath $TokenPath
    }
    
}

####Cancels ViPR Order####
Function Stop-ViPROrder{
[Cmdletbinding()]
Param(
  [Parameter(Mandatory=$true)]
  [string]$ViprIP,
  [Parameter(Mandatory=$true)]
  [string]$OrderID,
  [Parameter(Mandatory=$true)]
  [string]$TokenPath
)

          $result = try{

                $uri = "https://"+$ViprIP+":4443/catalog/orders/$OrderID/cancel"
                $authtoken = Get-Content -Path "$TokenPath\viprauthtoken.txt"
                $proxytoken = Get-Content -Path "$TokenPath\viprproxytoken.txt"
                $headers = @{ "X-SDS-AUTH-PROXY-TOKEN"=$proxytoken; "X-SDS-AUTH-TOKEN"=$authtoken; "Accept"="Application/JSON" }

                $response = Invoke-RestMethod -Uri $uri -Method POST -Headers $headers -ContentType "application/json"
        
                $response

          }
          catch{


            Get-ViPRErrorMsg -errordata $result

          }

  $result 


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
    
    $result = try{
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
            catch{

                Get-ViPRErrorMsg -errordata $result

            }
    $result

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
    $errorcontent = $responseBody
    $errormsg = $errorcontent | ConvertFrom-Json
    
   Write-Error $errorcontent
   $errormsg
    
    
    }
   catch{
    $catchall = '
    { "code" : "404",
      "description" : "Catch all",
      "details": "Possible IP resolution or HTTP error"
    }'
    
    return $catchall | ConvertFrom-Json
    
   } 
  
}
