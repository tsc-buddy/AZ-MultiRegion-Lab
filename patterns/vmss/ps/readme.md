# VMSS Pattern

This guide will step you through the process to deploy new VMSS instances via powershell. You have to option to choose multi zone in a single region or multi region with AZ support.


**Deployment Steps**

**Login to Azure** - Ensure you are in the correct context for deploying the chosen patterns resources into into.

![alt-text](docs/images/login.png)

**Check your context**

```text
    Get-AzContext
```
#### The following steps will vary between single region and multi region deployments. Just make sure the prerequisites are met and you should experience no issues.

**Run the deployment script** - Single Region VMSS for example. You will be prompted to provide the Azure region you wish to deploy into.
![alt-text](docs/images/runandlocation.png)

**Provide the name of the Virtual Network you wish to deploy into**
![alt-text](docs/images/vnet.png)

**Provide the password you wish to use for the VMSS**
![alt-text](docs/images/vmss-pw.png)

**Select from the subnet list**  - You will be prompted with an Index of subnets available within your chosen Virtual network, select one to connect your LB and VMSS into
![alt-text](docs/images/selectedsubnet.png)