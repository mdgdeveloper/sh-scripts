# Backup Vault Removal Tool
# Created by: Sergio Madrigal
# UNICEF 2023

# Configuration parameters
$rgBackup = "RG-UCEFDEV-IVANTI" 

$rgBackupInstanRecovery = "RG-UCEFDEV-IVANTI" 

$vaultName = "Ivanti" 

$vault = Get-AzRecoveryServicesVault -ResourceGroupName $rgBackup -Name $vaultName

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Disable soft delete for the Azure Backup Recovery Services vault
## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

Set-AzRecoveryServicesVaultProperty -Vault $vault.ID -SoftDeleteFeatureState Disable
Write-Host ($writeEmptyLine + " # Soft delete disabled for Recovery Service vault " + $vault.Name)

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Check if there are backup items in a soft-deleted state and reverse the delete operation
## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------

$containerSoftDelete = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureWorkload -WorkloadType MSSQL  -VaultId $vault.ID | Where-Object {$_.DeleteState -eq "ToBeDeleted"}
foreach ($item in $containerSoftDelete) {

    Undo-AzRecoveryServicesBackupItemDeletion -Item $item -VaultId $vault.ID -Force -Verbose

}
Write-Host ($writeEmptyLine + "# Undeleted all backup items in a soft deleted state in Recovery Services vault " + $vault.Name)

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Stop protection and delete data for all backup-protected items
## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------


$containerBackup = Get-AzRecoveryServicesBackupItem -BackupManagementType AzureVM -WorkloadType AzureVM -VaultId $vault.ID | Where-Object {$_.DeleteState -eq "NotDeleted"}

foreach ($item in $containerBackup) {
    Disable-AzRecoveryServicesBackupProtection -Item $item -VaultId $vault.ID -RemoveRecoveryPoints -Force -Verbose
}

Write-Host ($writeEmptyLine + "# Deleted backup date for all cloud protected items in Recovery Services vault " + $vault.Name)`

## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
## Delete the Recovery Services vault
## ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------
Remove-AzRecoveryServicesVault -Vault $vault -Verbose

Write-Host ($writeEmptyLine + "# Recovery Services vault " + $vault.Name + " deleted" + $writeSeperatorSpaces + $currentTime)