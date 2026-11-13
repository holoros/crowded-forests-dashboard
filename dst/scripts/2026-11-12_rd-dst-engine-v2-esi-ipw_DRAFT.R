## 2026-11-12_rd-dst-engine-v2-esi-ipw_DRAFT.R: two more confounding checks on the engine v2 direct net carbon curve (reference height, B = 100):
## (1) site productivity: ESI v6r North America 1 km (na30 release A_esi) extracted at PUBLIC FIA plot coordinates (fuzzed up to about 1 km, matched to the
##     1 km raster; true coordinates for CONUS are not on firebreather). Checks: + s(ESI) at the regional median ESI, and within ESI terciles.
## (2) harvest selection: inverse probability of remaining unharvested (prep_r15_20261019.R, te_pairs_ipw.rds; mean 1, range 0.84 to 1.50) multiplied
##     into the interval-length weights. Uses the v2 definitions and chk() unchanged; the covariate check reuses chk(smax = TRUE) with lsm set to ESI.
suppressPackageStartupMessages({library(terra)})
src <- readLines("2026-11-12_rd-dst-engine-v2_DRAFT.R"); i0 <- grep("^ALL <- list", src); i1 <- grep("^chk <- function", src)
eval(parse(text = src[1:(i0 - 1)])); eval(parse(text = src[i1:(i1 + 7)])); t0 <- Sys.time()
X <- fread("/home/aaron/jobs/rd_maine10m_20261106/rdrelay_plot_public_xy.csv.gz")[, LOC := paste(STATECD, UNITCD, COUNTYCD, PLOT, sep = "_")]
X <- X[, .(LAT = median(LAT), LON = median(LON)), by = LOC][LOC %in% D$LOC]; cat("plots with public coordinates", nrow(X), "of", uniqueN(D$LOC), "\n")
r <- rast("/home/aaron/jobs/na30/release_v1/A_esi/data/ESI_v6r_NA_1km.tif"); cat("ESI layers", nlyr(r), names(r)[1], "\n")
p <- project(vect(X, geom = c("LON", "LAT"), crs = "EPSG:4269"), crs(r)); X[, esi := extract(r[[1]], p)[, 2]]; rm(p)
cat("ESI missing share", round(mean(is.na(X$esi)), 4), " ESI quantiles", round(quantile(X$esi, c(.05, .5, .95), na.rm = TRUE), 2), "\n")
D <- merge(D, X[, .(LOC, esi)], by = "LOC", all.x = TRUE); W <- readRDS("dst_ipw_DATA.rds"); D <- merge(D, as.data.table(W), by = "pid", all.x = TRUE); stopifnot(nrow(D) == 276984)
fwrite(D[, .(r_esi = cor(RD, esi, use = "complete.obs"), r_esi_lsm = cor(esi, lsm, use = "complete.obs"), esi_med = median(esi, na.rm = TRUE)), by = region], file.path(OD, "dst_engine2_esi_summary_DATA.csv"))
CK <- list()
for (R in names(LEV)) { d <- D[region == R & is.finite(esi)]
  e <- copy(d)[, lsm := esi]; CK[[length(CK) + 1]] <- chk(e, R, smax = TRUE, lab = "plus s(ESI), at regional median ESI")
  tq <- quantile(d$esi, c(1/3, 2/3)); d[, terc := cut(esi, c(-Inf, tq, Inf), labels = c("low ESI", "mid ESI", "high ESI"))]
  for (tt in levels(d$terc)) CK[[length(CK) + 1]] <- chk(d[terc == tt], R, lab = paste("ESI tercile:", tt))
  w <- copy(D[region == R & is.finite(ipw)])[, T := T * ipw]; CK[[length(CK) + 1]] <- chk(w, R, lab = "harvest attrition weights (IPW)")
  cat(R, "done", format(Sys.time() - t0), "\n") }
CKs <- rbindlist(CK); fwrite(CKs, file.path(OD, "dst_engine2_esi_ipw_DATA.csv"))
print(dcast(CKs[stat %in% c("rd_max", "ceil_contrast", "floor_contrast")], region + check ~ stat, value.var = "est"), digits = 3); cat("done\n")
