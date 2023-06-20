# Collect & set parameters
$location = Read-Host "Please specify the Azure region to deploy the virtual machine scale set to."
$vnetName = Read-Host "Please specify the name of the virtual network to deploy the virtual machine scale set to."
$randomString = [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)
$vmssName = "vmss-" + $randomString
$rgname = "rg-" + $randomString
$adminUsername = "adminuser"
$adminPassword = Read-Host -Prompt "Enter a secure password for the VMSS Nodes." -AsSecureString

# Get the virtual network by name
$virtualNetwork = Get-AzVirtualNetwork -Name $vnetName

# Check if the virtual network exists before continuing
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

# Set the ipConfig for the VMSS based on the selected subnet

$ipConfig = New-AzVmssIpConfig `
    -Name "ipconfig1" `
    -SubnetId $selectedSubnet.Id

# Create a new virtual machine scale set config object
 
# Create a new virtual machine scale set config object
$vmssConfig = New-AzVmssConfig `
    -Location $location `
    -SkuCapacity 3 `
    -SkuName "Standard_D2s_v5" `
    -UpgradePolicyMode "Automatic" `
    -Zone 1,2,3 `
    -ZoneBalance $true |
    Set-AzVmssStorageProfile `
        -OsDiskCreateOption "FromImage" `
        -OsDiskCaching "ReadWrite" `
        -ImageReferencePublisher "MicrosoftWindowsServer" `
        -ImageReferenceOffer "WindowsServer" `
        -ImageReferenceSku "2022-datacenter" `
        -ImageReferenceVersion "latest" `
        -OsDiskOsType "Windows" |
    Set-AzVmssOsProfile `
        -ComputerNamePrefix 'vmss' `
        -AdminUsername $adminUsername `
        -AdminPassword $adminPassword |
    Add-AzVmssNetworkInterfaceConfiguration `
        -Name "nicconfig1" `
        -Primary $true `
        -IPConfiguration $ipConfig

# Create Resource group and VMSS Instance
New-AzResourceGroup -ResourceGroupName $rgname -Location $location
New-AzVmss `
    -ResourceGroupName $rgname `
    -Name $vmssName `
    -VirtualMachineScaleSet $vmssConfig `
    -Verbose

# Create a load balancer in front of the VMSS

$publicIp = New-AzPublicIpAddress -ResourceGroupName $rgName -Name "vmss-pip-$randomString" -Sku "Standard" -Zone 1,2,3 -AllocationMethod "Static" -Location $location
$frontendIpConfig = New-AzLoadBalancerFrontendIpConfig -Name "lbFrontendIp" -PublicIpAddress $publicIp
$backendPool = New-AzLoadBalancerBackendAddressPoolConfig -Name "vmssBackendPool"
$loadBalancerConfig = New-AzLoadBalancerConfig -Name "lbConfig" -FrontendIpConfiguration $frontendIpConfig -BackendAddressPool $backendPool
$vmssConfig = $vmssConfig | Add-AzVmssLoadBalancerBackendAddressPoolConfig -Name "vmssBackendPool" -LoadBalancerBackendAddressPool $backendPool
$healthProbe = New-AzLoadBalancerProbeConfig -Name "vmssProbe" -Protocol "Tcp" -Port 80 -IntervalInSeconds 15 -NumberOfProbes 4
$loadBalancerConfig = $loadBalancerConfig | Add-AzLoadBalancerProbeConfig -Name "vmssProbe" -LoadBalancerProbe $healthProbe
$loadBalancingRule = New-AzLoadBalancerRuleConfig -Name "vmssRule" -Protocol "Tcp" -FrontendPort 80 -BackendPort 80 -BackendAddressPool $backendPool -Probe $healthProbe
$loadBalancerConfig = $loadBalancerConfig | Add-AzLoadBalancerRuleConfig -Name "lbRule" -LoadBalancerRule $loadBalancingRule
$loadBalancer = New-AzLoadBalancer -ResourceGroupName $rgName -Name "vmss-lb-$randomString" -Location $location -FrontendIpConfiguration $frontendIpConfig -LoadBalancerSku "Standard" -LoadBalancerRules $loadBalancingRule -Probes $healthProbe -BackendAddressPools $backendPool
$vmssConfig = $vmssConfig | Set-AzVmssLoadBalancer -LoadBalancerId $loadBalancer.Id -BackendPoolName "vmssBackendPool"
Update-AzVmss -ResourceGroupName $rgname -VMScaleSetName $vmssName -VirtualMachineScaleSet $vmssConfig

