# WA-MZ-MR-Patterns (Pilot)


### The content is in full development as of 01/07/23. 

This repo contains Multi-Zone and Multi-Region Patterns for various Azure Architecture patterns. The following azure services / patterns for Multi Zone and Multi Region **brownfields** deployments will be as followed:

- Virtual Machine Scale Sets
- Standalone Azure SQL
- Azure Kubernetes Services
- Two Tier Application running on App Services and Azure SQL

## Prerequisites

Given that the artifacts within the repo are designed to address resiliency gaps for existing workloads, it assumes that certain resources are in place for a multi-zone or multi-region deployment to happen. Below is a breakdown of the core pre-reqs, followed by the resources that the deployment script has a dependency on.

**Core requirements**
- Azure subscription
- Contributor access over the subscription or RG scope you wish to deploy the solution into
- Access to connect to existing resources, specifically Virtual Networks subnets.

**Existing Resource Requirements**

- Single Region Multi Zone Deployment
    - Ensure you select an Azure Region that supports availability zones
    - Existing Virtual Network where both the VMSS and Load Balancer will reside
    - A subnet in the above VNET for targeting the deployment into

- Multi Region Multi Zone Deployment
    - Ensure you select two Azure Region that supports availability zones
    - Existing Virtual Networks in both regions where the VMSS and Load Balancer will reside
    - A subnet in the above VNET for targeting the deployment into

**Deployment Options**

We are focusing our efforts on providing deployments options based on both Azure Bicep and Terraform. You will find some patterns contain options for Azure CLI or Azure Powershell, however these will not be our active focus moving forward.

# Contribution

# Contribution


![Contributors](https://contrib.rocks/image?repo=tsc-buddy/WA-MZ-MR-Patterns)
