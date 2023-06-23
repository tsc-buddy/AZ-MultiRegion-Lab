# Collect & set parameters
function vmssCreation{

    param (
        [Parameter(Mandatory=$true)]
        [string]$vnetName = (Read-Host "Please specify the name of the virtual network to deploy the virtual machine scale set to."),

        [Parameter(Mandatory=$true)]
        [SecureString]$adminPassword = (Read-Host "Please specify the name of the virtual network to deploy the virtual machine scale set to."),
        
        [Parameter(Mandatory=$true)]
        [string]$tmName,

        [Parameter(Mandatory=$true)]
        [string]$tmRGName
    )

    $randomString = [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)
    $vmssName = "vmss-" + $randomString
    $rgname = "rg-"+ $vmssName
    $adminUsername = "adminuser"

    # Get the virtual network by name
    $virtualNetwork = Get-AzVirtualNetwork -Name $vnetName
    $location = $virtualNetwork.Location

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
        DomainNameLabel = "vmss-pip-$randomString"
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
        Write-Host-ForegroundColor Blue "Public IP created successfully."
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

    New-AzTrafficManagerEndpoint -Name $vmssName -ProfileName $tmName -ResourceGroupName $tmRGName -Type AzureEndpoints -TargetResourceId $publicIp.Id -EndpointStatus Enabled

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
        -platformFaultDomainCount 1 `
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
}

##############################################################################################################

Write-Host -ForegroundColor Blue "Starting the creation of a multi-zone, multi-region VMSS architecture."


Write-Host -ForegroundColor Blue "Beginning the creation of Traffic manager profile to provide DNS load-balancing between the two VMSS deployments."

## Creating the traffic manager profile and associating the load balancer within both regions as endpoints.

$tmRGlocation = Read-Host -Prompt "Please provide the location for the resource group that will contain the traffic manager profile."
$tmdnsName = Read-Host -Prompt "Please provide the DNS name for the traffic manager profile."
$randomString = [System.IO.Path]::GetRandomFileName().Replace(".", "").Substring(0, 8)
$tmName = "vmss-tm-" + $randomString
$tmRGName = "vmss-tm-rg"


## Create the resource group for the traffic manager profile.
New-AzResourceGroup -name $tmRGName -location $tmRGlocation

## Create the traffic manager profile.
$tm = New-AzTrafficManagerProfile -Name $tmName -ResourceGroupName $tmRGName -TrafficRoutingMethod Performance -RelativeDnsName $tmdnsName -Ttl 30 -MonitorProtocol HTTP -MonitorPort 80 -MonitorPath "/"


Write-Host -ForegroundColor Blue  "Traffic Manager profile '$($tm.Name)' created successfully. Moving onto VMSS creation."


Write-Host -ForegroundColor Blue "Please provide the details for the first multi zone vmss deployment."

vmssCreation -tmName $tmName -tmRGName $tmRGName

Write-Host -ForegroundColor Blue "Please provide the details for the second multi zone vmss deployment. This one will be in a different region."

vmssCreation -tmName $tmName -tmRGName $tmRGName
