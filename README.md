# WA-MZ-MR-Patterns (Pilot)


### The content is in full development as of 22/060/23. 

This repo contains Multi-Zone and Multi-Region Patterns for various Azure Architecture patterns. The following azure services / patterns for Multi Zone and Multi Region **brownfields** deployments will be as followed:

- Virtual Machine Scale Sets
- Azure Kubernetes Services
- Standalone Azure SQL
- Two Tier Application running on App Services and Azure SQL


## Prerequisites

Given that the artifacts within the repo are designed to address resiliency gaps for existing workloads, it assumes that certain resources are in place for a multi-zone or multi-region deployment to happen. Below is a breakdown of the core pre-reqs, followed by the resources that the deployment script has a dependency on.

**Core requirements**
- Azure subscription
- Contributor access over the subscription or RG scope you wish to deploy the solution into
- Access to connect to existing resources, specifically Virtual Networks subnets.

**Existing Resource Requirements**

- Single Region Multi Zone Deployment
    - Virtual Network where both the VMSS and Load Balancer will reside
    - A subnet in the above VNET for targeting the deployment into

    
