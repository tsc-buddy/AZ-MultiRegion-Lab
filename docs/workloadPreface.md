# Workload Background

The synthetic workloads used in each of the scenarios is based on Acme Limited, a multi-national technology consulting business. They have developed an internal project and resource tracking application called, **Tracker**. Its purpose is to allow its project managers and engineering leads plan project, understand capacity requirements across the different consulting engagements, whilst also forecasting an individual’s availability and bench time. Furthermore, it has integrations into external systems such as Azure Devops and Dynamics 365. 
You have identified the key areas of the workload that need to be addressed. This has been done through gaining an understanding of the workloads criticality to the business, its availability targets and the critical user and data flows to ensure the correct components are being addressed.
Depending on the scenario you select, you will be faced with an IaaS, PaaS or a multi-region based infrastructure architecture.

### Customer Conversation Transcript Notes (The following has been developed in preperation for future lab scenarios and is just a fictional story to give the upcoming application some background.)

Note that is this is deliberately 

**Workload Purpose:** Tracker is our internal consultant resource and project tracking application. It has been developed in-house. The entire business uses it for time sheeting, PMs & Tech Leads track project budget burndown against high-level project features synced from ADO and to analyze productivity improvements from new tooling, frameworks, mentoring etc.  

Our Leadership team use it for capacity planning and revenue forecasting purposes. It also has integration into our CRM it for billing purposes. 

**Workload Criticality:** Highly Critical. All personnel use it (~3000 FTE) daily, if this workload is offline or specific features are degraded, it can cause significant delays to planning, billing, forecasting. 
**RPO / RTO Defined:** RPO = <2hr of data loss, RTO 4 hours. 
**Availability Targets Defined:** None, the only targets are the RPO & RTO. 
**Application Stack:** JS front end on IIS Virtual Machines. Refactored API Layer migrated to App Services on .net Core. 

**Infrastructure Stack / History:** Originally, Tracker was migrated from On-prem in a lift and Shift Fashion, four large VMs in total. The API and Front end all ran on web-fe-vm01 & 02 with Tracker DBs running on our SQL Server. Tracker-app-vm01 is our middleware server running other jobs and integrations. 

All users Authenticate via Entra ID and depending on where they are accessing, the tracker app endpoint will resolve to either an internal or external IP (for C-Suite only). Our FTEs access tracker from our offices or when connected to the Cisco VPN on a private URL. Our LT & C-Suite can also access it via the internet, secured through IP whitelisting.  

Our app server had two key tasks, a resource & project budget summarization process and a report generation process that runs on the 28th of every month. These processes store the processed summarization data in a dedicated table (still on the SQL Server on prem) and creates a PDF report that is placed on the file server On-premises so we have a dependency on our hub and hybrid connectivity. These reports are used for resource and budget forecasting meetings, eventually we will refactor this feature.  

Our CRM also calls the app server / service endpoint three times a month for billing purposes and to reduce load of doing this at the end of the month. In the past we’ve missed billing cycles when running it on the 28th due to the amount of data and a lack of compute capacity we had on premise. 

Currently we have some performance issues with the three processes that the app server runs, we believe due to the hybrid nature of the infrastructure components of these data flows. 

**Backup / DR Strategy:** We use Azure Backup for our VMs. Everything else is managed by Microsoft. Our DR plan is to restore from Backup for VMs and redeploy APIs if needed. 

### Critical Data Flows

During a recent assessment of workloads resiliency posture, you identified three user/data flows that were important to Acme and the users of the Tracker App. Below you will find diagrams illustrating the identified flows across the different archetypes of the workload, the IaaS and PaaS ones respectively. You can use this information across all three scenarios to help determine remediation impact, failover measures and more.

| Flow Name | Flow Type | Flow Notes | Criticality (low,med, crit) | Critical Flow Components |
|----------|----------|----------|----------|----------|
| Login Flow   | User     | Users authenticate with Entra ID (which is synced to ADDS back on prem). DNS resolution can be done via the public DNS servers or via our private ADDS Integrated DNS Servers (not illustrated on the diagram)      | crit     | Entra ID, AppGW, FE VMs, Express Route & GW, Azure FW (for on-prem users).      |
| Time sheeting     | User     | Users log their time daily in 15 minute increments. It is company policy that time sheets are done daily.      | crit     | AppGW, FE VMs, Express Route & GW, Azure FW (for on-prem users), Azure SQL, API App Services, APIM      |
| Project burndown Updates     | System     | A process runs daily to update the project burndown based on that days completed time sheets. This runs at 2200.      | med     | Azure SQL, Web Job on Azure App Services      |
| Project Creation   | user     | Project Managers can create projects through the UI when given the green light by customer account managers. They create projects, link them to an ADO project and can assign individual resources (consultants) to that project to time sheet against it.      | med     | AppGW, FE VMs, Express Route & GW, Azure FW (for on-prem users), Azure SQL, API App Services, APIM      |
| ADO Feature Integration     | System    | A process runs twice daily to check for new backlog features added by the team that may need pulling into tracker. These items are used by the team to track their time against. This in turn also updates the remaining effort on that feature back in ADO      | med     | Azure SQL, Web Job on Azure App Services      |
| Project Summarization Process     | System     | A process that runs on the 28th of every month to create summarized project data for reporting purposes. Its stored in a separate table for report creation and analysis purposes.      | med     | App Server VM, Azure SQL, On-prem SQL VM, Express Route & GW, Azure Firewall.      |
| CRM Billing ingestion Process    | System      | Custom Dynamics processes hit the app server endpoint 3 times a month to ingest data for billing purposes. This is a legacy process that we never got around to migrating.      | crit     | App Server VM, Azure SQL, Public IP, Dynamics 365      |

