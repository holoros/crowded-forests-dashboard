# Crowded forests by state

Companion dashboard to a Conversation US article by Aaron Weiskittel, Adam Daigneault, and Christopher Woodall (University of Maine, CTrees), November 2026.

A single static page (`index.html`) with the data inlined and d3 7.9.0 vendored, so it serves from GitHub Pages with no build step. The same page runs as a Claude dashboard artifact; this copy is the public mirror.

## Data

- `dash_state_crowding_damage_cp.csv`: 47 lower 48 states. Columns: `n_plots` and `n_conditions` (all remeasured plots and conditions in the state), `plots_crowded_pct` (share of conditions with relative density at or above two thirds at the first visit), `damage_open_pct` and `damage_crowded_pct` (share of open, under one third, and crowded conditions with any recorded disturbance by the next visit), `diff_points` with a 1,000 draw plot clustered bootstrap range (`diff_lo_points`, `diff_hi_points`), `signal` (higher in crowded, no clear difference, lower in crowded, or too few plots when either class has under 100 conditions), `top_cause` and `top_cause_share` (the agent recorded most often among the state's damaged conditions), `n_open`, `n_crowded`, `small_sample`. Relative density is measured over the area each stand occupies (the condition area basis of the preprint below).
- `dash_national_by_class_cp.csv`: the same by crowding class for the lower 48, 148,604 conditions.
- `dash_carbon_context.csv`: five published carbon findings the article cites, with sources.

Computed on OSC Cardinal from the preprint's analysis table (148,604 conditions on 121,035 plots), October 29, 2026 (SLURM job 15979164 for the bootstrap, an interactive run for totals and causes; scripts in the Zenodo companion record). Raw condition shares, not design based estimates, and not adjusted for stand size, height, or forest type. Preliminary, not yet peer reviewed. No plot coordinates or identifiers are included.

## Source

Weiskittel, A.R., Chivhenge, E., Woodall, C.W., D'Amato, A.W., Daigneault, A. (2026). Forest density tracks the agent of disturbance more consistently than its risk across the United States. Preprint, version 1, October 26, 2026. doi 10.5281/zenodo.23673229.

## License

Code MIT, data and text CC BY 4.0.
