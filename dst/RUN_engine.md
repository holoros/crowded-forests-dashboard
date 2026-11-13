# rd_dst_engine_20261112 (12 November 2026)
Host: firebreather. Rscript (R) version 4.5.1 (2025-06-13). Packages: data.table, mgcv (bam fREML, discrete), parallel. Seed 20261112. B = 200 (engine), 50 (type group).
Input: dst_engine_input_DATA.rds md5 184601b2e0eb706c9bdfbf2bd279ec02 (built on Cardinal from typeeco/out; no coordinates).
Scripts: 2026-11-12_rd-dst-engine_DRAFT.R (md5 e2c356e6fa090de9ca21107fc6e38996), 2026-11-12_rd-dst-engine-typegroup_DRAFT.R (md5 73dd64ad3e930f03a4e825f807c3263d).
Launch: NBOOT=200 Rscript --vanilla 2026-11-12_rd-dst-engine_DRAFT.R; Rscript --vanilla 2026-11-12_rd-dst-engine-typegroup_DRAFT.R. Wall time 7.6 min and about 15 min.
Row shuffle: identical point estimates in all 4 regions and all 13 region x type group fits.
GitHub: holoros/crowded-forests-dashboard PR 1 (commit 11f76fa). Zenodo: not applicable (intermediate decision support build, not yet citable).

## Engine v2 (12 November 2026)
Host: firebreather (shared; load 10 to 30 during the run). Rscript (R) version 4.5.1 (2025-06-13); data.table, mgcv (bam fREML discrete), parallel. Seeds 20261112 (fits, B = 200), 30261112 (checks, B = 100). 4 cores.
Inputs: dst_engine_input_DATA.rds md5 184601b2e0eb706c9bdfbf2bd279ec02; dst_natdist_flags_DATA.rds (Cardinal, 2026-11-12_rd-dst-natdist-audit_DRAFT.R).
Runs: engine v2 (first run failed after the regional fits on a Tweedie table bug; rerun with per region checkpoints), checks script (confounding), lag check (tolerant previous visit match; the first lag attempt matched every interval to itself and was killed).
Row shuffle: identical point estimates in all four regions.
Outputs: output_v2/ (aggregates only). GitHub: this branch. Zenodo: not applicable (draft decision support build).

## Engine v2 follow-up checks (12 November 2026, evening)
2026-11-12_rd-dst-engine-v2-esi-ipw_DRAFT.R (md5 80ed7e71...): ESI v6r 1 km at public FIA coordinates (66,326 of 85,821 plots) and harvest attrition weights (dst_ipw_DATA.rds md5 e62b6a7c..., from te_pairs_ipw.rds), B = 100, run with the geos activation (terra).
2026-11-12_rd-dst-engine-v2-type_DRAFT.R (md5 c832019a...): direct net curves by region x forest type group (13 groups, >= 6,000 intervals), full height grid, B = 100, shuffle identical in all 13.
Outputs: output_v2/dst_engine2_esi_ipw_DATA.csv, dst_engine2_esi_summary_DATA.csv, dst_engine2_type_curves_DATA.csv, dst_engine2_type_stats_DATA.csv (aggregates only).
