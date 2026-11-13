## 2026-11-12_rd-dst-natdist-audit_DRAFT.R: rebuild the interval disturbance flag by agent. Old flag = any DSTRBCD > 0 at a visit (combos_build.R),
## which includes 60 (vegetation: suppression, competition) and 70 (unknown). New flags from COND at visits inside (i, j]: nat = codes 10 to 54
## (insects, disease, fire, animal, weather); veg = 60; unk = 70; geo = 90 to 95. Output: pid-level flags (no coordinates) for the engine rerun.
suppressPackageStartupMessages(library(data.table)); setwd("/fs/scratch/PUOM0008/crsfaaron/rdgrowth_conus_20260930/typeeco")
P <- readRDS("out/te_pairs_ht.rds")[, .(pid, LOC, ti, tj, natdist, consecutive)]
FIA <- "/fs/scratch/PUOM0008/crsfaaron/fia_datamart_20260930"; sts <- readLines("../states.txt")
V <- rbindlist(lapply(sts, function(ST) { p <- fread(sprintf("%s/%s_PLOT.csv", FIA, ST), select = c("CN", "STATECD", "UNITCD", "COUNTYCD", "PLOT", "INVYR", "MEASYEAR", "MEASMON"), colClasses = list(character = "CN"))
  c <- fread(sprintf("%s/%s_COND.csv", FIA, ST), select = c("PLT_CN", "DSTRBCD1", "DSTRBCD2", "DSTRBCD3"), colClasses = list(character = "PLT_CN"))
  cc <- melt(c, id.vars = "PLT_CN", value.name = "d")[!is.na(d) & d > 0, .(nat = any(d >= 10 & d <= 54), veg = any(d == 60), unk = any(d == 70), geo = any(d >= 90), any0 = TRUE), by = PLT_CN]
  p <- merge(p[INVYR < 9999], cc, by.x = "CN", by.y = "PLT_CN", all.x = TRUE); for (z in c("nat", "veg", "unk", "geo", "any0")) set(p, which(is.na(p[[z]])), z, FALSE)
  p[, LOC := paste(STATECD, UNITCD, COUNTYCD, PLOT, sep = "_")][, .(LOC, MEASYEAR, MEASMON, nat, veg, unk, geo, any0)] }))
V <- V[, lapply(.SD, any), by = .(LOC, MEASYEAR), .SDcols = c("nat", "veg", "unk", "geo", "any0")]
J <- merge(P[, .(pid, LOC, ti, tj, natdist)], V, by = "LOC", allow.cartesian = TRUE)[MEASYEAR > floor(ti) & MEASYEAR <= floor(tj)]
F <- J[, .(nat = any(nat), veg = any(veg), unk = any(unk), geo = any(geo), any0 = any(any0), nvis = .N), by = .(pid, natdist)]
F <- merge(P[, .(pid, natdist)], F[, !"natdist"], by = "pid", all.x = TRUE)
cat("pairs", nrow(P), " matched", sum(!is.na(F$nvis)), "\n"); print(F[!is.na(nvis), .N, by = .(old = natdist, rebuilt_any = any0)])
print(F[!is.na(nvis), .(share_old = mean(natdist), nat = mean(nat), veg = mean(veg), unk = mean(unk), geo = mean(geo), veg_only = mean(veg & !nat & !geo), unk_only = mean(unk & !nat & !veg & !geo))])
saveRDS(F[, .(pid, natdist_old = natdist, dist_nat = nat, dist_veg = veg, dist_unk = unk, dist_geo = geo, matched = !is.na(nvis))], "../dst_20261112/dst_natdist_flags_DATA.rds"); cat("done\n")
