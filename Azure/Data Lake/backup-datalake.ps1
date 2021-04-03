# Azure DataLake Gen2 Backup
# Version: 1.7
# Developed by: Felipe Augusto [felipeaugustol.com] | Cloud Solutions Architect 
# Created: 17th Sep, 2020
# Last Change: 13th January, 2021
# 1.1 - Create backup and cleanup logic routine - Felipe Augusto
# 1.2 - Set attribute on backup folders - Felipe Augusto
# 1.3 - Copy data even if file is empty - Felipe Augusto
# 1.4 - Refactored logic to ignore folders and more verbose output between tasks - Felipe Augusto
# 1.5 - Refactored compare logic using foreach-object instead foreach for parallel jobs
# 1.6 - Refactored destination filter to decrease time processing
# 1.7 - Refactored source logic, getting only files from previous day.


Param([Parameter(Mandatory = $true)][String] $rg_sa_src_name,
	[Parameter(Mandatory = $true)][String] $sa_src_name,
	[Parameter(Mandatory = $true)][String] $rg_sa_dest_name,
	[Parameter(Mandatory = $true)][String] $sa_dest_name,
	[Parameter(Mandatory = $true)][String] $container_name)



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

Write-Output "`nStarting backup routine..."
# [SRC_CTX]


Write-Output "`nGetting source and destination storage account context..."

$StorageAccount_Source_Context = Get-SAContext -ResourceGroupName $rg_sa_src_name -StorageAccountName $sa_src_name


# [DEST_CTX]

$StorageAccount_Destination_Context = Get-SAContext -ResourceGroupName $rg_sa_dest_name -StorageAccountName $sa_dest_name

# SOURCE STORAGE ACCOUNT #
Write-Output "`nListing current data on source and destination storage account..."

$gblob_src = Get-AzStorageAccount -ResourceGroupName $rg_sa_src_name -Name $sa_src_name | Get-AzStorageContainer -Name $container_name | Get-AzStorageBlob
# DESTINATION STORAGE ACCOUNT #

$checkgblob_dest = Get-AzStorageAccount -ResourceGroupName $rg_sa_dest_name -Name $sa_dest_name | Get-AzStorageContainer -Name $container_name
if (!$checkgblob_dest) {
	Get-AzStorageAccount -ResourceGroupName $rg_sa_dest_name -Name $sa_dest_name | New-AzStorageContainer -Name $container_name
}

$gblob_dest = Get-AzStorageAccount -ResourceGroupName $rg_sa_dest_name -Name $sa_dest_name | Get-AzStorageContainer -Name $container_name | Get-AzStorageBlob
$filter_gblob_dest = $gblob_dest | Sort-Object -Property LastModified -Descending

# [COMPARE AND COPY PROCESS]
Write-Output "`nComparing data on source and destination storage account..."
$getdate = Get-Date -Format "dd-MM-yyyy"
$get_yesterday_date = (Get-Date).AddDays(-1)
$filter_src_item = $gblob_src | Where-Object { $_.Length -gt 0 -and $_.Name.EndsWith -ne '.***' } | Where-Object {$_.LastModified -gt $get_yesterday_date }

Write-Output "`nBackup in process..."
$filter_src_item | ForEach-Object -parallel  {
	$src_item = $_
	$dest_items = $using:filter_gblob_dest | Where-Object {$_.Name.EndsWith($src_item.Name) } 
	Write-Output "Processing File... $($src_item.Name)"
	if ($NULL -eq $dest_items -or $dest_items.LastModified -lt $src_item.LastModified) {
		Write-Host "`n$($src_item.Name) is different or don't exist, backup in process..." -ForegroundColor Green
		Start-AzStorageBlobCopy -Context $using:StorageAccount_Source_Context -SrcContainer $using:container_name -SrcBlob $src_item.Name -DestContext $using:StorageAccount_Destination_Context -DestContainer $using:container_name -DestBlob "$($using:getdate)/$($src_item.Name)" -Force
	}
}
Write-Host "Backup routine finished..." -ForegroundColor Yellow
Write-Output "#############################################################################"


###### Cleanup routine

$delete_backup_date = (Get-Date).AddDays(-31)

Write-Output "`nChecking if any Backups is older than 30 days..."

$checking_date = Get-AzStorageBlob -Container $container_name -Context $StorageAccount_Destination_Context -Blob * | Where-Object { $_.Name.Length -eq 10 -and [datetime]::ParseExact($_.Name, "dd-MM-yyyy", [Globalization.CultureInfo]::CreateSpecificCulture('en-GB')) -le $delete_backup_date }

if (!$checking_date) {
	Write-Output "The script did not find any backup older than 30 days... Ending cleanup routine..."
}
else {
	Write-Output "The script found backup older than 30 days... Starting cleanup routine..."
	foreach ($checking_dates in $checking_date.Name) {
		Write-Output "Cleanup routine starting on $($checking_dates) date..."
		$delete_backup_blob	= Get-AzStorageBlob -Container $container_name -Context $StorageAccount_Destination_Context -Blob "$($checking_dates)/*"
		$delete_backup_blob = $delete_backup_blob.Name | Sort-Object { ($_.ToCharArray() | Where-Object { $_ -eq "/" } | Measure-Object).Count } -Descending
		foreach ($current_blob in $delete_backup_blob) {
			Get-AzStorageBlob -Container $container_name -Context $StorageAccount_Destination_Context -Blob "$($current_blob)" | Remove-AzStorageBlob
		}
		Get-AzStorageBlob -Container $container_name -Context $StorageAccount_Destination_Context -Blob "$($checking_dates)" | Remove-AzStorageBlob
	}
}