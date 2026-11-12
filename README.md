# Crowded forests by state

Companion dashboard to a Conversation US article by Aaron Weiskittel, Adam Daigneault, and Christopher Woodall (University of Maine, CTrees), November 2026. The article: https://theconversation.com/cutting-down-a-christmas-tree-wont-hurt-the-forest-but-too-many-trees-left-crowding-the-woods-might-295233

A single static page (`index.html`) with the data inlined and d3 7.9.0 vendored, so it serves from GitHub Pages with no build step.

## Data (updated November 12, 2026)

- `dash_state_crowding_damage_subplot.csv`: 48 lower 48 states. Each remeasured Forest Inventory and Analysis plot visit is one sample, with crowding (relative density, stand density index over its site maximum) averaged over the plot's four fixed-area subplots at the earlier visit. Columns: `n_plots`, `n_conditions` (here the number of remeasured plot visits; the column name is kept for the page code), `plots_crowded_pct` (share of plot visits with relative density of 0.6 or more), `damage_open_pct` and `damage_crowded_pct` (share of open, under 0.35, and crowded, 0.6 or more, plot visits with any recorded natural disturbance by the next visit), `diff_points` with a 95% plot-level cluster bootstrap range (`diff_lo_points`, `diff_hi_points`; 4,000 resamples of whole plots within each state, percentile limits, since most plots were visited more than once), `signal` (higher in crowded, no clear difference, lower in crowded, or too few plots when either class has under 100 plot visits), `top_cause` and `top_cause_share` (the agent recorded most often among the state's disturbed plot visits), `n_open`, `n_crowded`, `small_sample`.
- `dash_national_by_class_subplot.csv`: the same by crowding class for the lower 48, 228,797 plot visits, 1999 to 2026.
- `dash_carbon_context.csv`: published findings the article cites, with sources.

- `dash_annual_risk_curve.csv` (added November 12, 2026): the national annual probability of any recorded natural disturbance by relative density, with its 95% interval, from the annual hazard model (complementary log-log with a log remeasurement-interval offset; forest type, stand age, and ecological section as covariates). Source file `curves.csv` in the Zenodo record.
- `dash_agent_hazard_ratios.csv` (added November 12, 2026): hazard ratio per 0.5 relative density for each disturbance agent with its 95% interval (`table_agents_OR.csv` in the record). The page shows these as percent changes.
- `dash_state_risk_carbon.csv` (added November 12, 2026): by state, forest area, median relative density, the mean predicted annual probability of disturbance, and the expected annual transfer of live aboveground carbon to dead pools (Tg C per year), from `national_carbon_by_state.csv` in the record. The 48 state transfers sum to the national 39.5 Tg C per year (95% interval 23.7 to 58.8, clustered by ecological section). State intervals have not been computed, and the page says so.
- Page figures also quoted from the record: the contrast between relative density 0.3 and 0.6 (ratio 1.09, 1.04 to 1.15 nationally; 1.02, 0.96 to 1.08 East; 1.26, 1.17 to 1.38 West; `contrast_03_06.csv`) and the transfer linked to plots above the median relative density (3.47 Tg C per year, 2.00 to 6.57; `carbon_revision_specs.csv`).

The state gap columns are raw shares, not design-based estimates, and not adjusted for forest type, age, or location. The adjusted results are in the study's code and summary record, doi 10.5281/zenodo.23886182. Not yet peer reviewed. No plot coordinates or identifiers are included. The earlier condition-area files (`*_cp.csv`) are superseded and kept only for the record.

## Source

Weiskittel, A.R., Chivhenge, E., Woodall, C.W., D'Amato, A.W., Daigneault, A. (2026). Data and code: relative density and forest disturbance on the FIA subplot design (conterminous United States, 1999 to 2026). Zenodo, doi 10.5281/zenodo.23886182.

## License

Code MIT, data and text CC BY 4.0.


## Page revision, November 12, 2026

Added the annual risk curve, the agent chart, a third map view (yearly chance of damage), state risk and carbon columns, and a methods panel; replaced the between-visit adjusted figures in the national panel with the annual model; set type and color from the Weiskittel Lab design system (Libre Franklin, Source Sans 3, CRSF green). Latest record version 4.3.0, doi 10.5281/zenodo.24147574.
