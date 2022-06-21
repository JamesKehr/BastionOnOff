#requires -Module Az.Network

# Deallocates Bastion to prevent billing
# This script assumes the networking portion is pre-staged. It will not create the vnet or subnets.

[CmdletBinding()]
param (
    [Parameter()]
    [string]
    $BastionConfig = ".\Bastion.conf.json"
)


# read the config file
$config = Get-Content "$BastionConfig" | ConvertFrom-Json
$Azure   = $config.Azure
#$VNet    = $config.VNet
#$PIP     = $config.PIP
$Bastion = $config.Bastion


Write-Host -ForegroundColor Green "Getting things ready."

# make sure the correct tenant and subscription is in use
$azContext = Get-AzContext

if ($Azure.TenantID -ne $azContext.Tenant)
{
    try 
    {
        $null = Set-AzContext -Tenant $Azure.TenantID -EA Stop    
    }
    catch 
    {
        return (Write-Error "Failed to connect to the Azure Tenant. Please manually connect [Set-AzContext -Tenant $($Azure.TenantID)] and try again: $_" -EA Stop)
    }
}

if ($Azure.SubscriptionID -ne $azContext.Subscription)
{
    try 
    {
        $null = Set-AzContext -SubscriptionId $Azure.SubscriptionID -EA Stop    
    }
    catch 
    {
        return (Write-Error "Failed to connect to the Azure Subscription. Please manually connect [Set-AzContext -SubscriptionId $($Azure.SubscriptionID)] and try again: $_" -EA Stop)
    }
}


# get the bastion instance
try 
{
    $azBastion = Get-AzBastion -ResourceGroupName $Bastion.ResourceGroupName -Name $Bastion.Name -EA Stop
}
catch 
{
    return (Write-Error "Failed to find a Bastion instance in the RG $($Bastion.ResourceGroupName)`: $_")
}

# remove it
try
{
    Write-Host -ForegroundColor Yellow "Removing Bastion. This will take several minutes. Please be patient grasshopper."
    $null = Remove-AzBastion -ResourceGroupName $azBastion.ResourceGroupName -Name $azBastion.Name -Force -EA Stop
}
catch 
{
    return (Write-Error "Failed to remove the Bastion instance: $_")
}

Write-Host -ForegroundColor Green "Bastion has been successfully removed. You may not be able to add Bastion back for another 5-10 minutes while the Azure backend does cleanup."
