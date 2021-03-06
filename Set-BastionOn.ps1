#requires -Module Az.Network

# Allocates Bastion when remote access is needed.
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
$VNet    = $config.VNet
$PIP     = $config.PIP
$Bastion = $config.Bastion

Write-Host -ForegroundColor Green "Getting things ready."

# make sure the correct tenant and subscription is in use
$azContext = Get-AzContext

if ($Azure.TenantID -ne $azContext.Tenant)
{
    try 
    {
        Set-AzContext -Tenant $Azure.TenantID -EA Stop    
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
        Set-AzContext -SubscriptionId $Azure.SubscriptionID -EA Stop    
    }
    catch 
    {
        return (Write-Error "Failed to connect to the Azure Subscription. Please manually connect [Set-AzContext -SubscriptionId $($Azure.SubscriptionID)] and try again: $_" -EA Stop)
    }
}



# get the vnet
try 
{
    $azVnet = Get-AzVirtualNetwork -ResourceGroupName $VNet.ResourceGroupName -Name $VNet.Name -EA Stop    
}
catch 
{
    return (Write-Error "Failed to find a vnet named $($VNet.Name) in RG $($VNet.ResourceGroupName)`: $_")
}


# make sure there is a Bastion subnet in the vnet
$AzBastionSubnet = $azVnet.Subnets | Where-Object Name -eq "AzureBastionSubnet"

if (-NOT $AzBastionSubnet)
{
    return (Write-Error "Failed to find a subnet named AzureBastionSubnet in VNet $($VNet.Name). Please create the subnet and try again. https://docs.microsoft.com/en-us/azure/bastion/quickstart-host-portal")
}


# test the PIP
try 
{
    $azPIP = Get-AzPublicIpAddress -ResourceGroupName $PIP.ResourceGroupName -Name $PIP.Name -EA Stop
}
catch 
{
    return (Write-Error "Failed to find a public IP address named $($PIP.Name) in RG $($PIP.ResourceGroupName)`: $_")
}


# create the Bastion instance
try 
{
    $bastionSplat = @{
        ResourceGroupName     = $Bastion.ResourceGroupName
        Name                  = $Bastion.Name
        PublicIpAddressRgName = $azPIP.ResourceGroupName
        PublicIpAddressName   = $azPIP.Name
        VirtualNetworkRgName  = $azVnet.ResourceGroupName
        VirtualNetworkName    = $azVnet.Name
        Sku                   = $Bastion.Sku
    }

    Write-Host -ForegroundColor Yellow "Adding Bastion. This will take up to 10+ minutes. Please be patient grasshopper."
    $azBastion = New-AzBastion @bastionSplat
}
catch 
{
    return (Write-Error "Failed to create the Bastion instance: $_")
}

Write-Host -ForegroundColor Green "Bastion has been successfully created. You may not be able to remove Bastion for another 5-10 minutes while the Azure backend updates.`n`nBastion ID: $($azBastion.ID)"
