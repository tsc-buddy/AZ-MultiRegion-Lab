# Collect parameters
$location = "australiaeast"
$vnetName = "vnet01"

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


$subnetId = $selectedSubnet.Id
$subnetId
$ipConfig = New-AzVmssIpConfig `
    -Name "ipconfig1" `
    -SubnetId $subnetId

# Create a new virtual machine scale set with three zones
 
###########################

$vmssConfig = New-AzVmssConfig `
    -Location $location `
    -SkuCapacity 3 `
    -SkuName "Standard_DS2_v2" `
    -UpgradePolicyMode "Automatic"

    $vmssConfig = $vmssConfig | Set-AzVmssStorageProfile `
    -OsDiskCreateOption "FromImage" `
    -OsDiskCaching "ReadWrite" `
    -ImageReferencePublisher "MicrosoftWindowsServer" `
        -ImageReferenceOffer "WindowsServer" `
        -ImageReferenceSku "2022-datacenter" `
        -ImageReferenceVersion "latest" `
        -OsDiskOsType "Windows"

    $vmssConfig = $vmssConfig |Set-AzVmssOsProfile `
    -ComputerNamePrefix 'vmss' `
    -AdminUsername ''`
    -AdminPassword '' 

    $vmssConfig = $vmssConfig | Add-AzVmssNetworkInterfaceConfiguration `
    -Name "nicconfig1" `
    -Primary $true `
    -IPConfiguration $ipConfig 

New-AzResourceGroup -ResourceGroupName $rgname -Location $location
New-AzVmss `
    -ResourceGroupName $rgname `
    -Name $vmssName `
    -VirtualMachineScaleSet $vmssConfig `
    -Verbose