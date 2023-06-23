# Collect & set parameters
$location = Read-Host "Please specify the Azure region to deploy the virtual machine scale set to."
$vnetName = Read-Host "Please specify the name of the virtual network to deploy the virtual machine scale set to."
$randomString = [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)
$vmssName = "vmss-" + $randomString
$rgname = "az-vmm-rg"
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
Write-Host -ForegroundColor Blue "Selected Subnet for deployment: $($selectedSubnet.Name)"

# Create Resource group and VMSS Instance
New-AzResourceGroup -ResourceGroupName $rgname -Location $location

# Create an Azure Load Balancer with a public IP address that has the VMSS as the backend on port 80
$publicip = @{
    Name = "vmss-pip-$randomString"
    ResourceGroupName = $rgname
    Location = $location
    Sku = 'Standard'
    AllocationMethod = 'static'
    Zone = 1,2,3
}
New-AzPublicIpAddress @publicip

## Place public IP created in previous steps into variable. ##
$pip = @{
    Name = "vmss-pip-$randomString"
    ResourceGroupName = $rgname
}
$publicIp = Get-AzPublicIpAddress @pip

if ($publicIp.ProvisioningState -ne 'Succeeded') {
    Write-Error "Public IP creation failed."
    exit 1
}
else {
    Write-Host -ForegroundColor Blue "Public IP created successfully."
}

## Create load balancer frontend configuration and place in variable. ##
$fip = @{
    Name = 'frontEndConfig'
    PublicIpAddress = $publicIp 
}
$feip = New-AzLoadBalancerFrontendIpConfig @fip

## Create backend address pool configuration and place in variable. ##
$bepool = New-AzLoadBalancerBackendAddressPoolConfig -Name 'VMSS-BackEndPool'

## Create the health probe and place in variable. ##
$probe = @{
    Name = 'vmss-HealthProbe'
    Protocol = 'tcp'
    Port = '80'
    IntervalInSeconds = '360'
    ProbeCount = '5'
}
$healthprobe = New-AzLoadBalancerProbeConfig @probe

## Create the load balancer rule and place in variable. ##
$lbrule = @{
    Name = 'vmss-HTTPRule'
    Protocol = 'tcp'
    FrontendPort = '80'
    BackendPort = '80'
    IdleTimeoutInMinutes = '15'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
    Probe = $healthprobe
}
$rule = New-AzLoadBalancerRuleConfig @lbrule -EnableTcpReset -DisableOutboundSNAT

## Create the load balancer resource. ##
$loadbalancer = @{
    ResourceGroupName = $rgname
    Name = "vmss-lb-$randomString"
    Location = $location
    Sku = 'Standard'
    FrontendIpConfiguration = $feip
    BackendAddressPool = $bePool
    LoadBalancingRule = $rule
    Probe = $healthprobe
}
New-AzLoadBalancer @loadbalancer

$lbResource = Get-AzLoadBalancer -Name $loadbalancer.Name -ResourceGroupName $rgname

if ($lbResource.ProvisioningState -ne 'Succeeded') {
    Write-Error "Load Balancer creation failed."
    exit 1
}
else {
    Write-Host -ForegroundColor Blue "Load Balancer created successfully. Moving onto VMSS creation."
}

# Set the ipConfig for the VMSS based on the selected subnet

$ipConfig = New-AzVmssIpConfig `
    -Name "ipconfig1" `
    -SubnetId $selectedSubnet.Id `
    -LoadBalancerBackendAddressPoolsId $bePool.Id
 
# Create a new virtual machine scale set config object
$vmssConfig = New-AzVmssConfig `
    -Location $location `
    -SkuCapacity 3 `
    -SkuName "Standard_D2s_v5" `
    -UpgradePolicyMode "Automatic" `
    -OrchestrationMode "Flexible" `
    -platformFaultDomainCount 1 `
    -Zone 1,2,3 |
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

# Create the Azure virtual machine scale set
New-AzVmss `
    -ResourceGroupName $rgname `
    -Name $vmssName `
    -VirtualMachineScaleSet $vmssConfig `
    -Verbose

$vmssResource = Get-AzVmss -VMScaleSetName $vmssName -ResourceGroupName $rgname

if ($vmssResource.ProvisioningState -ne 'Succeeded') {
    Write-Error "VMSS creation failed."
    exit 1
}
else {
    Write-Host -ForegroundColor Blue "VMSS '$vmssName' created successfully."
}

