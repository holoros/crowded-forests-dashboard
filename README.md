# Crowded forests by state

Companion dashboard to a Conversation US article by Aaron Weiskittel, Adam Daigneault, and Christopher Woodall (University of Maine, CTrees), November 2026.

A single static page (`index.html`) with the data inlined and d3 7.9.0 vendored, so it serves from GitHub Pages with no build step.

## Data (updated November 3, 2026)

- `dash_state_crowding_damage_subplot.csv`: 48 lower 48 states. Each remeasured Forest Inventory and Analysis plot visit is one sample, with crowding (relative density, stand density index over its site maximum) averaged over the plot's four fixed-area subplots at the earlier visit. Columns: `n_plots`, `n_conditions` (here the number of remeasured plot visits; the column name is kept for the page code), `plots_crowded_pct` (share of plot visits with relative density of 0.6 or more), `damage_open_pct` and `damage_crowded_pct` (share of open, under 0.35, and crowded, 0.6 or more, plot visits with any recorded natural disturbance by the next visit), `diff_points` with a 95% normal approximation range (`diff_lo_points`, `diff_hi_points`), `signal` (higher in crowded, no clear difference, lower in crowded, or too few plots when either class has under 100 plot visits), `top_cause` and `top_cause_share` (the agent recorded most often among the state's disturbed plot visits), `n_open`, `n_crowded`, `small_sample`.
- `dash_national_by_class_subplot.csv`: the same by crowding class for the lower 48, 228,797 plot visits, 1999 to 2026.
- `dash_carbon_context.csv`: published findings the article cites, with sources.

Raw shares, not design-based estimates, and not adjusted for forest type, age, or location. The adjusted results are in the study's code and summary record, doi 10.5281/zenodo.23886182. Not yet peer reviewed. No plot coordinates or identifiers are included. The earlier condition-area files (`*_cp.csv`) are superseded and kept only for the record.

## Source

Weiskittel, A.R., Chivhenge, E., Woodall, C.W., D'Amato, A.W., Daigneault, A. (2026). Data and code: relative density and forest disturbance on the FIA subplot design (conterminous United States, 1999 to 2026). Zenodo, doi 10.5281/zenodo.23886182.

## License

Code MIT, data and text CC BY 4.0.
