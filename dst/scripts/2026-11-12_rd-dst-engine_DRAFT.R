## 2026-11-12_rd-dst-engine_DRAFT.R: engine table for the relative density (RD) decision support tool.
## Input: dst_engine_input_DATA.rds (276,984 remeasured intervals on 85,821 unharvested FIA plots; no coordinates), built on Cardinal from typeeco/out.
## One crowding definition: RD at the start of the interval (what a manager measures before acting). Interval mean RD (m14 dashboard axis) kept only as a sensitivity.
## Stand development is held fixed by conditioning on top height (HT0, m): across plots, high RD goes with short, low biomass stands, so a curve on RD alone
## mixes stand age with crowding. Each response is a tensor smooth te(RD, log HT0) fitted by region (bam, fREML), intervals weighted by length.
## Responses (annual, per ha, carbon Mg C ha-1 yr-1 and merchantable volume m3 ha-1 yr-1, VOLCFNET trees >= 5 in):
##   G   gross growth (all intervals)
##   Mb  mortality on intervals with no recorded natural disturbance  -> density related (background) mortality
##   Md  mortality on intervals with recorded natural disturbance
##   p   probability of a recorded natural disturbance, cloglog binomial with log(T) offset; reported as annual hazard and as 10 yr probability
## Decomposition (no double counting): expected mortality = Mb + p10 * (Md - Mb); disturbance cost = p10 * (Md - Mb); net = G - Mb - disturbance cost.
## Uncertainty: whole plot bootstrap within region, B = 200, 95% percentile intervals. Order check: every point estimate refit on a row shuffled table.
## Support rule: a grid cell is reported only where at least 30 intervals fall within +/-0.025 RD and +/-10% top height; otherwise NA (no extrapolation).
suppressPackageStartupMessages({library(data.table); library(mgcv); library(parallel)})
set.seed(20261112); NC <- 8L; B <- as.integer(Sys.getenv("NBOOT", "200")); OD <- "output"; dir.create(OD, showWarnings = FALSE)
D <- readRDS("dst_engine_input_DATA.rds"); stopifnot(nrow(D) == 276984)
D <- D[is.finite(HT0) & HT0 > 0 & is.finite(RD) & T > 0]
D[, `:=`(lh = log(HT0), gc = Gc_tot / T, mc = Mc_tot / T, gv = Gv_tot / T, mv = Mv_tot / T, nc = Nc_tot / T, nv = Nv_tot / T, dist = as.integer(natdist))]
cat("intervals with top height", nrow(D), " plots", uniqueN(D$LOC), "\n")
BAND <- c(North = 0.485, Central = 0.400, Southeast = 0.385, West = 0.405)   # regional leveling points, m14_optimal_rd_region_DATA.csv (interval mean axis)
RDG <- seq(0.10, 0.80, by = 0.01); HTG <- c(10, 15, 20, 25, 30)
fitg <- function(f, d, fam = gaussian()) { d <- copy(d); d[, wt := if (identical(fam$family, "gaussian")) T else 1]
  tryCatch(bam(f, data = d, weights = wt, family = fam, discrete = TRUE, method = "fREML", nthreads = 1), error = function(e) { message("fit failed: ", conditionMessage(e)); NULL }) }
## fit one region: returns predictions on the grid (vector, named) or NULL
fit_unit <- function(d, grid) {
  fG <- list(c = fitg(gc ~ te(RD, lh, k = c(8, 5)), d), v = fitg(gv ~ te(RD, lh, k = c(8, 5)), d))
  fB <- list(c = fitg(mc ~ te(RD, lh, k = c(8, 5)), d[dist == 0]), v = fitg(mv ~ te(RD, lh, k = c(8, 5)), d[dist == 0]))
  fD <- list(c = fitg(mc ~ te(RD, lh, k = c(6, 4)), d[dist == 1]), v = fitg(mv ~ te(RD, lh, k = c(6, 4)), d[dist == 1]))
  fP <- fitg(dist ~ te(RD, lh, k = c(6, 4)) + offset(log(T)), d, binomial(link = "cloglog"))
  if (any(vapply(c(fG, fB, fD, list(fP)), is.null, TRUE))) return(NULL)
  nd <- data.frame(RD = grid$RD, lh = log(grid$HT), T = 1)
  eta <- as.numeric(predict(fP, nd, type = "link"))                        # log annual cumulative hazard at T = 1
  h1 <- 1 - exp(-exp(eta)); p10 <- 1 - exp(-exp(eta) * 10)
  out <- list(h1 = h1, p10 = p10)
  for (u in c("c", "v")) { G <- as.numeric(predict(fG[[u]], nd)); Mb <- as.numeric(predict(fB[[u]], nd)); Md <- as.numeric(predict(fD[[u]], nd))
    Dc <- p10 * (Md - Mb); out[[paste0("G", u)]] <- G; out[[paste0("Mb", u)]] <- Mb; out[[paste0("Md", u)]] <- Md; out[[paste0("Dc", u)]] <- Dc; out[[paste0("N", u)]] <- G - Mb - Dc }
  out }
## summaries at one height: first local net maximum in 0.25 to 0.70, 90% of max gross, band performance and cost of being outside
summ <- function(pr, grid, band_c, H) {
  r <- list(); for (u in c("c", "v")) {
    k <- which(grid$HT == H & !is.na(pr[[paste0("N", u)]])); x <- grid$RD[k]; n <- pr[[paste0("N", u)]][k]; g <- pr[[paste0("G", u)]][k]
    dn <- diff(n); idx <- which(dn[-length(dn)] > 0 & dn[-1] <= 0) + 1L; idx <- idx[x[idx] >= 0.25 & x[idx] <= 0.70]
    r[[paste0("rd_netmax_", u)]] <- if (length(idx)) x[idx[1]] else NA_real_
    r[[paste0("rd_g90_", u)]] <- x[which(g >= 0.9 * max(g))[1]]
    inb <- abs(x - band_c) <= 0.05 + 1e-9; at <- function(z) if (z < min(x) || z > max(x)) NA_real_ else approx(x, n, z)$y
    nb <- mean(n[inb]); r[[paste0("net_band_", u)]] <- nb; r[[paste0("net_band_pct_max_", u)]] <- nb / max(n); r[[paste0("rd_netmax_global_", u)]] <- x[which.max(n)]
    for (dd in c(0.10, 0.20)) { r[[sprintf("cost_below%02d_%s", 100 * dd, u)]] <- nb - at(band_c - dd); r[[sprintf("cost_above%02d_%s", 100 * dd, u)]] <- nb - at(band_c + dd) } }
  k <- which(grid$HT == H & !is.na(pr$h1)); x <- grid$RD[k]; h <- pr$h1[k]; inb <- abs(x - band_c) <= 0.05 + 1e-9
  r$h1_band <- mean(h[inb]); r$h1_above20 <- if (band_c + 0.2 > max(x)) NA_real_ else approx(x, h, band_c + 0.2)$y; r$h1_below20 <- if (band_c - 0.2 < min(x)) NA_real_ else approx(x, h, band_c - 0.2)$y
  unlist(r) }
## support mask on the grid
support <- function(d, grid) vapply(seq_len(nrow(grid)), function(i) d[abs(RD - grid$RD[i]) <= 0.025 & abs(lh - log(grid$HT[i])) <= 0.0953, .N], 1L)

ALL <- list(); SUM <- list(); t0 <- Sys.time()
for (R in names(BAND)) {
  d <- D[region == R]; Hm <- round(median(d$HT0)); grid <- CJ(HT = sort(unique(c(HTG, Hm))), RD = RDG); sup <- support(d, grid)
  pe <- fit_unit(d, grid); stopifnot(!is.null(pe)); for (nm in names(pe)) pe[[nm]][sup < 30] <- NA
  ## order check on the point estimate
  ps <- fit_unit(d[sample(.N)], grid); for (nm in names(ps)) ps[[nm]][sup < 30] <- NA
  shuf_ok <- isTRUE(all.equal(pe, ps, tolerance = 1e-6))
  cl <- split(seq_len(nrow(d)), d$LOC); nm <- names(cl)
  bs <- mclapply(seq_len(B), function(b) { set.seed(20261112 + b); ii <- unlist(cl[sample(nm, length(nm), replace = TRUE)], use.names = FALSE)
    f <- fit_unit(d[ii], grid); if (is.null(f)) return(NULL); for (z in names(f)) f[[z]][sup < 30] <- NA
    list(curves = f, s = summ(f, grid, BAND[[R]], Hm)) }, mc.cores = NC)
  bs <- bs[!vapply(bs, is.null, TRUE)]; nb <- length(bs)
  q <- function(z, p) apply(do.call(rbind, lapply(bs, function(b) b$curves[[z]])), 2, quantile, p, na.rm = TRUE)
  cv <- data.table(region = R, grid, support_n = sup)
  for (z in names(pe)) { cv[, (z) := pe[[z]]]; cv[, (paste0(z, "_lo")) := q(z, 0.025)]; cv[, (paste0(z, "_hi")) := q(z, 0.975)] }
  ALL[[R]] <- cv
  s0 <- summ(pe, grid, BAND[[R]], Hm); s1 <- summ(ps, grid, BAND[[R]], Hm); SB <- do.call(rbind, lapply(bs, `[[`, "s"))
  SUM[[R]] <- data.table(region = R, ref_height_m = Hm, band_center = BAND[[R]], intervals = nrow(d), plots = length(cl), boot = nb, shuffle_identical = shuf_ok && isTRUE(all.equal(s0, s1, tolerance = 1e-6)),
    stat = names(s0), est = as.numeric(s0), lo = apply(SB, 2, quantile, 0.025, na.rm = TRUE), hi = apply(SB, 2, quantile, 0.975, na.rm = TRUE), defined_share = colMeans(!is.na(SB)))
  cat(R, "done", format(Sys.time() - t0), " boot", nb, " shuffle", shuf_ok, "\n"); print(SUM[[R]][, .(stat, est, lo, hi, defined_share)], digits = 3) }
CV <- rbindlist(ALL); SM <- rbindlist(SUM)
fwrite(CV, file.path(OD, "dst_engine_curves_DATA.csv")); fwrite(SM, file.path(OD, "dst_engine_summary_DATA.csv"))

## identity check: G - Mb - Dc against a direct fit of net growth, at the reference height (carbon)
IDC <- rbindlist(lapply(names(BAND), function(R) { d <- D[region == R]; Hm <- SM[region == R, ref_height_m][1]; f <- fitg(nc ~ te(RD, lh, k = c(8, 5)), d)
  cv <- CV[region == R & HT == Hm & !is.na(Nc)]; dn <- as.numeric(predict(f, data.frame(RD = cv$RD, lh = log(Hm))))
  data.table(region = R, max_abs_diff = max(abs(cv$Nc - dn)), mean_net = mean(dn)) })); print(IDC, digits = 3); fwrite(IDC, file.path(OD, "dst_engine_identity_check_DATA.csv"))

## sensitivity: crowding axis. Net carbon maximum on start RD (marginal over height) vs interval mean RD (the dashboard axis)
SEN <- rbindlist(lapply(names(BAND), function(R) { d <- D[region == R]; x <- seq(0.20, 0.80, by = 0.005)
  a <- function(v) { f <- fitg(as.formula(paste("nc ~ s(", v, ", bs = 'cr', k = 10)")), d); n <- as.numeric(predict(f, setNames(data.frame(x), v))); dn <- diff(n)
    i <- which(dn[-length(dn)] > 0 & dn[-1] <= 0) + 1L; i <- i[x[i] >= 0.25 & x[i] <= 0.70]; if (length(i)) x[i[1]] else NA_real_ }
  data.table(region = R, netmax_start_rd_marginal = a("RD"), netmax_interval_mean_rd_marginal = a("mX"), m14_leveling_point = BAND[[R]]) })); print(SEN); fwrite(SEN, file.path(OD, "dst_engine_axis_sensitivity_DATA.csv"))

## attenuation: observed on predicted slope for gross carbon growth, 5 fold CV blocked by plot
ATT <- rbindlist(lapply(names(BAND), function(R) { d <- copy(D[region == R]); lk <- unique(d$LOC); fo <- setNames(sample(rep(1:5, length.out = length(lk))), lk); d[, fold := fo[LOC]]; d[, pr := NA_real_]
  for (k in 1:5) { f <- fitg(gc ~ te(RD, lh, k = c(8, 5)), d[fold != k]); d[fold == k, pr := as.numeric(predict(f, d[fold == k]))] }
  cf <- coef(lm(gc ~ pr, d, weights = T)); data.table(region = R, obs_on_pred_slope = cf[2], intercept = cf[1], cv_r2 = cor(d$gc, d$pr)^2) })); print(ATT, digits = 3); fwrite(ATT, file.path(OD, "dst_engine_attenuation_DATA.csv"))
cat("total time", format(Sys.time() - t0), "\ndone\n")
