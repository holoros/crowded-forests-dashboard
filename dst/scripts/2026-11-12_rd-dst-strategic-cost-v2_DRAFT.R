## 2026-11-12_rd-dst-strategic-cost-v2_DRAFT.R: strategic cost after the red team. Changes from v1: direct net growth curves (engine v2, Nd), top height grid
## 4 to 30 m, ceiling only where the engine v2 replicate-wise test indicates one at the plot's nearest tested top height (ceilings-by-height table), cost carried through
## all bootstrap replicate curves so intervals include curve uncertainty plus plot sampling, hexagons flagged and cost suppressed when under 70% of plots are
## costed. Population: unharvested FIA plots at their latest visit (unweighted plot shares). Aggregates only; no plot rows or coordinates written.
suppressPackageStartupMessages({library(sf); library(data.table)}); sf_use_s2(FALSE); set.seed(20261112)
setwd("/fs/scratch/PUOM0008/crsfaaron/rdgrowth_conus_20260930/typeeco"); source("fig_common.R"); OD <- "../dst_20261112"
CT <- fread("../dst_20261112/2026-11-12_rd-dst-ceilings-by-height_DATA.csv")   # per region and top height: ceiling where the engine v2 replicate test indicates one, else NA
P <- readRDS("out/te_pairs_ht.rds"); stopifnot(nrow(P) == 276984)
setorder(P, LOC, -tj); L <- P[, .SD[1], by = LOC][, .(LOC, RDl = RD_j, H = HT0)]; stopifnot(nrow(L) == 85821)
FIA <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20260930"; sts <- readLines("../states.txt")
X <- rbindlist(lapply(sts, function(ST) { p <- fread(sprintf("%s/%s_PLOT.csv", FIA, ST), select = c("STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "MEASYEAR", "LAT", "LON"))
  p <- p[!is.na(LAT) & !is.na(LON) & INVYR < 9999]; p[, LOC := paste(STATECD, UNITCD, COUNTYCD, PLOT, sep = "_")]; setorder(p, LOC, -MEASYEAR); p[, .SD[1], by = LOC][, .(LOC, LAT, LON, STATECD)] }))
L <- merge(L, X, by = "LOC"); O <- "/fs/scratch/PUOM0008/crsfaaron/treemap2022"
st <- st_transform(st_read(file.path(O, "states/cb_2022_us_state_20m.shp"), quiet = TRUE), 5070); st <- st[!st$STUSPS %in% c("AK", "HI", "PR"), ]; us <- st_union(st)
hx0 <- st_sf(geometry = st_make_grid(us, cellsize = 60000, square = FALSE)); hx0 <- hx0[st_intersects(hx0, us, sparse = FALSE)[, 1], ]; hx0$hex <- seq_len(nrow(hx0))
pts <- st_transform(st_as_sf(L, coords = c("LON", "LAT"), crs = 4269), 5070); j <- st_intersects(pts, hx0)
L[, hex := vapply(j, function(z) if (length(z)) hx0$hex[z[1]] else NA_integer_, 1L)]; L[, c("LAT", "LON") := NULL]; rm(pts, X)
EC <- unique(as.data.table(readRDS("out/plot_eco.rds"))[, .(LOC, L3 = as.integer(L3), L3NAME, L2NAME)], by = "LOC"); L <- merge(L, EC, by = "LOC", all.x = TRUE); L[, region := er[L2NAME]]
L <- L[!is.na(region)]; LEV <- c(North = 0.485, Central = 0.400, Southeast = 0.385, West = 0.405)
L[, floor := LEV[region] - 0.05]; L[, ceil := Inf]
for (R in names(LEV)) { ct <- CT[region == R]; k <- which(L$region == R); hs <- ct$HT
  nh <- vapply(L$H[k], function(h) if (is.finite(h)) hs[which.min(abs(log(hs) - log(h)))] else NA_real_, 1); cc <- ct$ceiling[match(nh, hs)]; set(L, k, "ceil", fifelse(is.na(cc), Inf, cc)) }
cat("share of plots with a ceiling by region:\n"); print(L[, .(with_ceiling = round(mean(is.finite(ceil)), 3)), by = region])
CV <- fread(file.path(OD, "dst_engine2_curves_DATA.csv")); REP <- readRDS(file.path(OD, "dst_engine2_replicates_DATA.rds"))
## interpolation on a curve given as a vector over grid (HT x RD); NA outside support
interp_vec <- function(grid, v, rd, h) { Hs <- sort(unique(grid$HT))
  A <- sapply(Hs, function(hh) { k <- which(grid$HT == hh & !is.na(v)); if (length(k) < 2) rep(NA_real_, length(rd)) else approx(grid$RD[k], v[k], rd, rule = 1)$y })
  i0 <- findInterval(h, Hs, all.inside = TRUE); w <- (h - Hs[i0]) / (Hs[i0 + 1] - Hs[i0]); ok <- is.finite(h) & h >= min(Hs) & h <= max(Hs)
  r <- seq_along(rd); out <- (1 - w) * A[cbind(r, i0)] + w * A[cbind(r, i0 + 1)]; out[!ok] <- NA_real_; out }
cost_vec <- function(grid, v, d) { lo <- d$floor[1]; hi <- LEV[[d$region[1]]] + 0.05
  nb <- rowMeans(sapply(seq(lo, hi, by = 0.01), function(x) interp_vec(grid, v, rep(x, nrow(d)), d$H)))
  nx <- interp_vec(grid, v, d$RDl, d$H); out <- d$RDl < d$floor | d$RDl > d$ceil; fifelse(out, pmax(0, nb - nx), 0) }
L[, `:=`(out_below = RDl < floor, out_above = RDl > ceil)]
for (R in names(LEV)) { k <- which(L$region == R); d <- L[k]; g <- CV[region == R]
  gr <- REP[[R]]$grid; stopifnot(nrow(gr) == sum(CV$region == R))
  for (u in c("c", "v")) { set(L, k, paste0("cost_", u), cost_vec(g, g[[paste0("Nd", u)]], d))
    M <- REP[[R]][[paste0("Nd", u)]]; CB <- sapply(seq_len(nrow(M)), function(b) cost_vec(gr, M[b, ], d))   # plots x replicates
    saveRDS(CB, sprintf("%s/_tmp_costrep_%s_%s.rds", OD, R, u)) } }
L[, supported := is.finite(cost_c) & is.finite(cost_v)]
cat("plots", nrow(L), " supported", sum(L$supported), " share unsupported by region:\n"); print(L[, .(unsupported = round(mean(!supported), 3)), by = region])
## attach replicate costs back (rows of L within region, in order)
RC <- list(); for (R in names(LEV)) for (u in c("c", "v")) RC[[paste(R, u)]] <- readRDS(sprintf("%s/_tmp_costrep_%s_%s.rds", OD, R, u))
agg <- function(by) { out <- list(); for (R in names(LEV)) { k <- which(L$region == R); d <- L[k]
    for (u in c("c", "v")) { CB <- RC[[paste(R, u)]]; d[, (paste0("rep_", u, "_", seq_len(ncol(CB)))) := lapply(seq_len(ncol(CB)), function(b) CB[, b])] } ; out[[R]] <- d }
  D <- rbindlist(out, fill = TRUE); rc <- grep("^rep_c", names(D), value = TRUE)
  res <- D[, { s <- supported; m_c <- if (any(s)) mean(cost_c[s]) else NA_real_; m_v <- if (any(s)) mean(cost_v[s]) else NA_real_
      repm <- if (any(s)) vapply(.SD, function(z) mean(z[s], na.rm = TRUE), 1) else NA_real_
      se_s <- if (sum(s) > 1) sd(cost_c[s]) / sqrt(sum(s)) else NA_real_
      ci <- quantile(repm, c(0.025, 0.975), na.rm = TRUE); sd_tot <- sqrt(var(repm, na.rm = TRUE) + se_s^2)
      list(n = .N, n_supported = sum(s), share_costed = mean(s), share_below_floor = mean(out_below), share_above_ceiling = mean(out_above), share_ok = mean(!out_below & !out_above),
           cost_c = m_c, cost_c_lo = m_c - 1.96 * sd_tot, cost_c_hi = m_c + 1.96 * sd_tot, cost_c_curve_lo = ci[[1]], cost_c_curve_hi = ci[[2]], cost_c_sampling_se = se_s, cost_v = m_v) }, by = by, .SDcols = rc]
  res[share_costed < 0.70, `:=`(cost_c = NA_real_, cost_c_lo = NA_real_, cost_c_hi = NA_real_, cost_v = NA_real_)]; res[, cost_suppressed := share_costed < 0.70]; res }
L[, all := "Conterminous US"]
HX <- agg("hex")[n >= 20]; setorder(HX, hex); STt <- agg("STATECD"); setorder(STt, STATECD); E3 <- agg(c("L3", "L3NAME", "region"))[n >= 20]; setorder(E3, L3); RG <- agg("region"); NA1 <- agg("all")
for (z in list(list(HX, "hex"), list(STt, "state"), list(E3, "ecoregion"), list(RG, "region"), list(NA1, "national"))) fwrite(z[[1]], sprintf("%s/dst_strategic2_cost_%s_DATA.csv", OD, z[[2]]))
unlink(Sys.glob(file.path(OD, "_tmp_costrep_*.rds")))
SH <- L[sample(.N)][, .(cost_c = mean(cost_c[supported]), share_ok = mean(!out_below & !out_above)), keyby = region]; P0 <- L[, .(cost_c = mean(cost_c[supported]), share_ok = mean(!out_below & !out_above)), keyby = region]
cat("F14 shuffle identical:", isTRUE(all.equal(SH, P0)), "\n")
print(RG, digits = 3); print(NA1, digits = 3); cat("hexes", nrow(HX), " suppressed", sum(HX$cost_suppressed), "\ndone\n")
