
# Custom Intune Reporting Examples

**A collection of custom reporting solutions built on Microsoft Intune, Microsoft Graph, Azure, and Power BI.**

## 📌 Overview

This repository contains a series of examples that demonstrate how to extend Intune's native reporting capabilities using Microsoft Graph API and other tools. These solutions are designed to help IT administrators generate richer, more customized reports by combining data from Intune with external sources.

Each example is self-contained and focuses on a specific reporting scenario, such as cost tracking, device compliance, or user activity.

## 🧰 Components

Each example may include a combination of the following components:

- PowerShell scripts for data collection and Azure resource provisioning
- Power BI dashboards for data visualization
- Azure Automation runbooks and Log Analytics workspaces
- Integration with Microsoft Graph API and external data sources

## ⚙️ Setup Instructions

Each example will have its own setup instructions, but most follow a similar format:

1. **Download Assets**  
   Clone or download the PowerShell scripts and Power BI templates provided in the example folder.

2. **Configure Variables**  
   Update the script with your environment-specific values (e.g., Tenant ID, Resource Group, location).

3. **Deploy Resources**  
   Run the script to create necessary Azure resources and configure data ingestion.

4. **Connect Power BI**  
   Use the provided queries to connect Power BI to your Log Analytics workspace.

5. **Customize as Needed**  
   Modify pricing tables, data sources, or queries to suit your organization’s needs.
