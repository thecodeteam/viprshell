[CmdletBinding()]

$viprmodulelocation = "C:\code\viprshell"

Import-Module $viprmodulelocation -Verbose

#This section defines variables - long term some persistence layer/SQL/PS will handle this - or you can add parameters to this script and load them in from somewhere else.
$ProxyUsername = "proxyuser"
$ProxyUserPassword = "Password1!"
$TokenPath = "C:\vipr\tokens"
$VolumeToBeSnapped = "Volume_Name"
$MountHost = "Mount_Host_Name"
$SnapshotName = "Snap_Name"
$SnapHLU = "-1"
$TenantName = "Tenant_Name"
$ProjectName = "Project_Name"
$ViprIP = "10.4.44.6"
$StorageType = "Exclusive"


###Take the snapshot
$order = New-ViPRSnapshot-Order -ViprIP $ViprIP -VolumeName $VolumeToBeSnapped -SnapshotName $SnapshotName -TokenPath $TokenPath -TenantName $TenantName -ProjectName $ProjectName -Verbose


###Monitor the status, wait until it's no longer running
$status = "Running"

While($status -eq "Running"){
  $progress = (Get-ViPROrderStatus -ViprIP $ViprIP -OrderID $order.execution_window.id -TokenPath $TokenPath)
  $status = $progress.execution_status
  $task = $progress.current_task
  Write-Verbose "Current Status: $status"
  Write-Verbose "Current Task: $task" 
  Start-Sleep -Seconds 5
}
###Get the order, should return all of the things we need including the final status and new resource IDs


###Once complete, Map to target
Export-ViPRSnapshot-Order -ViprIP $ViprIP -SnapshotName $SnapshotName -TokenPath $TokenPath -HostName $MountHost -TenantName $TenantName -ProjectName $ProjectName -HLU $SnapHLU -StorageType $StorageType -Verbose


###Monitor the status, wait until it's no longer running
$status = "Running"

While($status -eq "Running"){
  $progress = (Get-ViPROrderStatus -ViprIP $ViprIP -OrderID $order.execution_window.id -TokenPath $TokenPath)
  $status = $progress.execution_status
  $task = $progress.current_task
  Write-Verbose "Current Status: $status"
  Write-Verbose "Current Task: $task" 
  Start-Sleep -Seconds 5
}
###Get the order, should return all of the things we need including the final status and new resource IDs