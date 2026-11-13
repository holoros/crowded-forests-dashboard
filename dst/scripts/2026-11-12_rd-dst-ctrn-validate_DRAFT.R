## 2026-11-12_rd-dst-ctrn-validate_DRAFT.R: validation of the North thin-to floor against the CFRU Commercial Thinning Research Network.
## Pre-stated pass rule: (1) the CTRN curve of net basal area growth on start RD, at the median top height, reaches 90% of its maximum at or below the
## North floor (0.435); (2) growth 0.10 below the floor is lower than at the floor, 95% whole plot bootstrap interval excluding zero.
## RD = SDI / SDImax with the North spruce/fir median SDImax (1,132; FIA plots), the same default as the calculator; sensitivity at the 25th and 75th
## percentile of that SDImax distribution is not available here, so the 10th and 90th (451, 2,080) bracket the scale. Thinned plots enter after thinning only.
suppressPackageStartupMessages({library(data.table); library(mgcv); library(parallel)}); set.seed(20261112)
I <- fread("ctrn_intervals_DATA.csv")[status %in% c("control", "post_thin") & is.finite(HT0) & HT0 > 3]
FLOOR <- 0.435; out <- list()
for (smax in c(1132, 451, 2080)) {
  d <- copy(I)[, RD := SDI0 / smax][, lh := log(HT0)]; Hm <- median(d$HT0); xs <- seq(quantile(d$RD, 0.03), quantile(d$RD, 0.97), by = 0.005)
  fit <- function(z) { f <- gam(dBA ~ s(RD, k = 6) + s(lh, k = 4), data = z, weights = T, method = "REML"); as.numeric(predict(f, data.frame(RD = xs, lh = log(Hm)))) }
  st <- function(y) { g90 <- xs[which(y >= 0.9 * max(y))[1]]; at <- function(x) if (x < min(xs) || x > max(xs)) NA_real_ else approx(xs, y, x)$y
    c(rd_g90 = g90, rd_max = xs[which.max(y)], y_floor = at(FLOOR), d_floor_minus10 = at(FLOOR) - at(FLOOR - 0.10), d_floor_plus10 = at(FLOOR + 0.10) - at(FLOOR)) }
  y0 <- fit(d); s0 <- st(y0); cl <- split(seq_len(nrow(d)), d$PlotID)
  bs <- do.call(rbind, mclapply(1:200, function(b) { set.seed(20261112 + b); ii <- unlist(cl[sample(names(cl), length(cl), replace = TRUE)]); st(fit(d[ii])) }, mc.cores = 8))
  r <- data.table(sdimax = smax, intervals = nrow(d), plots = uniqueN(d$PlotID), thinned_plots = uniqueN(d[status == "post_thin", PlotID]), ref_height_m = round(Hm, 1),
    rd_range = sprintf("%.2f to %.2f", min(xs), max(xs)), stat = names(s0), est = s0, lo = apply(bs, 2, quantile, 0.025, na.rm = TRUE), hi = apply(bs, 2, quantile, 0.975, na.rm = TRUE))
  ys <- fit(d[sample(.N)]); r[, shuffle_identical := isTRUE(all.equal(y0, ys, tolerance = 1e-6))]
  out[[length(out) + 1]] <- r
  if (smax == 1132) { fwrite(data.table(RD = xs, dBA = y0, lo = apply(do.call(rbind, mclapply(1:100, function(b) { set.seed(9e6 + b); ii <- unlist(cl[sample(names(cl), length(cl), replace = TRUE)]); fit(d[ii]) }, mc.cores = 8)), 2, quantile, 0.025),
      hi = apply(do.call(rbind, mclapply(1:100, function(b) { set.seed(9e6 + b); ii <- unlist(cl[sample(names(cl), length(cl), replace = TRUE)]); fit(d[ii]) }, mc.cores = 8)), 2, quantile, 0.975)), "ctrn_curve_DATA.csv")
    RES <- d[status == "post_thin", .SD[which.min(yrs_since_thin)], by = PlotID]
    fwrite(RES[, .(n = .N, resid_rd_q10 = quantile(RD, .1), resid_rd_q50 = median(RD), resid_rd_q90 = quantile(RD, .9), share_below_floor = mean(RD < FLOOR))], "ctrn_residual_rd_DATA.csv") } }
R <- rbindlist(out); fwrite(R, "ctrn_validation_DATA.csv"); print(R, digits = 3)
m <- R[sdimax == 1132]; pass1 <- m[stat == "rd_g90", est] <= FLOOR; pass2 <- m[stat == "d_floor_minus10", lo] > 0
cat("PASS rule 1 (90% of max at or below floor):", pass1, "  PASS rule 2 (loss below floor):", pass2, "\n"); print(fread("ctrn_residual_rd_DATA.csv")); cat("done\n")
