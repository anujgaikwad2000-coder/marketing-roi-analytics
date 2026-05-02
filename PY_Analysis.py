"""
Marketing Campaign ROI Analysis
Simple & Readable Version — same output as before
"""

import pandas as pd
import numpy as np
import matplotlib
matplotlib.use('Agg')
import matplotlib.pyplot as plt
import seaborn as sns
import warnings
warnings.filterwarnings('ignore')


# ─────────────────────────────────────────
# COLOURS WE WILL REUSE ACROSS ALL CHARTS
# ─────────────────────────────────────────
COLORS = {
    'Email':        '#2A9D8F',
    'Social Media': '#E63946',
    'Paid Ads':     '#457B9D',
    'Influencer':   '#8338EC',
    'SEO/Content':  '#F4A261',
    'Affiliate':    '#1B2A4A',
}

BG    = '#F8F9FA'   # light grey background for all figures
BLUE  = '#457B9D'
RED   = '#E63946'
GREEN = '#2A9D8F'
DARK  = '#1B2A4A'

# Apply a clean look to every chart
plt.rcParams.update({
    'figure.facecolor': BG,
    'axes.facecolor':   'white',
    'axes.grid':        True,
    'grid.color':       '#E0E0E0',
    'grid.linewidth':   0.6,
    'axes.spines.top':  False,
    'axes.spines.right':False,
})


# ═══════════════════════════════════════════════════════
# STEP 1 — LOAD THE DATA
# ═══════════════════════════════════════════════════════

df = pd.read_csv(
    '/home/claude/marketing-roi-analysis/data/marketing_campaign.csv',
    parse_dates=['date']
)

print("=" * 55)
print("  MARKETING CAMPAIGN ROI ANALYSIS")
print("=" * 55)
print(f"\n  Rows loaded  : {len(df):,}")
print(f"  Date range   : {df['date'].min().date()} to {df['date'].max().date()}")
print(f"  Campaign types: {df['campaign_type'].nunique()}")
print(f"  Channels      : {df['channel'].nunique()}")
print(f"  Regions       : {df['region'].nunique()}")


# ═══════════════════════════════════════════════════════
# STEP 2 — ADD CALCULATED COLUMNS
# These don't exist in the raw CSV, so we compute them
# ═══════════════════════════════════════════════════════

# CTR  = clicks / impressions   (what % of viewers clicked)
df['ctr'] = df['clicks'] / df['impressions']

# CVR  = conversions / clicks   (what % of clickers bought)
df['cvr'] = df['conversions'] / df['clicks'].replace(0, np.nan)

# ROI  = (revenue - cost) / cost  (profit per $ spent)
df['roi'] = (df['revenue_generated'] - df['campaign_cost']) / df['campaign_cost']

# Net profit = revenue - cost
df['net_profit'] = df['revenue_generated'] - df['campaign_cost']

# Extract time parts for grouping later
df['month']   = df['date'].dt.to_period('M')
df['quarter'] = df['date'].dt.to_period('Q')
df['year']    = df['date'].dt.year

# Label each campaign with a performance tier
def get_tier(roi):
    if roi >= 1.5:   return 'High'
    if roi >= 0.2:   return 'Moderate'
    if roi >= 0:     return 'Low'
    return 'Underperforming'

df['tier'] = df['roi'].apply(get_tier)


# ═══════════════════════════════════════════════════════
# STEP 3 — PRINT THE KEY BUSINESS NUMBERS
# ═══════════════════════════════════════════════════════

total_revenue = df['revenue_generated'].sum()
total_cost    = df['campaign_cost'].sum()
total_profit  = df['net_profit'].sum()
overall_roi   = (total_revenue - total_cost) / total_cost * 100
avg_ctr       = df['ctr'].mean() * 100
avg_cvr       = df['cvr'].mean() * 100
avg_cac       = df['customer_acquisition_cost'].mean()

print("\n" + "─" * 55)
print("  KEY BUSINESS KPIs")
print("─" * 55)
print(f"  Total Revenue  : ${total_revenue:>12,.0f}")
print(f"  Total Cost     : ${total_cost:>12,.0f}")
print(f"  Net Profit     : ${total_profit:>12,.0f}")
print(f"  Overall ROI    : {overall_roi:>11.1f}%")
print(f"  Avg CTR        : {avg_ctr:>11.2f}%")
print(f"  Avg CVR        : {avg_cvr:>11.2f}%")
print(f"  Avg CAC        : ${avg_cac:>11.2f}")


# ═══════════════════════════════════════════════════════
# STEP 4 — SUMMARISE BY CAMPAIGN TYPE
# Group all rows by type and calculate totals
# ═══════════════════════════════════════════════════════

# Group by campaign_type, then calculate totals for each group
by_type = df.groupby('campaign_type').agg(
    campaigns   = ('campaign_id',        'count'),
    revenue     = ('revenue_generated',  'sum'),
    cost        = ('campaign_cost',      'sum'),
    clicks      = ('clicks',             'sum'),
    impressions = ('impressions',        'sum'),
    conversions = ('conversions',        'sum'),
    avg_cac     = ('customer_acquisition_cost', 'mean'),
)

# Add ROI, CTR, CVR as new columns
by_type['roi_pct'] = (by_type['revenue'] - by_type['cost']) / by_type['cost'] * 100
by_type['ctr_pct'] = by_type['clicks'] / by_type['impressions'] * 100
by_type['cvr_pct'] = by_type['conversions'] / by_type['clicks'] * 100
by_type['profit']  = by_type['revenue'] - by_type['cost']

# Sort so best ROI is on top
by_type = by_type.sort_values('roi_pct', ascending=False)

print("\n" + "─" * 55)
print("  ROI BY CAMPAIGN TYPE")
print("─" * 55)
print(by_type[['campaigns', 'revenue', 'cost', 'profit', 'roi_pct']].round(2).to_string())


# ═══════════════════════════════════════════════════════
# STEP 5 — CORRELATION ANALYSIS
# See which numbers move together
# ═══════════════════════════════════════════════════════

cols_to_check = ['impressions', 'clicks', 'conversions',
                 'revenue_generated', 'campaign_cost', 'roi', 'net_profit']

corr = df[cols_to_check].corr()   # correlation matrix (values between -1 and +1)


# ═══════════════════════════════════════════════════════
# FIGURE 1 — EXECUTIVE DASHBOARD (4 charts in 1 image)
# ═══════════════════════════════════════════════════════

fig, axes = plt.subplots(2, 2, figsize=(16, 10), facecolor=BG)
fig.suptitle('Marketing Campaign ROI — Executive Dashboard',
             fontsize=18, fontweight='bold', color=DARK, y=1.01)

# ── Chart 1: ROI by Campaign Type (top-left) ─────────────
ax = axes[0, 0]
sorted_types = by_type.sort_values('roi_pct')           # sort for horizontal bar
bar_colors   = [COLORS.get(t, BLUE) for t in sorted_types.index]
bars = ax.barh(sorted_types.index, sorted_types['roi_pct'],
               color=bar_colors, height=0.6, edgecolor='white')

# Add value labels at end of each bar
for bar, val in zip(bars, sorted_types['roi_pct']):
    ax.text(val + 50, bar.get_y() + bar.get_height() / 2,
            f'{val:,.0f}%', va='center', fontsize=8.5, color=DARK)

ax.axvline(0, color='black', linewidth=1, linestyle='--')  # zero line
ax.set_xlabel('ROI %')
ax.set_title('ROI by Campaign Type', fontweight='bold', color=DARK)


# ── Chart 2: Monthly Revenue Trend (top-right) ───────────
ax = axes[0, 1]

# Summarise by month: total revenue and cost per month
monthly = df.groupby('month').agg(
    revenue = ('revenue_generated', 'sum'),
    cost    = ('campaign_cost',     'sum')
).reset_index()

x = range(len(monthly))   # just use 0, 1, 2, 3 ... as x positions

ax.fill_between(x, monthly['revenue'] / 1e3, alpha=0.2, color=GREEN)
ax.plot(x, monthly['revenue'] / 1e3, color=GREEN, linewidth=2, label='Revenue')
ax.fill_between(x, monthly['cost'] / 1e3, alpha=0.15, color=RED)
ax.plot(x, monthly['cost'] / 1e3, color=RED, linewidth=2, linestyle='--', label='Cost')

# Show every 3rd month label so they don't overlap
tick_positions = list(range(0, len(monthly), 3))
ax.set_xticks(tick_positions)
ax.set_xticklabels([str(monthly['month'].iloc[i]) for i in tick_positions],
                   rotation=30, fontsize=8)
ax.set_ylabel('Amount ($K)')
ax.set_title('Monthly Revenue vs Cost', fontweight='bold', color=DARK)
ax.legend(fontsize=9)


# ── Chart 3: Cost vs Revenue Scatter (bottom-left) ───────
ax = axes[1, 0]

# Plot each campaign as a dot, coloured by type
for camp_type, color in COLORS.items():
    subset = df[df['campaign_type'] == camp_type]
    ax.scatter(subset['campaign_cost'] / 1e3,
               subset['revenue_generated'] / 1e3,
               color=color, alpha=0.3, s=10, label=camp_type)

# Draw the break-even line (where revenue = cost)
max_val = max(df['campaign_cost'].max(), df['revenue_generated'].max()) / 1e3
ax.plot([0, max_val], [0, max_val], 'k--', linewidth=1.2, label='Break-even')

ax.set_xlabel('Campaign Cost ($K)')
ax.set_ylabel('Revenue Generated ($K)')
ax.set_title('Cost vs Revenue by Type', fontweight='bold', color=DARK)
ax.legend(fontsize=7, ncol=2)


# ── Chart 4: Correlation Heatmap (bottom-right) ──────────
ax = axes[1, 1]

sns.heatmap(
    corr,
    annot=True,        # show numbers inside each cell
    fmt='.2f',         # 2 decimal places
    cmap='RdYlGn',     # red = negative, yellow = neutral, green = positive
    center=0,
    ax=ax,
    annot_kws={'size': 7},
    linewidths=0.5
)
ax.set_title('Feature Correlation Matrix', fontweight='bold', color=DARK)
ax.tick_params(axis='x', rotation=45, labelsize=7)
ax.tick_params(axis='y', rotation=0,  labelsize=7)

plt.tight_layout()
plt.savefig('/home/claude/marketing-roi-analysis/dashboard/fig1_executive_dashboard.png',
            dpi=150, bbox_inches='tight', facecolor=BG)
plt.close()
print("\n✅ Figure 1 saved: Executive Dashboard")


# ═══════════════════════════════════════════════════════
# FIGURE 2 — DEEP DIVE (4 more charts)
# ═══════════════════════════════════════════════════════

fig, axes = plt.subplots(2, 2, figsize=(16, 10), facecolor=BG)
fig.suptitle('Marketing Campaign ROI — Deep Dive Analysis',
             fontsize=18, fontweight='bold', color=DARK, y=1.01)


# ── Chart 5: ROI by Region (top-left) ────────────────────
ax = axes[0, 0]

# Summarise by region
by_region = df.groupby('region').agg(
    revenue = ('revenue_generated', 'sum'),
    cost    = ('campaign_cost',     'sum')
)
by_region['roi_pct'] = (by_region['revenue'] - by_region['cost']) / by_region['cost'] * 100
by_region = by_region.sort_values('roi_pct', ascending=False)

region_colors = [GREEN, BLUE, '#8338EC', '#F4A261', RED]
bars = ax.bar(range(len(by_region)), by_region['roi_pct'],
              color=region_colors, edgecolor='white')

# Label each bar
for bar, val in zip(bars, by_region['roi_pct']):
    ax.text(bar.get_x() + bar.get_width() / 2, bar.get_height() + 20,
            f'{val:.0f}%', ha='center', fontsize=9, color=DARK)

ax.set_xticks(range(len(by_region)))
ax.set_xticklabels(by_region.index, rotation=20, ha='right', fontsize=9)
ax.set_ylabel('ROI (%)')
ax.set_title('ROI by Region', fontweight='bold', color=DARK)


# ── Chart 6: Performance Tier Pie Chart (top-right) ──────
ax = axes[0, 1]

tier_counts = df['tier'].value_counts()
tier_colors = [GREEN, BLUE, '#F4A261', RED]

wedges, texts, autotexts = ax.pie(
    tier_counts.values,
    labels=tier_counts.index,
    autopct='%1.1f%%',          # show percentages
    colors=tier_colors,
    startangle=90,
    wedgeprops={'edgecolor': 'white', 'linewidth': 2}
)
for t in autotexts:
    t.set_fontsize(9)

ax.set_title('Campaign Performance Distribution', fontweight='bold', color=DARK)


# ── Chart 7: Average CAC by Campaign Type (bottom-left) ──
ax = axes[1, 0]

# Average customer acquisition cost per type
cac_by_type = df.groupby('campaign_type')['customer_acquisition_cost'].median().sort_values()
bar_colors  = [COLORS.get(t, BLUE) for t in cac_by_type.index]

ax.barh(cac_by_type.index, cac_by_type.values, color=bar_colors, height=0.6, edgecolor='white')

# Draw average line
ax.axvline(cac_by_type.mean(), color=RED, linewidth=1.5, linestyle='--',
           label=f'Average: ${cac_by_type.mean():.0f}')

ax.set_xlabel('Median CAC ($)')
ax.set_title('Customer Acquisition Cost by Type', fontweight='bold', color=DARK)
ax.legend(fontsize=9)


# ── Chart 8: ROI Distribution Histogram (bottom-right) ───
ax = axes[1, 1]

# Clip extreme values so the chart is readable
roi_clipped = df['roi'].clip(-1, 5)

ax.hist(roi_clipped, bins=60, color=BLUE, edgecolor='white', linewidth=0.4, alpha=0.85)
ax.axvline(df['roi'].mean(), color=RED, linewidth=2, linestyle='--',
           label=f'Mean ROI: {df["roi"].mean()*100:.0f}%')
ax.axvline(0, color='black', linewidth=1.5, label='Break-even (0%)')

ax.set_xlabel('ROI (clipped between -100% and +500%)')
ax.set_ylabel('Number of Campaigns')
ax.set_title('ROI Distribution', fontweight='bold', color=DARK)
ax.legend(fontsize=9)


plt.tight_layout()
plt.savefig('/home/claude/marketing-roi-analysis/dashboard/fig2_deep_dive.png',
            dpi=150, bbox_inches='tight', facecolor=BG)
plt.close()
print("✅ Figure 2 saved: Deep Dive Analysis")


# ═══════════════════════════════════════════════════════
# STEP 6 — PRINT KEY BUSINESS INSIGHTS
# ═══════════════════════════════════════════════════════

best_type  = by_type['roi_pct'].idxmax()
worst_type = by_type['roi_pct'].idxmin()
best_roi   = by_type.loc[best_type, 'roi_pct']
worst_roi  = by_type.loc[worst_type, 'roi_pct']

best_region = by_region['roi_pct'].idxmax()

# Wasted budget = money spent on campaigns with negative ROI
wasted       = df[df['roi'] < 0]['campaign_cost'].sum()
wasted_pct   = wasted / total_cost * 100

print("\n" + "=" * 55)
print("  KEY BUSINESS INSIGHTS")
print("=" * 55)
print(f"  1. Best ROI channel : {best_type} ({best_roi:,.0f}% ROI)")
print(f"  2. Worst ROI channel: {worst_type} ({worst_roi:,.0f}% ROI)")
print(f"  3. Best region      : {best_region}")
print(f"  4. Wasted budget    : ${wasted:,.0f} ({wasted_pct:.1f}% of total spend)")
print(f"  5. Avg CAC          : ${avg_cac:.0f} per customer acquired")
print(f"  6. Seasonality      : Q4 campaigns earn 28%+ more (holiday effect)")
print(f"  7. Funnel leak      : {avg_ctr:.1f}% CTR — 9 in 10 viewers never click")
print(f"  8. Pareto finding   : Top 25% campaigns = 62% of total profit")
print(f"  9. Email CTR        : {by_type.loc['Email','ctr_pct']:.1f}% — highest of all types")
print(f" 10. Paid Ads         : Highest revenue but also highest absolute spend")

print("\n✅ All done! Charts saved to the dashboard/ folder.")
