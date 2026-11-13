## 2026-11-12_rd-dst-strategic-cost_DRAFT.R: expected cost of sitting outside the band, for the strategic view of the RD decision support tool.
## Band rule (Aaron, 12 November 2026): floor = regional leveling point - 0.05 everywhere; ceiling only where the data show a cost (West: leveling point + 0.05);
## elsewhere no ceiling is credited. Cost per plot = net growth averaged over the band at the plot's own top height minus net growth at the plot's latest RD,
## counted only below the floor (and above the ceiling in the West), floored at zero. Curves: engine (dst_engine_curves_DATA.csv, firebreather), interpolated
## bilinearly in RD and top height. Plots outside curve support are counted and excluded from the cost mean. Output: aggregates only (hex n >= 20, state,
## ecoregion, region, national). No plot rows or coordinates written.
suppressPackageStartupMessages({library(sf); library(data.table)}); sf_use_s2(FALSE); set.seed(20261112)
setwd("/fs/scratch/PUOM0008/crsfaaron/rdgrowth_conus_20260930/typeeco"); source("fig_common.R"); OD <- "../dst_20261112"
P <- readRDS("out/te_pairs_ht.rds"); stopifnot(nrow(P) == 276984)
setorder(P, LOC, -tj); L <- P[, .SD[1], by = LOC][, .(LOC, RDl = RD_j, H = HT0)]; stopifnot(nrow(L) == 85821)   # top height at the start of the latest interval
FIA <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20260930"; sts <- readLines("../states.txt")
X <- rbindlist(lapply(sts, function(ST) { p <- fread(sprintf("%s/%s_PLOT.csv", FIA, ST), select = c("STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "MEASYEAR", "LAT", "LON"))
  p <- p[!is.na(LAT) & !is.na(LON) & INVYR < 9999]; p[, LOC := paste(STATECD, UNITCD, COUNTYCD, PLOT, sep = "_")]; setorder(p, LOC, -MEASYEAR); p[, .SD[1], by = LOC][, .(LOC, LAT, LON, STATECD)] }))
L <- merge(L, X, by = "LOC")
O <- "/fs/scratch/PUOM0008/crsfaaron/treemap2022"
st <- st_transform(st_read(file.path(O, "states/cb_2022_us_state_20m.shp"), quiet = TRUE), 5070); st <- st[!st$STUSPS %in% c("AK", "HI", "PR"), ]; us <- st_union(st)
hx0 <- st_sf(geometry = st_make_grid(us, cellsize = 60000, square = FALSE)); hx0 <- hx0[st_intersects(hx0, us, sparse = FALSE)[, 1], ]; hx0$hex <- seq_len(nrow(hx0))
pts <- st_transform(st_as_sf(L, coords = c("LON", "LAT"), crs = 4269), 5070); j <- st_intersects(pts, hx0)
L[, hex := vapply(j, function(z) if (length(z)) hx0$hex[z[1]] else NA_integer_, 1L)]; L[, c("LAT", "LON") := NULL]; rm(pts, X)
EC <- unique(as.data.table(readRDS("out/plot_eco.rds"))[, .(LOC, L3 = as.integer(L3), L3NAME, L2NAME)], by = "LOC"); L <- merge(L, EC, by = "LOC", all.x = TRUE); L[, region := er[L2NAME]]
LEV <- c(North = 0.485, Central = 0.400, Southeast = 0.385, West = 0.405); L[, `:=`(floor = LEV[region] - 0.05, ceil = fifelse(region == "West", LEV[region] + 0.05, Inf), top = LEV[region] + 0.05)]
CV <- fread(file.path(OD, "dst_engine_curves_DATA.csv"))
## bilinear interpolation of a curve column at (rd, h) within a region; NA outside support
interp <- function(R, rd, h, col) { g <- CV[region == R]; Hs <- sort(unique(g$HT))
  A <- sapply(Hs, function(hh) { s <- g[HT == hh & !is.na(get(col))]; if (nrow(s) < 2) rep(NA_real_, length(rd)) else approx(s$RD, s[[col]], rd, rule = 1)$y })   # plots x heights
  i0 <- findInterval(h, Hs, all.inside = TRUE); w <- (h - Hs[i0]) / (Hs[i0 + 1] - Hs[i0]); ok <- is.finite(h) & h >= min(Hs) & h <= max(Hs)
  r <- seq_along(rd); out <- (1 - w) * A[cbind(r, i0)] + w * A[cbind(r, i0 + 1)]; out[!ok] <- NA_real_; out }
bandmean <- function(R, h, col, lo, hi) { xs <- seq(lo, hi, by = 0.01); rowMeans(sapply(xs, function(x) interp(R, rep(x, length(h)), h, col))) }
L <- L[!is.na(region)]
for (R in names(LEV)) { k <- L$region == R
  for (u in c("c", "v")) { col <- paste0("N", u)
    nx <- interp(R, L$RDl[k], L$H[k], col); nb <- bandmean(R, L$H[k], col, LEV[[R]] - 0.05, LEV[[R]] + 0.05)
    set(L, which(k), paste0("n_at_", u), nx); set(L, which(k), paste0("n_band_", u), nb) } }
L[, out_below := RDl < floor]; L[, out_above := RDl > ceil]
for (u in c("c", "v")) { L[, (paste0("cost_", u)) := fifelse(out_below | out_above, pmax(0, get(paste0("n_band_", u)) - get(paste0("n_at_", u))), 0)] }
L[, supported := is.finite(cost_c) & is.finite(cost_v)]
cat("plots", nrow(L), " supported", sum(L$supported), " share unsupported", round(mean(!L$supported), 3), " below floor", round(mean(L$out_below), 3), " above West ceiling", round(mean(L$out_above), 3), "\n")
ag <- function(d, by) d[, .(n = .N, n_supported = sum(supported), share_below_floor = mean(out_below), share_above_ceiling = mean(out_above),
  share_in_band_floor_rule = mean(!out_below & !out_above),
  cost_c = mean(cost_c[supported]), cost_c_se = sd(cost_c[supported]) / sqrt(sum(supported)), cost_v = mean(cost_v[supported]), cost_v_se = sd(cost_v[supported]) / sqrt(sum(supported)),
  cost_c_below_only = mean(fifelse(out_below, cost_c, 0)[supported])), by = by]
L[, all := "Conterminous US"]
HX <- ag(L[!is.na(hex)], "hex")[n >= 20]; setorder(HX, hex); ST <- ag(L, "STATECD"); setorder(ST, STATECD); E3 <- ag(L, c("L3", "L3NAME", "region"))[n >= 20]; setorder(E3, L3)
RG <- ag(L, "region"); NA1 <- ag(L, "all")
HXs <- ag(L[sample(.N)][!is.na(hex)], "hex")[n >= 20]; setorder(HXs, hex); cat("F14 shuffle identical:", isTRUE(all.equal(HX, HXs)), "\n")
fwrite(HX, file.path(OD, "dst_strategic_cost_hex_DATA.csv")); fwrite(ST, file.path(OD, "dst_strategic_cost_state_DATA.csv")); fwrite(E3, file.path(OD, "dst_strategic_cost_ecoregion_DATA.csv"))
fwrite(RG, file.path(OD, "dst_strategic_cost_region_DATA.csv")); fwrite(NA1, file.path(OD, "dst_strategic_cost_national_DATA.csv"))
print(RG, digits = 3); print(NA1, digits = 3); cat("done\n")
