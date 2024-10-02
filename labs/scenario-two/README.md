# Scenario 2 Guidance

In this scenario you will be working with a PaaS infrastructure architecture. The application was originally built and run on virtual machines on-prem before being migrated to Azure and refactored to leverage PaaS. However, there are significant gaps around zone resiliency and given the criticality of this workload it must be able to tolerate a datacenter / availability zone failure within the primary Azure region used by Acme.

For a brief summary of the workload and its flows, read the [workload preface](../../docs/workloadPreface.md) here.

![Scenario Two Workload](../../docs/images/scenario-2.jpg)

### Getting Started 
To begin the lab, your first step is to deploy the synthetic workloads infrastructure. This will deploy the Azure Infrastructure shown in the architecture above into a single resource group called rg-waf-az-lab-scenario-2. Ensure you have the prerequisites above complete before following the steps below.

1. Navigate to the following Github Repo and either download or clone it to your local device.
2. Open up the Github Repo Directory in VS Code and load up terminal, logging into Azure Powershell or Azure CLI.
3. Ensure you are in the correct context for deploying resources.
4. CD into the Labs\scenario-two directory
5. Run the following deployment command.
```powershell
New-azSubscriptionDeployment -Location <location> -TemplateFile .\labs\scenario-two\main.bicep -TemplateParameterFile .\labs\scenario-two\scenario-two.bicepparam -verbose -name <PROVIDE DEPLOYMENT NAME>
```

```bash
az deployment sub create --location <location> --template-file ./labs/scenario-two/main.bicep
``` 


### Steps to remediate
The workload follows a typical three tier architecture, web/presentation layer, middleware/api layer and a data layer. There is also a L7 Application gateway that is in front of the web layer, this component is already Zone Redundant.
The objective of this lab is to ensure that all components of the application leverage three availability zones and for you to explore the steps and considerations when completing such activities.

#### Data Layer
The first layer we are going to focus on is the Data Layer, for this workload it consists of Azure Storage account and Azure SQL Single DB.

<br>

**SQL Database Steps**

Azure SQL Databases are used to store information relating to the application, data such as projects, engineer profiles, capacity project, time logging etc. You can use SQL Management Studio to connect to the DB should you wish. There are two primary approaches to DB migration to availability zones. The migration feature on Azure SQL is the first, the second is more manual and involves creating a transactionally consistent copy of the database. Use the following guide to step through the migration process using the migration feature.
There is an expected disconnect during the migration process, this is something customers should be aware of. If there is a lack of retry logic within the connected application, disruptions will likely occur.

[Migrate Azure SQL Database to availability zone support | Microsoft Learn](https://learn.microsoft.com/en-us/azure/reliability/migrate-sql-database?tabs=portal%2Cpool#migration-premium-business-critical-and-general-purpose)

For more information around implementing retry logic, explore the following documentation. 
[Working with transient errors - Azure SQL Database | Microsoft Learn](https://learn.microsoft.com/en-us/azure/azure-sql/database/troubleshoot-common-connectivity-issues?view=azuresql&preserve-view=true#retry-logic-for-transient-errors)

**Storage Account Steps**

The storage account is used to store specific content related to the application, file uploads by users, generated reports etc. Follow the steps below to migrate the deployed storage account from its current state to our desired state. Use could use Azure Storage Explorer to understand any downtime implications.

Follow the steps here to migrate to AZs. You will notice there are two migration options, follow ‘Option one – customer initiated’ for the purpose of this lab.
[Migrate Azure Storage accounts to availability zone support | Microsoft Learn](https://learn.microsoft.com/en-us/azure/reliability/migrate-storage#option-1-conversion)

You will notice that for the option we selected, there will be no impact on the availability of the storage account, however, it is not immediate and could take up to 72 hours to complete. This is something to keep in mind when conducting a migration to from LRS to another resiliency type as the timing may play a role in ones remediation strategy. Furthermore, this makes testing hard to achieve. It is recommended that for storage accounts that are 'busy', you leverage [AMBA](https://azure.github.io/azure-monitor-baseline-alerts/services/Storage/storageAccounts/) to monitor the following metrics:

> **Note** - Select the availbility / latency metric most appropriate to the sub-service you are leveraging

- Availability
- blobServices - SuccessE2ELatency
- fileServices - Availability
- Throttling

**API Management**

Azure API Management serves as the gateway to the API Web App, it is there for security, performance and resiliency reasons, providing rate limiting, secure API access and circuit breaker functionality where required. When configured to be zone resilient, both the gateway and the control plane are replicated across the zones you select. One key pre-requisite is the SKU, the APIM instance needs to be Premium. Another prerequisite to confirm is the subnet size for APIMs that are into a VNET. Subnet micro-segmentation is a popular security control, however, you need to ensure that the subnet APIM is connected to has enough address space to support the number of instances you wish to have for each availability zone.

Following the step here to remediate the Acme API Management instance. Note that the deployed APIM is in a single AZ, the goal is to have it deployed across all zones. 

[Migrate Azure API Management to availability zones | Microsoft Learn ](https://learn.microsoft.com/en-us/azure/reliability/migrate-api-mgt)

For testing downtime, leverage an application such as Postman to make API calls to APIM whilst the migration is happening. There is an ACME API loaded into the deployed API Management instance for you to test against.

#### Web & API Layers

**App Services**

There are two layers of App Services being used within this architecture. One is the web/presentation layer, the other is the API/middleware layer. The latter sits behind the API Management instance, so the two are coupled together, thus dependent on one another.
The web/presentation layer is the one running the UI. Requests come from the user through the Application Gateway which forwards the request to the App Service. Azure Application Gateway is serving as a Layer 7 Web Application Firewall / LB. The App services are configured as backend endpoints.
Something you will observe when reading the App Service Migration guidance on the link below is that unlike some other the others services we have been addressing, there is no SKU conversion / feature toggle to seamlessly begin leveraging availability zones.

**Call to action:** With that information at hand and the knowledge of the App Services at each layer, explore options to migrate to a Zone Redundant instance for both layers whilst minimizing downtime. Feel free to use the table below to capture the steps that you determine are necessary

[App Services Migration - Reliability in Azure App Service | Microsoft Learn](https://learn.microsoft.com/en-us/azure/reliability/reliability-app-service?tabs=cli#availability-zone-migration)

| Step No. | Step Title | Details | Links / Ref | 
|----------|----------|----------|----------|
| 1.          |          |          |          |
| 2.          |          |          |          |

>
> **Note** – Due to no active API Service on the workload as of July 2024, just focus on the Web Layer behind the Azure Application Gateway. The App Services should start with: s2-web-_'uniquestring'_

>
>**Tip**: Explore Azure Application Gateway HTTP Settings for ways to transition between App Service Instances.


### Composite Availability Estimate
Availability Calculations are intended to be used as a rough-order-of-magnitude (ROM) estimate for the general availability of a workload based on the design and dependency chain of each critical flow. It is a great way to understand how design decisions relating to both the infrastructure in Azure and your application code play a role is a workloads level of potential availability.

> **Call to Action:** Using the Microsoft Composite Availability Estimate Calculator (CATE), work out the Max Minutes of Downtime/month and the Composite Availability Target for the architecture and its critical flows to compare the before and after based on the changes you have made. For a table of details about the critical flows, read the [workload preface](../../docs/workloadPreface.md).

### Cleanup
When you have finished with this scenario as part of the lab, simply delete the resource group named ‘rg-waf-az-lab-scenario-2’. Everything that was deployed during the initial steps will reside within that resource group. 
If you deployed any additional resources outside of that resource group, be sure to do the same and clean them up also.
