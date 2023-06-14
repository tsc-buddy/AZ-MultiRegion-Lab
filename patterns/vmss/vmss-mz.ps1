# Collect parameters
$location = read-host "Please provide the Azure Region you wish to deploy the VMSS into."
$vnetName = read-Host "Please provide the name of the Virtual Network you wish to provision the multi-zone VMSS into."

$vmssName = "vmss-" + [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)
$rgname = "rg-" + [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)


# Get the virtual network by name
$virtualNetwork = Get-AzVirtualNetwork -Name $vnetName

# Check if the virtual network exists
if (!$virtualNetwork) {
    Write-Error "Virtual network '$vnetName' not found."
    exit 1
}

# Retrieve the subnets of the virtual network
$subnets = $virtualNetwork.Subnets

# Display the subnet names to the user and prompt for selection
$index = 1
Write-Output "Available Subnets in '$vnetName':"
foreach ($subnet in $subnets) {
    Write-Output "$index. $($subnet.Name)"
    $index++
}

$selectedSubnetIndex = Read-Host "Select the index of the desired Subnet"

# Validate the user input
if ($selectedSubnetIndex -le 0 -or $selectedSubnetIndex -gt $subnets.Count) {
    Write-Error "Invalid selection. Please enter a valid index."
    exit 1
}

# Get the selected subnet and store it in a variable
$selectedSubnet = $subnets[$selectedSubnetIndex - 1]

# Use the selected subnet as needed
Write-Output "Selected Subnet: $($selectedSubnet.Name)"

New-AzResourceGroup -ResourceGroupName $rgname -Location $location

# Create a new virtual machine scale set with three zones

New-AzVmss `
    -ResourceGroupName $rgname `
    -Location $location `
    -VMScaleSetName $vmssName `
    -VirtualNetworkName $vnetName `
    -SubnetName $selectedSubnet.Name `
    -PublicIpAddressName "pip-$vmssName" `
    -LoadBalancerName "lb-$vmssName" `
    -BackendPort 80 `
    -Zone 1,2,3 `
    -SkuName "Standard_DS1_v2" `
    -UpgradePolicyMode "Automatic" `
    -HealthProbeName "healthprobe-$vmssName"