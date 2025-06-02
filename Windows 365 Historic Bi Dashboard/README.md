# Windows 365 Cost Dashboard

**Custom reporting solution for Windows 365 using Microsoft Graph, Azure Log Analytics, and Power BI.**

## 📌 Overview

This project demonstrates how to collect and visualize Windows 365 Cloud PC data by combining Microsoft Graph API with external data sources. It provides an end-to-end example of building a custom Power BI dashboard backed by Azure infrastructure for historical and cost-based reporting.

## 🚀 What It Does

- Collects Cloud PC data from Microsoft Graph API.
- Ingests data into Azure Log Analytics via Azure Automation.
- Visualizes data in a Power BI dashboard.
- Supports integration with external pricing or asset management data.

## 🧰 Components

- **PowerShell Script**: Automates Azure resource creation and data ingestion.
- **Power BI Dashboard**: Displays Cloud PC usage and cost trends.
- **Azure Resources**:
  - Log Analytics Workspace
  - Custom Table & Data Collection Rule
  - Azure Automation Account & Runbook
  - Managed Identity & App Registration

## 📦 Setup Instructions

1. **Download the Assets**  
   Clone or download the PowerShell script and Power BI template from this repo.

2. **Configure the Script**  
   Update variables like Tenant ID, Resource Group, and location.

3. **Run the Script**  
   Deploys all required Azure resources and sets up data ingestion.

4. **Verify Setup**  
   Confirm resource creation in the Azure Portal and test the runbook.

5. **Connect Power BI**  
   Use the provided M query to pull data from Log Analytics into Power BI.

6. **Customize Pricing Table**  
   Manually update or connect to your own pricing data source.

## ⚠️ Limitations

- Runbook scheduling and data retention policies must be configured manually.
- Azure usage may incur costs.

## 📖 Learn More

Coming soon: Keep watching for a blog post with a detailed explanation and step-by-step instructions.

## 🛡️ Disclaimer

The sample scripts are not supported under any Microsoft standard support program or service. The sample scripts are provided AS IS without warranty of any kind. Microsoft further disclaims all implied warranties including, without limitation, any implied warranties of merchantability or of fitness for a particular purpose. The entire risk arising out of the use or performance of the sample scripts and documentation remains with you. In no event shall Microsoft, its authors, or anyone else involved in the creation, production, or delivery of the scripts be liable for any damages whatsoever (including, without limitation, damages for loss of business profits, business interruption, loss of business information, or other pecuniary loss) arising out of the use of or inability to use the sample scripts or documentation, even if Microsoft has been advised of the possibility of such damages.

---

