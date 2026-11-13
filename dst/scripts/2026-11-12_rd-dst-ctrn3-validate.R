## ==== PRE-REGISTERED DESIGN (written before any data were analysed; not changed after results) ====
## - Unit: plot. Intervals: pair each plot's visits into non-overlapping spans of 4 to 6 years (first visit at or after thinning year for thinned plots; any visit for controls; skip spans that straddle the thinning).
## - Response: survivor basal area growth (m2 ha-1 yr-1) from trees alive at both ends of the span, linked by Tree within PlotID, DBH >= 2.54 cm, PTF at the start visit; secondary: net BA change including ingrowth and mortality.
## - RD at span start = sum(PTF * (DBH/25.4)^1.605) / SDImax, SDImax = 1,132 (primary), sensitivity 451 and 2,080. Top height = mean height of the largest 100 trees ha-1 with missing heights filled by a per plot fit ln(HT) = a + b/DBH.
## - Model: response ~ RD class + log(top height), weighted by span length, classes fixed in advance on the primary axis: [0.20,0.335), [0.335,0.435), [0.435,0.535), [0.535,0.70), [0.70,1.30]. The North floor is 0.435; the band is 0.435 to 0.535.
## - Contrasts: band class minus the class just below (floor test); band minus [0.535,0.70); band minus [0.70,1.30]. Whole plot bootstrap B = 2,000, 95% percentile intervals, seed 20261112.
## - Equivalence margin: 10% of the band class mean. Floor supported if the band minus below contrast is positive with the lower bound above 0. "No ceiling" is supported only if the band minus above contrasts fall inside the equivalence margin (TOST 90% interval within plus or minus margin). Otherwise report "not distinguishable" or "ceiling indicated" as the data say.
## - Power: by simulation from the bootstrap SE, the smallest true contrast detectable with 80% power.
## - Row shuffle: refit point estimates on a shuffled table and report identical TRUE/FALSE.
## ==== END PRE-REGISTERED DESIGN ====
##
## Implementation rules fixed before results (operational detail the block leaves open):
## * Live = view column Live == 1 (unknown status 0 counts as not live); start trees need DBH >= 2.54 and PTF > 0.
## * Span rule: sort eligible visits by year; from visit i take the earliest later visit j with gap >= 4; keep if gap <= 6, then i = j; else i = i + 1.
##   A span is skipped if any treatment year t has start < t <= end; a visit in the thinning year counts as post thinning.
## * Thinned and control: CTRN thinned = CT record (first CT year) or RegimeCTRN 'thinned%' with TrtYrCTRN; control = RegimeCTRN 'control'
##   or (RegimeCTRN null and location Control = 1); other CTRN plots (no regime, no treatment, non control location; or regime 'thinned' with
##   no year) are excluded. PEF/PCTF thinned = CT; UNB/PSP16 thinned = PC (first PC year); for both, controls = plots with no treatment record.
##   A secondary dataset is analysed only if >= 30 thinned plots have a valid post thinning span.
## * Height fill: per plot fit (all visits, live trees with HT > 1.3 m, >= 5 heights); plots with fewer use one pooled dataset fit (count logged).
## * Survivor growth = sum(PTF_start * pi/40000 * (DBH_end^2 - DBH_start^2)) / span years, trees Live at both ends; increments not trimmed.
##   Net change = (live BA_end - live BA_start) / span years, each end with its own PTF and DBH >= 2.54.
## * Sensitivity SDImax values use the same class cut points on their own RD axis; spans with RD outside [0.20, 1.30] are dropped per axis.
## * Band class mean (for margin) = span length weighted mean response of band class spans. TOST 90% = 5th and 95th bootstrap percentiles.
## * Verdicts: floor row: 'floor supported' if est > 0 and lo > 0; 'floor contradicted' if hi < 0; else 'not distinguishable'.
##   above rows: 'no ceiling supported' if TOST 90% inside +/- margin; else 'ceiling indicated' if lo > 0; 'denser class higher' if hi < 0; else 'not distinguishable'.
## * Bootstrap resamples whole plots from all plots of a dataset (same draws for every SDImax and response); refits with empty classes give NA and are dropped;
##   a contrast with an empty class in the full data (or < 100 usable refits) is reported as 'not estimable (empty class)'.
## * Power: est ~ N(delta, SE_boot); detection = est - 1.96 SE > 0; MDE = smallest delta (grid 0.01 SE) with power >= 0.80, 20,000 draws.
## * Plot-level tables stay on the server (_plotlevel/); only aggregate CSVs are written to the job folder root.
##
## ==== CTRN3 EXTENSION NOTE (2026-11-12; written before any CTRN3 data were analysed) ====
## The pre-registered design block above is unchanged and applies as written. Only the dataset list and the treatment-group mapping change.
## New datasets screened (all gydb-acadian datasets not analysed in CTRN2; CFRU/CTRN and UNB/PSP16 were analysed and PEF/PCTF was screened in CTRN2):
##   AFERP/OS, BSP/CFI, FIA/v4.0, HOLT/INV, HOWLAND/INV, MNAP/ERN, NB/CLI, NETN/ACAD, NFI/GP, NS/PSP, NS/RPSP, ON/PSPPGP,
##   PEF/CFI, PEF/MID, PE/PSP, QC/PSP, SBW/GIS, SILC/CFI. NS/RPSP has no 2_Standardized database in the build and is listed as not screenable.
## Treatment mapping (same for every dataset): a thinning-type record is an SV_PlotTreatments row with TreatmentGroup 'CT' (commercial thinning),
##   'PCT' (precommercial thinning/spacing), or 'PC' whose Description starts with 'Selection cutting' (partial cutting, single tree, group, patch,
##   strip, sanitation, general selection). Thinned plot = any thinning-type record; thin year = first thinning-type year.
##   Not thinning-type: 'CC' (clearcut, salvage, deforestation), 'CL' (cleaning, stand tending), 'PLT' (planting), NA group (site prep, seeding,
##   chemical cleaning, burn), 'PC' with Description 'Cutting' (generic cutting, FIA TRTCD 10; may be a clearcut), and 'PC' shelterwood cuts.
##   Control = plot with no SV_PlotTreatments record at all (as for UNB/PSP16 in CTRN2). Plots with only non thinning-type records are excluded.
##   All treatment years of a plot (any group) are used for the straddle rule, as in CTRN2.
## Eligibility (unchanged rule): >= 30 thinned plots with a valid post thinning span of 4 to 6 yr, plus >= 1 control plot with a valid span.
## Code changes beyond the mapping: output prefix ctrn3_; eligibility CSV columns (dataset, treated_plots, eligible_treated_plots, control_plots
##   [controls with a valid span], eligible, reason, generic_cutting_plots); a guard so datasets with no spans return cleanly.
## ==== END CTRN3 EXTENSION NOTE ====

t_start <- Sys.time()
suppressPackageStartupMessages({ library(DBI); library(RSQLite); library(data.table) })
SEED <- 20261112L; B <- 2000L
BRK <- c(0.20, 0.335, 0.435, 0.535, 0.70, 1.30)
CLS <- c("[0.20,0.335)", "[0.335,0.435)", "[0.435,0.535)", "[0.535,0.70)", "[0.70,1.30]")
SDIMAX <- c(1132, 451, 2080)
base <- path.expand("~/gydb2/build/ws/gydb-acadian/data")
DB <- c(AFERP_OS = "AFERP/OS", BSP_CFI = "BSP/CFI", FIA_v4.0 = "FIA/v4.0", HOLT_INV = "HOLT/INV", HOWLAND_INV = "HOWLAND/INV", MNAP_ERN = "MNAP/ERN",
  NB_CLI = "NB/CLI", NETN_ACAD = "NETN/ACAD", NFI_GP = "NFI/GP", NS_PSP = "NS/PSP", ON_PSPPGP = "ON/PSPPGP", PEF_CFI = "PEF/CFI", PEF_MID = "PEF/MID",
  PE_PSP = "PE/PSP", QC_PSP = "QC/PSP", SBW_GIS = "SBW/GIS", SILC_CFI = "SILC/CFI")   # NS/RPSP: no standardized database, added to eligibility table below
dbfile <- function(k) file.path(base, DB[[k]], "2_Standardized/Standardized.sqlite")
dir.create("_plotlevel", showWarnings = FALSE)
lg <- function(...) { cat(format(Sys.time(), "%H:%M:%S"), ..., "\n"); flush.console() }

## ---- treatment status per dataset ----
status_tab <- function(k, con) {
  tr <- setDT(dbGetQuery(con, "select PlotID, YR, TreatmentGroup, Description from SV_PlotTreatments"))
  pl <- setDT(dbGetQuery(con, "select PlotID from S_Plots"))
  tr[, thinlike := TreatmentGroup %in% c('CT', 'PCT') | (TreatmentGroup %in% 'PC' & grepl('^Selection cutting', Description))]
  allyrs <- tr[, .(tyrs = list(sort(unique(YR)))), by = PlotID]
  th <- tr[thinlike == TRUE, .(thin_yr = as.numeric(min(YR))), by = PlotID]
  p <- merge(pl[, .(PlotID)], th, by = "PlotID", all.x = TRUE)
  p[, grp := fifelse(!is.na(thin_yr), "thinned", fifelse(PlotID %in% tr$PlotID, "excluded", "control"))]
  p <- merge(p, allyrs, by = "PlotID", all.x = TRUE)
  attr(p, "generic_cut") <- uniqueN(tr[TreatmentGroup %in% 'PC' & Description %in% 'Cutting', PlotID])
  p[, .(PlotID, grp, thin_yr, tyrs)][, gcut := attr(p, "generic_cut")][]
}

## ---- span builder ----
make_spans <- function(yrs, vids, start_min, tyrs) {
  o <- order(yrs); yrs <- yrs[o]; vids <- vids[o]
  keep <- yrs >= start_min; yrs <- yrs[keep]; vids <- vids[keep]
  n <- length(yrs); out <- list(); i <- 1L
  while (i < n) {
    j <- which(yrs > yrs[i] & (yrs - yrs[i]) >= 4)
    if (length(j) == 0) break
    j <- j[1]; gap <- yrs[j] - yrs[i]
    strad <- length(tyrs) > 0 && any(tyrs > yrs[i] & tyrs <= yrs[j])
    if (gap <= 6 && !strad) { out[[length(out) + 1]] <- c(vids[i], vids[j], yrs[i], yrs[j]); i <- j } else i <- i + 1L
  }
  if (length(out) == 0) return(NULL)
  m <- do.call(rbind, out); data.table(v0 = m[, 1], v1 = m[, 2], y0 = as.numeric(m[, 3]), y1 = as.numeric(m[, 4]))
}

## ---- build spans for one dataset ----
build <- function(k) {
  con <- dbConnect(SQLite(), dbfile(k)); on.exit(dbDisconnect(con))
  st <- status_tab(k, con)
  lg(k, "status:", paste(names(table(st$grp)), table(st$grp), collapse = " "))
  vis <- setDT(dbGetQuery(con, "select PlotID, VisitID, YR from S_Visits"))
  vis <- merge(vis, st[grp != "excluded"], by = "PlotID")
  sp <- vis[, {
    s <- make_spans(YR, VisitID, if (grp[1] == "thinned") thin_yr[1] else -Inf, tyrs[[1]])
    if (is.null(s)) NULL else s
  }, by = .(PlotID, grp)]
  if (nrow(sp) == 0 || !"v0" %in% names(sp)) { sp <- data.table(PlotID = integer(), grp = character(), v0 = character(), v1 = character(), y0 = numeric(), y1 = numeric()) }
  sp[, v0 := as.character(v0)][, v1 := as.character(v1)]
  n_thin_ok <- uniqueN(sp[grp == "thinned", PlotID])
  lg(k, "spans:", nrow(sp), "plots:", uniqueN(sp$PlotID), "thinned plots with span:", n_thin_ok)
  n_ctrl_ok <- uniqueN(sp[grp == "control", PlotID])
  why <- if (sum(st$grp == "thinned") == 0) "no thinning-type treatment records" else if (n_thin_ok < 30) sprintf("%d thinned plots with a 4 to 6 yr post thinning span (< 30)", n_thin_ok) else if (n_ctrl_ok < 1) "no control plots with a valid span" else "meets rule"
  elig <- data.table(dataset = k, treated_plots = sum(st$grp == "thinned"), eligible_treated_plots = n_thin_ok, control_plots = n_ctrl_ok,
    eligible = n_thin_ok >= 30 && n_ctrl_ok >= 1, reason = why, generic_cutting_plots = st$gcut[1])
  lg(k, "eligible:", elig$eligible, why)
  if (!elig$eligible) return(list(spans = NULL, elig = elig))
  t0 <- Sys.time()
  tr <- setDT(dbGetQuery(con, "select PlotID, VisitID, Tree, DBH, HT, Live, PTF from SV_Trees"))
  lg(k, "trees read:", nrow(tr), "in", round(difftime(Sys.time(), t0, units = "secs")), "s")
  tr[, VisitID := as.character(VisitID)]
  tr <- tr[PlotID %in% sp$PlotID]
  live <- tr[Live %in% 1 & !is.na(DBH) & DBH >= 2.54 & !is.na(PTF) & PTF > 0]
  ## height fill
  hm <- live[!is.na(HT) & HT > 1.3]
  pool <- coef(lm(log(HT) ~ I(1 / DBH), data = hm))
  pf <- hm[, if (.N >= 5) { cf <- coef(lm(log(HT) ~ I(1 / DBH))); list(a = cf[1], b = cf[2]) }, by = PlotID]
  live <- merge(live, pf, by = "PlotID", all.x = TRUE)
  n_pool <- uniqueN(live[is.na(a), PlotID])
  live[is.na(a), `:=`(a = pool[1], b = pool[2])]
  live[, H := fifelse(!is.na(HT) & HT > 1.3, HT, exp(a + b / DBH))]
  lg(k, "plots using pooled height fit:", n_pool, "of", uniqueN(live$PlotID))
  ## visit summaries
  topH <- function(d, h, w) { o <- order(-d); d <- d[o]; h <- h[o]; w <- w[o]; cb <- cumsum(w) - w; ww <- pmin(pmax(100 - cb, 0), w); sum(h * ww) / sum(ww) }
  vs <- live[, .(SDI = sum(PTF * (DBH / 25.4)^1.605), BA = sum(PTF * pi * DBH^2 / 40000), TPH = sum(PTF), HT0 = topH(DBH, H, PTF)), by = .(PlotID, VisitID)]
  sp <- merge(sp, vs[, .(PlotID, v0 = VisitID, SDI0 = SDI, BA0 = BA, TPH0 = TPH, HT0)], by = c("PlotID", "v0"))
  sp <- merge(sp, vs[, .(PlotID, v1 = VisitID, BA1 = BA)], by = c("PlotID", "v1"), all.x = TRUE)
  sp[is.na(BA1), BA1 := 0]
  ## survivor growth
  t0s <- live[, .(PlotID, v0 = VisitID, Tree, D0 = DBH, P0 = PTF)]
  t1s <- tr[Live %in% 1 & !is.na(DBH) & DBH > 0, .(PlotID, v1 = VisitID, Tree, D1 = DBH)]
  lk <- merge(sp[, .(PlotID, v0, v1)], t0s, by = c("PlotID", "v0"), allow.cartesian = TRUE)
  lk <- merge(lk, t1s, by = c("PlotID", "v1", "Tree"))
  sg <- lk[, .(SBA = sum(P0 * pi * (D1^2 - D0^2) / 40000)), by = .(PlotID, v0, v1)]
  sp <- merge(sp, sg, by = c("PlotID", "v0", "v1"), all.x = TRUE)
  sp[is.na(SBA), SBA := 0]
  sp[, `:=`(T = y1 - y0, dataset = k)]
  sp[, `:=`(surv = SBA / T, net = (BA1 - BA0) / T)]
  sp <- sp[is.finite(HT0) & HT0 > 0]
  saveRDS(sp, file.path("_plotlevel", paste0(k, "_spans.rds")))
  elig[, `:=`(n_pooled_height_plots = n_pool)]
  list(spans = sp, elig = elig)
}

res <- lapply(names(DB), build)
ELIG <- rbindlist(c(lapply(res, `[[`, "elig"), list(data.table(dataset = "NS_RPSP", treated_plots = NA_integer_, eligible_treated_plots = NA_integer_, control_plots = NA_integer_, eligible = FALSE, reason = "no 2_Standardized database in build (0_Raw csv only)"))), fill = TRUE)
fwrite(ELIG, "ctrn3_dataset_eligibility_DATA.csv")
S <- rbindlist(lapply(res, `[[`, "spans"), fill = TRUE)
lg("total spans:", nrow(S))

## ---- fitting ----
fit_pt <- function(d) {                         # returns 5 class coefficients
  X <- cbind(sapply(CLS, function(cl) as.numeric(d$cls == cl)), lh = log(d$HT0))
  if (any(colSums(X[, 1:5, drop = FALSE]) == 0)) return(rep(NA_real_, 5))
  f <- lm.wfit(X, d$y, d$T); unname(f$coefficients[1:5])
}
contr <- function(cf) c(floor_band_minus_below = cf[3] - cf[2], band_minus_0535_070 = cf[3] - cf[4], band_minus_070_130 = cf[3] - cf[5])
prep <- function(sp, sdm, resp) {
  d <- copy(sp); d[, RD := SDI0 / sdm]; d <- d[RD >= 0.20 & RD <= 1.30]
  d[, cls := as.character(cut(RD, BRK, labels = CLS, right = FALSE, include.lowest = TRUE))]
  d[, y := get(resp)]; d[]
}
power_mde <- function(se) {
  set.seed(SEED); z <- rnorm(20000)
  for (m in seq(0, 6, by = 0.01)) if (mean(m * se + se * z - 1.96 * se > 0) >= 0.80) return(m * se)
  NA_real_
}

OUT <- list(); CM <- list(); SH <- list()
for (k in unique(S$dataset)) {
  spk <- S[dataset == k]
  plots <- sort(unique(spk$PlotID))
  set.seed(SEED)
  draws <- replicate(B, sample.int(length(plots), replace = TRUE))
  for (sdm in SDIMAX) for (resp in c("surv", "net")) {
    d <- prep(spk, sdm, resp)
    cf <- fit_pt(d); est <- contr(cf)
    rows_by <- split(seq_len(nrow(d)), factor(d$PlotID, levels = plots))
    bt <- do.call(rbind, parallel::mclapply(seq_len(ncol(draws)), function(j) { ix <- draws[, j]; r <- unlist(rows_by[ix], use.names = FALSE); dd <- d[r]; c(fit_pt(dd)) }, mc.cores = 8L))   # execution change only (see RUN.md): same draws, same refits, parallel over draws
    bc <- t(apply(bt, 1, contr)); ok <- complete.cases(bc)
    lhm <- mean(log(d$HT0))
    adj <- cf + coef(lm.wfit(cbind(sapply(CLS, function(cl) as.numeric(d$cls == cl)), lh = log(d$HT0)), d$y, d$T))[6] * lhm
    band_mean <- d[cls == CLS[3], weighted.mean(y, T)]
    margin <- 0.10 * abs(band_mean)
    npc <- sapply(CLS, function(cl) uniqueN(d[cls == cl, PlotID]))
    nsc <- sapply(CLS, function(cl) sum(d$cls == cl))
    for (ci in seq_along(est)) {
      b <- bc[ok, ci]; nm <- names(est)[ci]
      if (is.na(est[ci]) || length(b) < 100) { q <- rep(NA_real_, 4); se <- NA_real_; v <- "not estimable (empty class)" } else {
      q <- quantile(b, c(0.025, 0.975, 0.05, 0.95), names = FALSE); se <- sd(b)
      if (ci == 1) v <- if (est[ci] > 0 && q[1] > 0) "floor supported" else if (q[2] < 0) "floor contradicted" else "not distinguishable"
      else v <- if (q[3] > -margin && q[4] < margin) "no ceiling supported" else if (q[1] > 0) "ceiling indicated" else if (q[2] < 0) "denser class higher" else "not distinguishable" }
      OUT[[length(OUT) + 1]] <- data.table(dataset = k, sdimax = sdm, response = ifelse(resp == "surv", "survivor_BA_growth", "net_BA_change"),
        contrast = nm, est = est[ci], lo = q[1], hi = q[2], tost90_lo = q[3], tost90_hi = q[4], margin = margin, verdict = v,
        boot_se = se, mde80 = if (is.na(se)) NA_real_ else power_mde(se), n_boot_ok = sum(ok),
        n_plots_c020_0335 = npc[1], n_plots_c0335_0435 = npc[2], n_plots_c0435_0535 = npc[3], n_plots_c0535_070 = npc[4], n_plots_c070_130 = npc[5],
        n_spans = nrow(d), n_plots = uniqueN(d$PlotID))
    }
    bq <- apply(bt, 2, function(x) if (sum(!is.na(x)) >= 100) quantile(x, c(0.025, 0.975), na.rm = TRUE) else c(NA_real_, NA_real_))
    CM[[length(CM) + 1]] <- data.table(dataset = k, sdimax = sdm, response = ifelse(resp == "surv", "survivor_BA_growth", "net_BA_change"),
      rd_class = CLS, n_spans = nsc, n_plots = npc,
      wmean_raw = sapply(CLS, function(cl) d[cls == cl, if (.N) weighted.mean(y, T) else NA_real_]),
      mean_RD = sapply(CLS, function(cl) d[cls == cl, if (.N) mean(RD) else NA_real_]),
      mean_topht_m = sapply(CLS, function(cl) d[cls == cl, if (.N) mean(HT0) else NA_real_]),
      coef_class = cf, adj_mean_at_mean_logHT = adj, coef_lo = bq[1, ], coef_hi = bq[2, ], mean_logHT = lhm)
    if (sdm == 1132) {
      set.seed(SEED); ds <- d[sample(nrow(d))]
      cf2 <- fit_pt(ds); e2 <- contr(cf2)
      SH[[length(SH) + 1]] <- data.table(dataset = k, response = resp, identical = identical(unname(est), unname(e2)),
        all_equal_1e10 = isTRUE(all.equal(unname(est), unname(e2), tolerance = 1e-10)), max_abs_diff = max(abs(est - e2)))
    }
    lg(k, sdm, resp, "done; ok boots", sum(ok))
  }
}
R <- rbindlist(OUT); fwrite(R, "ctrn3_results_DATA.csv")
fwrite(rbindlist(CM), "ctrn3_class_means_DATA.csv")
fwrite(rbindlist(SH), "ctrn3_shuffle_DATA.csv")
saveRDS(list(wall_secs = as.numeric(difftime(Sys.time(), t_start, units = "secs")), r = R.version.string,
  pk = sapply(c("DBI", "RSQLite", "data.table"), function(p) as.character(packageVersion(p)))), "_plotlevel/runinfo.rds")
lg("ALL DONE wall secs", round(as.numeric(difftime(Sys.time(), t_start, units = "secs"))))
