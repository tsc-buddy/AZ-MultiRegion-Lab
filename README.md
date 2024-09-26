# AZ and Multi-Region Remediation Lab


### The content is in full development as of July 2024

This repo contains content for a Hands-on Self paced Lab based on the following scenarios:

- The migration of Azure services that are actively deployed and not leveraging availability zones for resiliency
- Workloads that are deployed in a single region, with a desire to adopt a multi-region resiliency strategy.

The purpose of this lab is to provide a **semi-guided** experience for you to get hands-on with the migration processes for services that are not leveraging AZ's or are part of a multi-region workload pattern in an environment that is not related to any real production workload, thus providing a safe space to conduct such activities in preparation for remediating resiliency issues for live workloads.

This is achieved through deploying a synthetic workloads infrastructure in one of two archetypes (VM IaaS Based or fully PaaS based), then leveraging a mixture of the public Availabiltiy Zone Migration guidance alongside some content developed exclusively for this lab. The same applies for the Multi-region scenario, leveraging the Lab Guide and a some of Microsofts Public documentation.  

## Prerequisites

To complete this lab and any of its scenarios, you need to have the following prerequisites met.

- An active azure subscription
- Azure Powershell / Azure CLI installed
- Azure Bicep Installed
- VSCode with the Bicep Extension
- Azure Storage Explorer (optional)
- SQL Server (mssql) - VS Code Extension (optional)


## The workloads

Please note - as of August 2024, this lab deploys just the infrastructure for the sythetic workload. There is no application deployment at this stage. However, we are actively planning the development of a basic application to deploy on top of the infrastructure scenarios with the aim to provide exposure into the effects and considerations you must have when addressing AZ resiliency gaps or adopting a multi-region strategy, allowing you to also explore the implications at an application level.

There are three lab scenarios to choose from:

1. [Single Region IaaS Based Infrastructure Availability Zone Remediation](./labs/scenario-one/README.md)
2. [Single Region PaaS Based Infrastructure Availability Zone Remediation](./labs/scenario-two/README.md)
3. [Multi-region implementation using the PaaS based infrastructure design from scenario two.](./labs/scenario-three/README.md)

There is a workload preface that can be found [here](./docs/workloadPreface.md). It contains some fictional notes from a customer conversation and details about some of the 'Tracker' applications critical flows.


### Scenario Two Reference Architecture
![Scenario Two](docs/images/scenario-2.jpg)

# Contribution
![Contributors](https://contrib.rocks/image?repo=tsc-buddy/WA-MZ-MR-Patterns)
