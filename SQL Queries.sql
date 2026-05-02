-- ============================================================
-- Marketing Campaign Effectiveness & ROI Analysis
-- SQL Queries - Simple & Readable Version
-- ============================================================


-- ============================================================
-- STEP 1: CREATE THE TABLE
-- This is where all campaign data will be stored
-- ============================================================

CREATE TABLE IF NOT EXISTS marketing_campaign (
    campaign_id               VARCHAR(20),
    campaign_type             VARCHAR(50),
    channel                   VARCHAR(50),
    region                    VARCHAR(50),
    impressions               BIGINT,
    clicks                    BIGINT,
    conversions               INT,
    revenue_generated         DECIMAL(12,2),
    campaign_cost             DECIMAL(12,2),
    customer_acquisition_cost DECIMAL(10,2),
    date                      DATE
);


-- ============================================================
-- STEP 2: OVERALL BUSINESS SUMMARY
-- One query to get the big picture numbers
-- ============================================================

SELECT
    COUNT(*)                                        AS total_campaigns,
    SUM(impressions)                                AS total_impressions,
    SUM(clicks)                                     AS total_clicks,
    SUM(conversions)                                AS total_conversions,

    -- Money metrics
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS total_profit,

    -- Key KPIs
    -- ROI = (revenue - cost) / cost × 100
    ROUND((SUM(revenue_generated) - SUM(campaign_cost))
          / SUM(campaign_cost) * 100, 2)            AS roi_pct,

    -- CTR = clicks / impressions × 100
    ROUND(SUM(clicks) * 100.0 / SUM(impressions), 2) AS ctr_pct,

    -- CVR = conversions / clicks × 100
    ROUND(SUM(conversions) * 100.0 / SUM(clicks), 2) AS cvr_pct,

    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac

FROM marketing_campaign;


-- ============================================================
-- STEP 3: PERFORMANCE BY CAMPAIGN TYPE
-- Which channel (Email, Paid Ads, etc.) performs best?
-- ============================================================

SELECT
    campaign_type,
    COUNT(*)                                        AS total_campaigns,
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS net_profit,

    -- ROI for each campaign type
    ROUND((SUM(revenue_generated) - SUM(campaign_cost))
          / SUM(campaign_cost) * 100, 2)            AS roi_pct,

    -- CTR for each campaign type
    ROUND(SUM(clicks) * 100.0 / SUM(impressions), 2) AS ctr_pct,

    -- CVR for each campaign type
    ROUND(SUM(conversions) * 100.0 / SUM(clicks), 2) AS cvr_pct,

    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac,

    -- Rank each type by ROI (1 = best)
    RANK() OVER (ORDER BY SUM(revenue_generated) - SUM(campaign_cost)
                          / SUM(campaign_cost) DESC) AS roi_rank

FROM marketing_campaign
GROUP BY campaign_type
ORDER BY roi_pct DESC;


-- ============================================================
-- STEP 4: PERFORMANCE BY REGION
-- Which region generates the most revenue?
-- Uses a CTE to also calculate % contribution
-- ============================================================

-- First calculate revenue per region
WITH region_summary AS (
    SELECT
        region,
        COUNT(*)                                        AS total_campaigns,
        ROUND(SUM(revenue_generated), 2)                AS total_revenue,
        ROUND(SUM(campaign_cost), 2)                    AS total_cost,
        ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS net_profit,
        ROUND((SUM(revenue_generated) - SUM(campaign_cost))
              / SUM(campaign_cost) * 100, 2)            AS roi_pct
    FROM marketing_campaign
    GROUP BY region
)

-- Then add the % contribution column
SELECT
    region,
    total_campaigns,
    total_revenue,
    total_cost,
    net_profit,
    roi_pct,
    -- What % of overall revenue comes from this region?
    ROUND(total_revenue / SUM(total_revenue) OVER () * 100, 2) AS revenue_share_pct
FROM region_summary
ORDER BY total_revenue DESC;


-- ============================================================
-- STEP 5: TOP 20 BEST CAMPAIGNS (Highest ROI)
-- Which specific campaigns made the most profit?
-- ============================================================

SELECT
    campaign_id,
    campaign_type,
    channel,
    region,
    ROUND(revenue_generated, 2)                     AS revenue,
    ROUND(campaign_cost, 2)                         AS cost,
    ROUND(revenue_generated - campaign_cost, 2)     AS net_profit,

    -- ROI for this single campaign
    ROUND((revenue_generated - campaign_cost)
          / campaign_cost * 100, 2)                 AS roi_pct,

    -- Rank from best to worst ROI
    RANK() OVER (ORDER BY (revenue_generated - campaign_cost)
                          / campaign_cost DESC)     AS roi_rank

FROM marketing_campaign
ORDER BY roi_pct DESC
LIMIT 20;


-- ============================================================
-- STEP 6: BOTTOM 20 WORST CAMPAIGNS (Biggest Budget Drains)
-- Which campaigns lost the most money?
-- ============================================================

SELECT
    campaign_id,
    campaign_type,
    channel,
    region,
    ROUND(revenue_generated, 2)                     AS revenue,
    ROUND(campaign_cost, 2)                         AS cost,
    ROUND(revenue_generated - campaign_cost, 2)     AS net_loss,
    ROUND((revenue_generated - campaign_cost)
          / campaign_cost * 100, 2)                 AS roi_pct

FROM marketing_campaign

-- Only campaigns losing money
WHERE revenue_generated < campaign_cost

ORDER BY net_loss ASC  -- most negative first
LIMIT 20;


-- ============================================================
-- STEP 7: CAMPAIGN TYPE RECOMMENDATION
-- Automatically label each type: Scale / Optimize / Cut
-- Uses CASE WHEN like an IF-ELSE statement
-- ============================================================

SELECT
    campaign_type,
    ROUND(AVG((revenue_generated - campaign_cost)
              / campaign_cost * 100), 2)            AS avg_roi_pct,
    ROUND(SUM(revenue_generated), 2)                AS total_revenue,
    ROUND(SUM(campaign_cost), 2)                    AS total_cost,
    ROUND(AVG(customer_acquisition_cost), 2)        AS avg_cac,

    -- Business recommendation based on ROI
    CASE
        WHEN AVG((revenue_generated - campaign_cost) / campaign_cost * 100) >= 150
            THEN 'Scale Up'
        WHEN AVG((revenue_generated - campaign_cost) / campaign_cost * 100) >= 50
            THEN 'Optimize'
        WHEN AVG((revenue_generated - campaign_cost) / campaign_cost * 100) >= 0
            THEN 'Monitor'
        ELSE 'Cut Budget'
    END AS recommendation,

    -- CAC label
    CASE
        WHEN AVG(customer_acquisition_cost) <= 50   THEN 'Excellent'
        WHEN AVG(customer_acquisition_cost) <= 150  THEN 'Acceptable'
        WHEN AVG(customer_acquisition_cost) <= 300  THEN 'High'
        ELSE 'Critical'
    END AS cac_rating

FROM marketing_campaign
GROUP BY campaign_type
ORDER BY avg_roi_pct DESC;


-- ============================================================
-- STEP 8: MONTHLY REVENUE TREND
-- How does revenue change month by month?
-- Uses LAG() to compare with previous month
-- ============================================================

WITH monthly AS (
    SELECT
        EXTRACT(YEAR FROM date)   AS year,
        EXTRACT(MONTH FROM date)  AS month,
        COUNT(*)                  AS campaigns_run,
        ROUND(SUM(revenue_generated), 2) AS revenue,
        ROUND(SUM(campaign_cost), 2)     AS cost,
        ROUND(SUM(revenue_generated) - SUM(campaign_cost), 2) AS profit,
        ROUND((SUM(revenue_generated) - SUM(campaign_cost))
              / SUM(campaign_cost) * 100, 2) AS roi_pct
    FROM marketing_campaign
    GROUP BY year, month
)

SELECT
    year,
    month,
    campaigns_run,
    revenue,
    cost,
    profit,
    roi_pct,

    -- Compare this month's revenue to last month's
    LAG(revenue) OVER (ORDER BY year, month)        AS prev_month_revenue,

    -- Month-over-month growth %
    ROUND((revenue - LAG(revenue) OVER (ORDER BY year, month))
          / LAG(revenue) OVER (ORDER BY year, month) * 100, 2) AS mom_growth_pct,

    -- Running total of revenue so far
    SUM(revenue) OVER (ORDER BY year, month)        AS cumulative_revenue

FROM monthly
ORDER BY year, month;


-- ============================================================
-- STEP 9: CONVERSION FUNNEL
-- Where are people dropping off?
-- Impressions → Clicks → Conversions
-- ============================================================

SELECT
    campaign_type,
    SUM(impressions)   AS impressions,
    SUM(clicks)        AS clicks,
    SUM(conversions)   AS conversions,

    -- What % of people who saw the ad clicked it?
    ROUND(SUM(clicks) * 100.0 / SUM(impressions), 2)     AS click_rate_pct,

    -- What % of people who clicked actually bought?
    ROUND(SUM(conversions) * 100.0 / SUM(clicks), 2)     AS conversion_rate_pct,

    -- How many people dropped off at each stage?
    SUM(impressions) - SUM(clicks)   AS dropped_before_click,
    SUM(clicks) - SUM(conversions)   AS dropped_before_conversion

FROM marketing_campaign
GROUP BY campaign_type
ORDER BY conversion_rate_pct DESC;


-- ============================================================
-- STEP 10: BUDGET WASTE FINDER
-- Show campaigns that are losing money and how much
-- ============================================================

SELECT
    campaign_type,
    channel,
    region,
    COUNT(*)                                        AS losing_campaigns,
    ROUND(SUM(campaign_cost), 2)                    AS money_spent,
    ROUND(SUM(revenue_generated), 2)                AS money_earned,
    ROUND(SUM(campaign_cost) - SUM(revenue_generated), 2) AS money_lost

FROM marketing_campaign

-- Only show campaigns where we spent more than we earned
WHERE campaign_cost > revenue_generated

GROUP BY campaign_type, channel, region
ORDER BY money_lost DESC
LIMIT 20;


-- ============================================================
-- STEP 11: CAMPAIGN QUARTILE RANKING
-- Split all campaigns into 4 equal groups (quartiles)
-- Bottom 25% = Cut, Top 25% = Scale
-- ============================================================

WITH campaign_scores AS (
    SELECT
        campaign_id,
        campaign_type,
        channel,
        region,
        ROUND((revenue_generated - campaign_cost)
              / campaign_cost * 100, 2)             AS roi_pct,

        -- Split into 4 groups: 1=worst, 4=best
        NTILE(4) OVER (ORDER BY (revenue_generated - campaign_cost)
                                / campaign_cost)    AS quartile
    FROM marketing_campaign
)

SELECT
    quartile,
    CASE quartile
        WHEN 1 THEN 'Bottom 25% — Cut'
        WHEN 2 THEN '25 to 50% — Monitor'
        WHEN 3 THEN '50 to 75% — Maintain'
        WHEN 4 THEN 'Top 25% — Scale'
    END                  AS action_label,
    COUNT(*)             AS campaign_count,
    ROUND(MIN(roi_pct), 2) AS worst_roi,
    ROUND(MAX(roi_pct), 2) AS best_roi,
    ROUND(AVG(roi_pct), 2) AS avg_roi
FROM campaign_scores
GROUP BY quartile
ORDER BY quartile;


-- ============================================================
-- STEP 12: CHANNEL vs REGION CROSS ANALYSIS
-- For each channel, which region performs best?
-- RANK() PARTITION = rank within each channel separately
-- ============================================================

SELECT
    channel,
    region,
    COUNT(*)                                         AS campaigns,
    ROUND(SUM(revenue_generated), 2)                 AS total_revenue,
    ROUND(AVG((revenue_generated - campaign_cost)
              / campaign_cost * 100), 2)             AS avg_roi_pct,

    -- Rank regions WITHIN each channel (resets for each channel)
    RANK() OVER (
        PARTITION BY channel
        ORDER BY AVG((revenue_generated - campaign_cost)
                     / campaign_cost) DESC
    ) AS best_region_rank

FROM marketing_campaign
GROUP BY channel, region
ORDER BY channel, best_region_rank;
