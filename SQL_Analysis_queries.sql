-- ============================================================
-- Marketing Campaign Effectiveness & ROI Analysis

-- SECTION 1: TABLE SETUP & ENRICHED VIEW

-- Create the base table
CREATE TABLE IF NOT EXISTS marketing_campaign (
    campaign_id              VARCHAR(20) PRIMARY KEY,
    campaign_type            VARCHAR(50),
    channel                  VARCHAR(50),
    region                   VARCHAR(50),
    impressions              BIGINT,
    clicks                   BIGINT,
    conversions              INT,
    revenue_generated        DECIMAL(12,2),
    campaign_cost            DECIMAL(12,2),
    customer_acquisition_cost DECIMAL(10,2),
    date                     DATE
);

-- Create an enriched view with derived KPIs
CREATE OR REPLACE VIEW vw_campaign_kpis AS
SELECT
    campaign_id,
    campaign_type,
    channel,
    region,
    impressions,
    clicks,
    conversions,
    revenue_generated,
    campaign_cost,
    customer_acquisition_cost,
    date,
    EXTRACT(YEAR FROM date)          AS year,
    EXTRACT(MONTH FROM date)         AS month,
    EXTRACT(QUARTER FROM date)       AS quarter,
    -- Click-Through Rate
    ROUND(CAST(clicks AS DECIMAL) / NULLIF(impressions, 0) * 100, 4) AS ctr_pct,
    -- Conversion Rate
    ROUND(CAST(conversions AS DECIMAL) / NULLIF(clicks, 0) * 100, 4) AS conversion_rate_pct,
    -- ROI
    ROUND((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100, 2) AS roi_pct,
    -- Net Profit
    ROUND(revenue_generated - campaign_cost, 2) AS net_profit,
    -- Revenue per Click
    ROUND(revenue_generated / NULLIF(clicks, 0), 2) AS revenue_per_click,
    -- Cost per Click
    ROUND(campaign_cost / NULLIF(clicks, 0), 2) AS cost_per_click,
    -- Cost per Impression (CPM)
    ROUND(campaign_cost / NULLIF(impressions, 0) * 1000, 2) AS cpm,
    -- Performance label
    CASE
        WHEN (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100 >= 100 THEN 'High Performer'
        WHEN (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100 BETWEEN 20 AND 99.99 THEN 'Moderate Performer'
        WHEN (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100 BETWEEN 0 AND 19.99 THEN 'Low Performer'
        ELSE 'Underperforming'
    END AS performance_label
FROM marketing_campaign;


-- ============================================================
-- SECTION 2: CORE KPI SUMMARY
-- ============================================================

-- Q1: Overall Business Summary
SELECT
    COUNT(campaign_id)                              AS total_campaigns,
    SUM(impressions)                                AS total_impressions,
    SUM(clicks)                                     AS total_clicks,
    SUM(conversions)                                AS total_conversions,
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS total_net_profit,
    ROUND(
        (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) * 100, 2
    )                                               AS overall_roi_pct,
    ROUND(CAST(SUM(clicks) AS DECIMAL) / NULLIF(SUM(impressions), 0) * 100, 4) AS avg_ctr_pct,
    ROUND(CAST(SUM(conversions) AS DECIMAL) / NULLIF(SUM(clicks), 0) * 100, 4) AS avg_cvr_pct,
    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac
FROM marketing_campaign;


-- ============================================================
-- SECTION 3: CHANNEL-WISE PERFORMANCE ANALYSIS
-- ============================================================

-- Q2: Channel Performance with Rankings
SELECT
    channel,
    campaign_type,
    COUNT(campaign_id)                              AS num_campaigns,
    SUM(impressions)                                AS total_impressions,
    SUM(clicks)                                     AS total_clicks,
    SUM(conversions)                                AS total_conversions,
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS net_profit,
    ROUND(
        CAST(SUM(clicks) AS DECIMAL) / NULLIF(SUM(impressions), 0) * 100, 3
    )                                               AS ctr_pct,
    ROUND(
        CAST(SUM(conversions) AS DECIMAL) / NULLIF(SUM(clicks), 0) * 100, 3
    )                                               AS cvr_pct,
    ROUND(
        (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) * 100, 2
    )                                               AS roi_pct,
    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac,
    -- Window function: Rank by ROI
    RANK() OVER (
        ORDER BY (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) DESC
    )                                               AS roi_rank,
    DENSE_RANK() OVER (
        ORDER BY SUM(revenue_generated) DESC
    )                                               AS revenue_rank
FROM marketing_campaign
GROUP BY channel, campaign_type
ORDER BY roi_pct DESC;


-- ============================================================
-- SECTION 4: REGION-WISE PERFORMANCE ANALYSIS
-- ============================================================

-- Q3: Region-wise breakdown with contribution %
WITH region_totals AS (
    SELECT
        region,
        COUNT(campaign_id)                           AS num_campaigns,
        SUM(impressions)                             AS total_impressions,
        SUM(clicks)                                  AS total_clicks,
        SUM(conversions)                             AS total_conversions,
        ROUND(SUM(revenue_generated), 2)             AS total_revenue,
        ROUND(SUM(campaign_cost), 2)                 AS total_cost,
        ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS net_profit,
        ROUND(
            (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) * 100, 2
        )                                            AS roi_pct,
        RANK() OVER (
            ORDER BY SUM(revenue_generated) DESC
        )                                            AS revenue_rank
    FROM marketing_campaign
    GROUP BY region
),
grand_total AS (
    SELECT SUM(total_revenue) AS grand_revenue FROM region_totals
)
SELECT
    r.*,
    ROUND(r.total_revenue / g.grand_revenue * 100, 2) AS revenue_contribution_pct
FROM region_totals r
CROSS JOIN grand_total g
ORDER BY r.revenue_rank;


-- ============================================================
-- SECTION 5: TOP & BOTTOM PERFORMING CAMPAIGNS
-- ============================================================

-- Q4: Top 20 Campaigns by ROI
WITH campaign_roi AS (
    SELECT
        campaign_id,
        campaign_type,
        channel,
        region,
        impressions,
        clicks,
        conversions,
        revenue_generated,
        campaign_cost,
        ROUND(revenue_generated - campaign_cost, 2) AS net_profit,
        ROUND(
            (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100, 2
        )                                           AS roi_pct,
        ROUND(CAST(clicks AS DECIMAL) / NULLIF(impressions, 0) * 100, 3) AS ctr_pct,
        ROUND(CAST(conversions AS DECIMAL) / NULLIF(clicks, 0) * 100, 3) AS cvr_pct,
        DENSE_RANK() OVER (ORDER BY (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) DESC) AS roi_rank
    FROM marketing_campaign
)
SELECT *
FROM campaign_roi
WHERE roi_rank <= 20
ORDER BY roi_rank;


-- Q5: Bottom 20 Worst Performing Campaigns (Budget Drains)
WITH campaign_roi AS (
    SELECT
        campaign_id,
        campaign_type,
        channel,
        region,
        revenue_generated,
        campaign_cost,
        ROUND(revenue_generated - campaign_cost, 2) AS net_profit,
        ROUND(
            (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100, 2
        )                                           AS roi_pct,
        conversions,
        customer_acquisition_cost,
        DENSE_RANK() OVER (ORDER BY (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) ASC) AS worst_rank
    FROM marketing_campaign
)
SELECT *
FROM campaign_roi
WHERE worst_rank <= 20
ORDER BY roi_pct ASC;


-- ============================================================
-- SECTION 6: CAMPAIGN TYPE ANALYSIS WITH CASE WHEN
-- ============================================================

-- Q6: Campaign Type Performance Tiers
SELECT
    campaign_type,
    COUNT(campaign_id)                              AS total_campaigns,
    ROUND(AVG(
        (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100
    ), 2)                                           AS avg_roi_pct,
    -- Budget efficiency tier
    CASE
        WHEN AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100) >= 150
            THEN '🟢 Scale Up - Excellent'
        WHEN AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100) BETWEEN 50 AND 149
            THEN '🟡 Optimize - Good'
        WHEN AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100) BETWEEN 0 AND 49
            THEN '🟠 Monitor - Below Average'
        ELSE '🔴 Cut Budget - Losing Money'
    END                                             AS budget_recommendation,
    SUM(conversions)                                AS total_conversions,
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac,
    -- CAC assessment
    CASE
        WHEN AVG(customer_acquisition_cost) <= 50   THEN 'Excellent CAC'
        WHEN AVG(customer_acquisition_cost) <= 150  THEN 'Acceptable CAC'
        WHEN AVG(customer_acquisition_cost) <= 300  THEN 'High CAC - Optimize'
        ELSE 'Critical CAC - Review'
    END                                             AS cac_assessment
FROM marketing_campaign
GROUP BY campaign_type
ORDER BY avg_roi_pct DESC;


-- ============================================================
-- SECTION 7: TIME-SERIES ANALYSIS
-- ============================================================

-- Q7: Monthly Revenue & ROI Trends (with Moving Average)
WITH monthly_stats AS (
    SELECT
        EXTRACT(YEAR FROM date)   AS year,
        EXTRACT(MONTH FROM date)  AS month,
        TO_CHAR(date, 'YYYY-MM')  AS year_month,
        COUNT(campaign_id)        AS campaigns_run,
        SUM(clicks)               AS total_clicks,
        SUM(conversions)          AS total_conversions,
        ROUND(SUM(revenue_generated), 2) AS monthly_revenue,
        ROUND(SUM(campaign_cost), 2)     AS monthly_cost,
        ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS monthly_profit,
        ROUND(
            (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) * 100, 2
        ) AS monthly_roi_pct
    FROM marketing_campaign
    GROUP BY EXTRACT(YEAR FROM date), EXTRACT(MONTH FROM date), TO_CHAR(date, 'YYYY-MM')
)
SELECT
    *,
    -- 3-month moving average on revenue
    ROUND(AVG(monthly_revenue) OVER (
        ORDER BY year, month
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW
    ), 2) AS revenue_3mo_moving_avg,
    -- Month-over-month revenue growth
    ROUND(
        (monthly_revenue - LAG(monthly_revenue) OVER (ORDER BY year, month))
        / NULLIF(LAG(monthly_revenue) OVER (ORDER BY year, month), 0) * 100, 2
    ) AS mom_revenue_growth_pct,
    -- Cumulative revenue
    SUM(monthly_revenue) OVER (ORDER BY year, month) AS cumulative_revenue
FROM monthly_stats
ORDER BY year, month;


-- Q8: Quarterly Performance Summary
SELECT
    EXTRACT(YEAR FROM date)    AS year,
    EXTRACT(QUARTER FROM date) AS quarter,
    CASE EXTRACT(QUARTER FROM date)
        WHEN 1 THEN 'Q1 (Jan-Mar)'
        WHEN 2 THEN 'Q2 (Apr-Jun)'
        WHEN 3 THEN 'Q3 (Jul-Sep)'
        WHEN 4 THEN 'Q4 (Oct-Dec)'
    END                         AS quarter_label,
    COUNT(campaign_id)          AS campaigns,
    SUM(impressions)            AS impressions,
    SUM(conversions)            AS conversions,
    ROUND(SUM(revenue_generated), 2) AS revenue,
    ROUND(SUM(campaign_cost), 2)     AS cost,
    ROUND(
        (SUM(revenue_generated) - SUM(campaign_cost)) / NULLIF(SUM(campaign_cost), 0) * 100, 2
    )                           AS roi_pct,
    -- QoQ comparison
    ROUND(
        (SUM(revenue_generated) - LAG(SUM(revenue_generated)) OVER (ORDER BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date)))
        / NULLIF(LAG(SUM(revenue_generated)) OVER (ORDER BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date)), 0) * 100, 2
    )                           AS qoq_revenue_growth_pct
FROM marketing_campaign
GROUP BY EXTRACT(YEAR FROM date), EXTRACT(QUARTER FROM date)
ORDER BY year, quarter;


-- ============================================================
-- SECTION 8: FUNNEL ANALYSIS
-- ============================================================

-- Q9: Conversion Funnel by Campaign Type
SELECT
    campaign_type,
    SUM(impressions)   AS impressions,
    SUM(clicks)        AS clicks,
    SUM(conversions)   AS conversions,
    -- Funnel drop rates
    ROUND(CAST(SUM(clicks) AS DECIMAL) / NULLIF(SUM(impressions), 0) * 100, 2)     AS impression_to_click_pct,
    ROUND(CAST(SUM(conversions) AS DECIMAL) / NULLIF(SUM(clicks), 0) * 100, 2)     AS click_to_conversion_pct,
    ROUND(CAST(SUM(conversions) AS DECIMAL) / NULLIF(SUM(impressions), 0) * 100, 4) AS end_to_end_cvr_pct,
    -- Absolute drop-offs
    SUM(impressions) - SUM(clicks)      AS dropped_at_impression,
    SUM(clicks) - SUM(conversions)      AS dropped_at_click
FROM marketing_campaign
GROUP BY campaign_type
ORDER BY end_to_end_cvr_pct DESC;


-- ============================================================
-- SECTION 9: BUDGET WASTE ANALYSIS
-- ============================================================

-- Q10: Identify Wasted Budget (Negative ROI Campaigns)
SELECT
    campaign_type,
    channel,
    region,
    COUNT(campaign_id)                                   AS losing_campaigns,
    ROUND(SUM(campaign_cost), 2)                         AS wasted_budget,
    ROUND(SUM(revenue_generated), 2)                     AS revenue_recovered,
    ROUND(SUM(campaign_cost) - SUM(revenue_generated), 2) AS net_loss,
    ROUND(
        AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100), 2
    )                                                    AS avg_roi_pct
FROM marketing_campaign
WHERE revenue_generated < campaign_cost
GROUP BY campaign_type, channel, region
ORDER BY net_loss DESC
LIMIT 20;


-- ============================================================
-- SECTION 10: ADVANCED - PERCENTILE & OUTLIER ANALYSIS
-- ============================================================

-- Q11: Campaign Performance Percentiles
WITH percentiles AS (
    SELECT
        campaign_id,
        channel,
        campaign_type,
        region,
        ROUND((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100, 2) AS roi_pct,
        NTILE(4) OVER (ORDER BY (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0)) AS roi_quartile,
        PERCENT_RANK() OVER (ORDER BY (revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0)) AS roi_percentile
    FROM marketing_campaign
)
SELECT
    roi_quartile,
    CASE roi_quartile
        WHEN 1 THEN 'Bottom 25% - Cut'
        WHEN 2 THEN '25-50% - Monitor'
        WHEN 3 THEN '50-75% - Maintain'
        WHEN 4 THEN 'Top 25% - Scale'
    END             AS quartile_label,
    COUNT(*)        AS campaign_count,
    ROUND(MIN(roi_pct), 2) AS min_roi,
    ROUND(MAX(roi_pct), 2) AS max_roi,
    ROUND(AVG(roi_pct), 2) AS avg_roi
FROM percentiles
GROUP BY roi_quartile
ORDER BY roi_quartile;


-- Q12: Channel-Region Cross Performance Matrix
SELECT
    channel,
    region,
    COUNT(campaign_id) AS campaigns,
    ROUND(AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0) * 100), 2) AS avg_roi_pct,
    ROUND(SUM(revenue_generated), 2) AS total_revenue,
    -- Row-level ranking within each channel
    RANK() OVER (
        PARTITION BY channel
        ORDER BY AVG((revenue_generated - campaign_cost) / NULLIF(campaign_cost, 0)) DESC
    ) AS region_rank_within_channel
FROM marketing_campaign
GROUP BY channel, region
ORDER BY channel, region_rank_within_channel;
