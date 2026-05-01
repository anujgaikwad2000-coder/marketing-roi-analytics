# 📊 Marketing Campaign ROI Analysis & Optimization

## 🚩 Problem Statement
Most marketing teams track performance but fail to identify where budget is actually being wasted**.

This project analyzes 5,000+ campaigns across 6 channels and 5 regions to:
- Measure true ROI
- Detect negative ROI campaigns
- Recommend budget reallocation for maximum impact

## 🎯 Business Objective
Optimize ~$32.7M marketing spend by:
- Identifying high-performing channels
- Eliminating wasteful campaigns
- Improving conversion efficiency

## 📌 Key Insights
- ❗ 31% of total spend (~$10.2M) was wasted on negative ROI campaigns  
- 📧 Email marketing delivered ~15,000% ROI but received only ~5% budget  
- ⚠️ 90% drop at impression → click stage indicating poor ad creatives  
- 📈 Potential **~$95M annual impact** through reallocation and funnel optimization  

## 🏗️ Data Model (Star Schema)
- Fact Table: `fact_campaign`
- Dimension Tables:
  - `dim_date`
  - `dim_channel`
  - `dim_region`
  - `dim_campaign_type`

Designed for scalable analytics and efficient DAX calculations.

## 🔧 Tech Stack
- SQL → Data extraction & transformation  
- Python → Data processing & analysis  
- Power BI → Dashboard & visualization  
- DAX → KPI calculations (ROI, CAC, CTR, CVR)  
- Power Query → Data cleaning & feature engineering  

## 📊 Dashboard Overview
### 1. Executive Overview
- Revenue, Cost, ROI, CAC KPIs
- Monthly trends
- Channel performance

### 2. Deep Dive Analysis
- Funnel (Impressions → Clicks → Conversions)
- ROI by region & channel
- Drill-down capability

### 3. Campaign Insights
- Top & bottom performers
- Budget waste analysis
- CAC comparison

### 4. Recommendations
- Budget reallocation strategy
- Campaign optimization actions
- Market expansion insights

## 🚀 Live Interactive Dashboard  
👉 Click here to explore the full interactive dashboard:



