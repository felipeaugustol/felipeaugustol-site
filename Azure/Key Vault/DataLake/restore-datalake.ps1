# Azure DataLake Gen2 Restore
# Version: 1.0
# Developed by: Felipe Augusto [felipeaugustol.com] | Cloud Solutions Architect 
# Created: 10th November, 2020
# Last Change: 25th November, 2020
#1.1 - Logic consider empty files to restore/backup

Param([Parameter(Mandatory = $true)][String] $rg_sa_backup_src_name,
    [Parameter(Mandatory = $true)][String] $sa_bkp_src_name,
    [Parameter(Mandatory = $true)][String] $rg_sa_restore_dest_name,
    [Parameter(Mandatory = $true)][String] $sa_restore_dest_name,
    [Parameter(Mandatory = $true)][String] $container_name,
    [Parameter(Mandatory = $true)][String] $filerecovery,
    [Parameter(Mandatory = $true)][String] $restore_date)


    

# [FUNCTIONS]
function Get-SAContext {
    param(
        [string]
        [Parameter(Mandatory = $true)]
        $ResourceGroupName,
        [string]
        [Parameter(Mandatory = $true)]
        $StorageAccountName)

    $GetStorageAccount = Get-AzStorageAccount -ResourceGroupName $ResourceGroupName -AccountName $StorageAccountName -ErrorAction SilentlyContinue

    $GetStorageAccountKey = (Get-AzStorageAccountKey -ResourceGroupName $ResourceGroupName -Name $GetStorageAccount.StorageAccountName | Select-Object -first 1).Value

    $GetContext = New-AzStorageContext -StorageAccountName $GetStorageAccount.StorageAccountName -StorageAccountKey $GetStorageAccountKey
    return $GetContext
}

# [SRC_CTX]

#############################SELECT AZ SUBSCRIPTION MISSING


$StorageAccount_Source_Context = Get-SAContext -ResourceGroupName $rg_sa_backup_src_name -StorageAccountName $sa_bkp_src_name


# [DEST_CTX]

$StorageAccount_Destination_Context = Get-SAContext -ResourceGroupName $rg_sa_restore_dest_name -StorageAccountName $sa_restore_dest_name


# [CHECK FILES TO BACKUP BEFORE RESTORE]
$gblob_src = Get-AzStorageAccount -ResourceGroupName $rg_sa_backup_src_name -Name $sa_bkp_src_name | Get-AzStorageContainer -Name $container_name


$Inc = 1
foreach ($src_item in $gblob_src) { 
    $src_item = ( Get-AzStorageAccount -ResourceGroupName $rg_sa_backup_src_name -Name $sa_bkp_src_name | Get-AzStorageContainer -Name $src_item.Name | Get-AzStorageBlob -Blob "$($restore_date)/$($filerecovery)") ;
    $Inc++;
}

if (!$src_item) {
    Write-Host "`nThe restoration point requested doesn't exist..."
    break
}
else {
    Write-Host "`nFiles for restored were found, preparing backup before restore..."
    $filter_src_item = $src_item | Where-Object  { $_.ContentType -ne $NULL -and $_.Length -ge 0 }

    foreach ($item in $filter_src_item) {

        $getdate = Get-Date -Format "dd-MM-yyyy"
        $item_backup_name = $item.name -replace "$restore_date/", ""
        Write-Host "`n Folder name $item_backup_name"

        Start-AzStorageBlobCopy -Context $StorageAccount_Destination_Context -SrcContainer $container_name -SrcBlob $item_backup_name -DestContext $StorageAccount_Source_Context -DestContainer $container_name -DestBlob "$($getdate)-BeforeRestoration/$($item_backup_name)" -Force 
    }
}

##### Restore files

Write-Host "`nBackup before restore complete, starting restore process..."
foreach ($item in $filter_src_item) {

    $getdate = Get-Date -Format "dd-MM-yyyy"
    $item_backup_name = $item.name -replace "$restore_date/", ""
    Write-Host "Folder name $item_backup_name"

    Start-AzStorageBlobCopy -Context $StorageAccount_Source_Context -SrcContainer $container_name -SrcBlob $item.Name -DestContext $StorageAccount_Destination_Context -DestContainer $container_name -DestBlob "$item_backup_name" -Force 
}