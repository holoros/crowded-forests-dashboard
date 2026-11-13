## 2026-11-12_rd-dst-engine-v2_DRAFT.R: engine rerun after the 12 November red team. Changes from v1 (2026-11-12_rd-dst-engine_DRAFT.R):
##  1. Disturbance flag = natural agents only (DSTRBCD 10 to 54) from dst_natdist_flags_DATA.rds; vegetation/suppression (60) and unknown (70) now count as
##     density related mortality. The rebuilt any-code flag reproduced the old flag on all 276,984 intervals.
##  2. Net growth is fitted directly (Nd, primary) and the decomposition residual is bootstrapped. Mortality split uses Gaussian mean fits in the bootstrap
##     (cost: the server is shared); a Tweedie (tw) split at the point estimate is saved for comparison. Disturbance probability is taken at each region's median interval length, not a fixed 10 yr.
##  3. Grid widened: top height 4 to 30 m, RD 0.05 to 1.00 (support rule unchanged: >= 30 intervals within +/-0.025 RD and +/-10% height).
##  4. Ceiling and floor tests are replicate-wise: in each bootstrap the net maximum is re-located and N(max + 0.10) - N(max) is computed; floor contrast
##     N(floor) - N(floor - 0.10) at the PI's floor; data floor = lowest RD reaching 90% of the supported maximum. B = 200. Replicate curves saved for cost propagation.
##  5. Confounding checks (point estimate plus B = 100): + s(ln SDImax); within SDImax terciles; regression calibration of start RD on the previous visit's RD.
suppressPackageStartupMessages({library(data.table); library(mgcv); library(parallel)})
set.seed(20261112); NC <- as.integer(Sys.getenv("NCORES", "4")); B <- as.integer(Sys.getenv("NBOOT", "200")); BV <- as.integer(Sys.getenv("NBOOTV", "100")); OD <- "output_v2"; dir.create(OD, showWarnings = FALSE)
D <- readRDS("dst_engine_input_DATA.rds"); FL <- readRDS("dst_natdist_flags_DATA.rds"); stopifnot(nrow(D) == 276984, all(FL$matched))
D <- merge(D, FL[, .(pid, dist_nat)], by = "pid"); stopifnot(nrow(D) == 276984)
D <- D[is.finite(HT0) & HT0 > 0 & is.finite(RD) & T > 0 & is.finite(SDImax) & SDImax > 0]
D[, `:=`(lh = log(HT0), lsm = log(SDImax), gc = Gc_tot / T, mc = pmax(Mc_tot, 0) / T, gv = Gv_tot / T, mv = pmax(Mv_tot, 0) / T, nc = Nc_tot / T, nv = Nv_tot / T, dist = as.integer(dist_nat))]
cat("intervals", nrow(D), " plots", uniqueN(D$LOC), " natural disturbance share", round(mean(D$dist), 4), "\n")
LEV <- c(North = 0.485, Central = 0.400, Southeast = 0.385, West = 0.405); FLOOR <- LEV - 0.05
TMED <- D[, .(Tm = median(T)), by = region]; TM <- setNames(TMED$Tm, TMED$region); print(TM)
RDG <- round(seq(0.05, 1.00, by = 0.01), 2); HTG <- c(4, 6, 8, 10, 15, 20, 25, 30)
fitg <- function(f, d, fam = gaussian()) { d <- copy(d); d[, wt := if (fam$family == "binomial") 1 else T]
  tryCatch(bam(f, data = d, weights = wt, family = fam, discrete = TRUE, method = "fREML", nthreads = 1), error = function(e) { message("fit failed: ", conditionMessage(e)); NULL }) }
fit_unit <- function(d, grid, Tm, xvar = "RD", smax = FALSE, lsm0 = NA_real_, mfam = gaussian()) {
  te_ <- sprintf("te(%s, lh, k = c(8, 5))", xvar); te2 <- sprintf("te(%s, lh, k = c(6, 4))", xvar); ad <- if (smax) " + s(lsm, k = 5)" else ""
  f <- function(y, t) as.formula(paste(y, "~", t, ad))
  m <- list(Gc = fitg(f("gc", te_), d), Gv = fitg(f("gv", te_), d), Ndc = fitg(f("nc", te_), d), Ndv = fitg(f("nv", te_), d),
            Mbc = fitg(f("mc", te_), d[dist == 0], mfam), Mbv = fitg(f("mv", te_), d[dist == 0], mfam),
            Mdc = fitg(f("mc", te2), d[dist == 1], mfam), Mdv = fitg(f("mv", te2), d[dist == 1], mfam),
            P = fitg(as.formula(paste("dist ~", te2, ad, "+ offset(log(T))")), d, binomial(link = "cloglog")))
  if (any(vapply(m, is.null, TRUE))) return(NULL)
  nd <- data.frame(x = grid$RD, lh = log(grid$HT), lsm = lsm0, T = 1); names(nd)[1] <- xvar
  pr <- function(k) as.numeric(predict(m[[k]], nd, type = "response"))
  eta <- as.numeric(predict(m$P, nd, type = "link")); out <- list(h1 = 1 - exp(-exp(eta)), pT = 1 - exp(-exp(eta) * Tm))
  for (u in c("c", "v")) { G <- pr(paste0("G", u)); Mb <- pr(paste0("Mb", u)); Md <- pr(paste0("Md", u)); Dc <- out$pT * pmax(Md - Mb, 0)
    out[[paste0("G", u)]] <- G; out[[paste0("Mb", u)]] <- Mb; out[[paste0("Md", u)]] <- Md; out[[paste0("Dc", u)]] <- Dc; out[[paste0("N", u)]] <- G - Mb - Dc
    out[[paste0("Nd", u)]] <- pr(paste0("Nd", u)); out[[paste0("res", u)]] <- out[[paste0("N", u)]] - out[[paste0("Nd", u)]] }
  out }
support <- function(d, grid, xvar = "RD") { x <- d[[xvar]]; l <- d$lh; vapply(seq_len(nrow(grid)), function(i) sum(abs(x - grid$RD[i]) <= 0.025 & abs(l - log(grid$HT[i])) <= 0.0953), 1L) }
mask <- function(o, sup) { for (z in names(o)) o[[z]][sup < 30] <- NA; o }
## per height statistics on the net curve (direct net fit Nd is primary for growth comparisons; decomposed N reported alongside)
stats_h <- function(o, grid, fl, col) { out <- list()
  for (H in unique(grid$HT)) { k <- which(grid$HT == H & !is.na(o[[col]])); if (length(k) < 5) next; x <- grid$RD[k]; n <- o[[col]][k]
    at <- function(z) if (z < min(x) - 1e-9 || z > max(x) + 1e-9) NA_real_ else approx(x, n, z)$y; im <- which.max(n); xm <- x[im]
    out[[as.character(H)]] <- c(HT = H, rd_lo = min(x), rd_hi = max(x), rd_max = xm, n_max = n[im], at_edge = as.numeric(im == length(n)),
      ceil_contrast = at(xm + 0.10) - n[im], floor_contrast = at(fl) - at(fl - 0.10), forgone_at_floor = 1 - at(fl) / n[im],
      data_floor = x[which(n >= 0.9 * n[im])[1]], n_floor = at(fl)) }
  do.call(rbind, out) }
ALL <- list(); ST <- list(); REP <- list(); TW <- list(); t0 <- Sys.time()
for (R in names(LEV)) {
  d <- D[region == R]; Hm <- round(median(d$HT0)); grid <- CJ(HT = sort(unique(c(HTG, Hm))), RD = RDG); sup <- support(d, grid); lsm0 <- median(d$lsm)
  pe <- mask(fit_unit(d, grid, TM[[R]]), sup); ps <- mask(fit_unit(d[sample(.N)], grid, TM[[R]]), sup); shuf <- isTRUE(all.equal(pe, ps, tolerance = 1e-6))
  cl <- split(seq_len(nrow(d)), d$LOC); nm <- names(cl)
  bs <- mclapply(seq_len(B), function(b) { set.seed(20261112 + b); ii <- unlist(cl[sample(nm, length(nm), replace = TRUE)], use.names = FALSE)
    f <- fit_unit(d[ii], grid, TM[[R]]); if (is.null(f)) NULL else mask(f, sup) }, mc.cores = NC); bs <- bs[!vapply(bs, is.null, TRUE)]
  q <- function(z, p) apply(do.call(rbind, lapply(bs, `[[`, z)), 2, quantile, p, na.rm = TRUE)
  cv <- data.table(region = R, grid, support_n = sup); for (z in names(pe)) { cv[, (z) := pe[[z]]]; cv[, (paste0(z, "_lo")) := q(z, 0.025)]; cv[, (paste0(z, "_hi")) := q(z, 0.975)] }
  ALL[[R]] <- cv; REP[[R]] <- list(grid = grid, Ndc = do.call(rbind, lapply(bs, `[[`, "Ndc")), Ndv = do.call(rbind, lapply(bs, `[[`, "Ndv")))
  for (col in c("Ndc", "Ndv", "Nc")) { s0 <- stats_h(pe, grid, FLOOR[[R]], col); sb <- lapply(bs, stats_h, grid = grid, fl = FLOOR[[R]], col = col)
    for (H in s0[, "HT"]) { m <- do.call(rbind, lapply(sb, function(s) if (!is.null(s) && H %in% s[, "HT"]) s[s[, "HT"] == H, ] else NULL))
      e <- s0[s0[, "HT"] == H, ]; qq <- function(v, p) if (all(is.na(v))) NA_real_ else unname(quantile(v, p, na.rm = TRUE))
      ST[[length(ST) + 1]] <- data.table(region = R, curve = col, HT = H, ref_height = H == Hm, floor = FLOOR[[R]], boot = nrow(m), shuffle_identical = shuf,
        stat = names(e)[-1], est = as.numeric(e[-1]), lo = apply(m[, -1, drop = FALSE], 2, qq, 0.025), hi = apply(m[, -1, drop = FALSE], 2, qq, 0.975),
        defined_share = colMeans(!is.na(m[, -1, drop = FALSE]))) } }
  saveRDS(list(cv = cv, rep = REP[[R]], bs_n = length(bs)), file.path(OD, sprintf("_ckpt_%s.rds", R)))
  tw1 <- tryCatch(fit_unit(d, grid, TM[[R]], mfam = tw()), error = function(e) NULL)
  if (!is.null(tw1)) { tw1 <- mask(tw1, sup); TW[[R]] <- data.table(region = R, grid, Mbc_tw = tw1$Mbc, Dcc_tw = tw1$Dcc, Nc_tw = tw1$Nc, Mbc_gauss = pe$Mbc, Dcc_gauss = pe$Dcc, Nc_gauss = pe$Nc) }
  cat(R, "done", format(Sys.time() - t0), " boot", length(bs), " shuffle", shuf, "\n") }
if (length(TW)) fwrite(rbindlist(TW, fill = TRUE), file.path(OD, "dst_engine2_tweedie_compare_DATA.csv"))
CV <- rbindlist(ALL); SM <- rbindlist(ST); fwrite(CV, file.path(OD, "dst_engine2_curves_DATA.csv")); fwrite(SM, file.path(OD, "dst_engine2_stats_DATA.csv")); saveRDS(REP, file.path(OD, "dst_engine2_replicates_DATA.rds"))
## verdicts at the reference height, direct net carbon curve
V <- dcast(SM[ref_height == TRUE & curve == "Ndc"], region + HT ~ stat, value.var = c("est", "lo", "hi"))
V[, ceiling := fifelse(is.na(hi_ceil_contrast), "not testable", fifelse(hi_ceil_contrast < 0, "ceiling indicated", fifelse(lo_ceil_contrast > 0, "growth still rising", "not distinguishable")))]
V[, floor_test := fifelse(lo_floor_contrast > 0, "floor supported", fifelse(hi_floor_contrast < 0, "floor contradicted", "not distinguishable"))]
print(V[, .(region, HT, est_rd_max, lo_rd_max, hi_rd_max, est_at_edge, ceiling, est_ceil_contrast, lo_ceil_contrast, hi_ceil_contrast, floor_test, est_floor_contrast, lo_floor_contrast, hi_floor_contrast, est_forgone_at_floor, est_data_floor, lo_data_floor, hi_data_floor)], digits = 3)
fwrite(V, file.path(OD, "dst_engine2_verdicts_DATA.csv"))
## decomposition residual (bootstrapped) at the reference height
RES <- CV[, .(max_abs_res_c = max(abs(resc), na.rm = TRUE), max_abs_res_c_bound = max(pmax(abs(resc_lo), abs(resc_hi)), na.rm = TRUE), mean_net_c = mean(Ndc, na.rm = TRUE)), by = .(region, HT)]
fwrite(RES, file.path(OD, "dst_engine2_decomp_residual_DATA.csv"))

## confounding and measurement error checks (direct net carbon, reference height): rd_max, ceiling contrast, floor contrast
chk <- function(d, R, xvar = "RD", smax = FALSE, lab) { Hm <- round(median(d$HT0)); grid <- CJ(HT = Hm, RD = RDG); sup <- support(d, grid, xvar); lsm0 <- median(d$lsm)
  ff <- as.formula(paste0("nc ~ te(", xvar, ", lh, k = c(8, 5))", if (smax) " + s(lsm, k = 5)" else ""))
  one <- function(z) { m <- fitg(ff, z); if (is.null(m)) return(NULL); nd <- data.frame(x = grid$RD, lh = log(grid$HT), lsm = lsm0); names(nd)[1] <- xvar
    f <- mask(list(Ndc = as.numeric(predict(m, nd))), sup); stats_h(f, grid, FLOOR[[R]], "Ndc") }
  e <- one(d); if (is.null(e)) return(NULL); cl <- split(seq_len(nrow(d)), d$LOC); nm <- names(cl)
  bs <- do.call(rbind, mclapply(seq_len(BV), function(b) { set.seed(30261112 + b); r <- one(d[unlist(cl[sample(nm, length(nm), TRUE)], use.names = FALSE)]); if (is.null(r)) NULL else r }, mc.cores = NC))
  data.table(region = R, check = lab, intervals = nrow(d), HT = Hm, stat = colnames(e)[-1], est = as.numeric(e[1, -1]),
    lo = apply(bs[, -1, drop = FALSE], 2, quantile, 0.025, na.rm = TRUE), hi = apply(bs[, -1, drop = FALSE], 2, quantile, 0.975, na.rm = TRUE)) }
CK <- list()
for (R in names(LEV)) { d <- D[region == R]
  CK[[length(CK) + 1]] <- chk(d, R, smax = TRUE, lab = "plus s(ln SDImax), at regional median SDImax")
  tq <- quantile(d$SDImax, c(1/3, 2/3)); d[, terc := cut(SDImax, c(-Inf, tq, Inf), labels = c("low SDImax", "mid SDImax", "high SDImax"))]
  for (tt in levels(d$terc)) CK[[length(CK) + 1]] <- chk(d[terc == tt], R, lab = paste("tercile:", tt))
  ## regression calibration: start RD predicted from the previous visit's RD (consecutive intervals with a prior consecutive interval ending at this start)
  lag <- d[consecutive == TRUE, .(LOC, tj, RDlag = RD)]; dl <- merge(d, lag, by.x = c("LOC", "ti"), by.y = c("LOC", "tj"))
  if (nrow(dl) > 5000) { f1 <- bam(RD ~ s(RDlag, k = 8) + s(lh, k = 5), data = dl, discrete = TRUE, method = "fREML"); dl[, RDc := as.numeric(predict(f1, dl))]
    CK[[length(CK) + 1]] <- chk(dl, R, lab = "subset with previous visit, observed start RD"); CK[[length(CK) + 1]] <- chk(dl, R, xvar = "RDc", lab = "subset with previous visit, calibrated start RD") }
  cat(R, "checks done", format(Sys.time() - t0), "\n") }
CKs <- rbindlist(CK); fwrite(CKs, file.path(OD, "dst_engine2_confounding_DATA.csv"))
print(dcast(CKs[stat %in% c("rd_max", "ceil_contrast", "floor_contrast")], region + check ~ stat, value.var = "est"), digits = 3)
cat("total time", format(Sys.time() - t0), "\ndone\n")
