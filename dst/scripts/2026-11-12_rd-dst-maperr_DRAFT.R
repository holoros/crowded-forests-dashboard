## 2026-11-12_rd-dst-maperr_DRAFT.R: direct error of the selected Maine 10 m RD product (R1) at held-out Maine TRUE plots, for the calculator pre-fill. Lines 1 to 28
## copied verbatim from ~/jobs/rd_maine10m_20261106/fb_refine.R (builds plot-level truth y and prediction R1). Aggregates only; no plot rows leave the server.
set.seed(42); suppressPackageStartupMessages({ library(data.table); library(ranger) })
J <- path.expand("~/jobs/rd_maine10m_20261106"); O <- path.expand("~/restricted/rd_conus10m"); M <- path.expand("~/restricted/rd_maine10m")
B <- sprintf("A%02d", 0:63); X <- c(B, "ch_eth", "ch_eth_sd"); MX <- paste0("m_", X)
A1 <- readRDS(file.path(O, "a1_model.rds")); m2 <- readRDS(file.path(O, "a2_within_model.rds")); R0 <- readRDS(file.path(O, "replica_models_eth.rds"))
meta <- fread(file.path(O, "plot_meta.csv"))[, .(k, test, eco_l2)]
nm <- merge(rbindlist(lapply(c(2020, 2022, 2023), function(y) fread(file.path(O, sprintf("nbr_metrue_emb_%d.csv", y))))), fread(file.path(O, "nbr_metrue_eth.csv"))[, .(k, m_ch_eth, m_ch_eth_sd)], by = "k")
fe <- function(d) { for (b in X) d[, (paste0("d_", b)) := get(b) - get(paste0("m_", b))]; d[, INVYR := IY]
  d[, `:=`(Dl = predict(m2, d)$predictions, A0 = predict(R0$mN, d)$predictions)]; d }
P <- rbindlist(lapply(c(2020, 2022, 2023), function(y) fread(file.path(O, sprintf("nbr_metruepts_emb_%d.csv", y)))))
P <- merge(P, fread(file.path(O, "nbr_metruepts_eth.csv")), by = "pid")[, k := sub("#.*$", "", pid)]
P <- merge(P, nm, by = c("k", "year"))[, IY := pmin(year, 2023L)]; P <- P[complete.cases(P[, c(X, MX), with = FALSE])]; P <- fe(P)
dm <- P[, .(mDl = mean(Dl), mA0 = mean(A0)), by = .(k, year)]
S <- rbindlist(lapply(c(2020, 2022, 2023), function(y) fread(file.path(M, sprintf("sub_ME_emb_%d.csv", y)))[, year := y]))
S <- merge(merge(S, fread(file.path(M, "sub_ME_chm_eth.csv"))[, .(ks, ch_eth, ch_eth_sd)], by = "ks")[, k := sub("_[0-9]+$", "", ks)], nm, by = c("k", "year"))[, IY := pmin(year, 2023L)]
S <- S[complete.cases(S[, c(X, MX), with = FALSE])]; S <- fe(S); S[, A1 := predict(A1$m, S)$predictions]; S <- merge(S, dm, by = c("k", "year"))
S[, `:=`(R1 = A1 + Dl - mDl, R2 = A1 + A0 - mA0)]
SS <- fread(file.path(J, "rdrelay_conus_subplot_rd_2015plus.csv.gz"))[STATECD == 23][, `:=`(k = sprintf("%d_%d_%d_%d", STATECD, UNITCD, COUNTYCD, PLOT))][, ks := paste0(k, "_", SUBP)]
V <- unique(fread(file.path(J, "rdrelay_plot_rd_visits_2017_2025.csv.gz"))[STATECD == 23][, k := sprintf("%d_%d_%d_%d", STATECD, UNITCD, COUNTYCD, PLOT)][, .(k, INVYR, MEASYEAR)], by = c("k", "INVYR"))
SS <- merge(SS[, .(k, ks, INVYR, ys = pmin(RD_sub, 1))], V, by = c("k", "INVYR"))
SS <- merge(SS, meta[test == 1, .(k)], by = "k")
D <- rbindlist(lapply(c(2020, 2022, 2023), function(y) merge(SS[abs(MEASYEAR - y) <= 1], S[year == y, .(ks, year, A1, R1, R2, A0)], by = "ks")))
sat <- function(o, p) c(p90_ratio = unname(quantile(p, .9) / quantile(o, .9)), cbias_ge075 = mean(p[o >= .75] - o[o >= .75]))
met <- function(o, p, lab, sc) { ok <- is.finite(o) & is.finite(p); o <- o[ok]; p <- p[ok]; bt <- replicate(500, { s <- sample(length(o), replace = TRUE); cor(o[s], p[s]) })
  data.table(scale = sc, model = lab, n = length(o), r = cor(o, p), r_lo = quantile(bt, .025), r_hi = quantile(bt, .975), slope = cov(o, p) / var(o), SDratio = sd(p) / sd(o), t(sat(o, p))) }
qmap <- function(p, o) { pq <- quantile(p, seq(0, 1, .01)); oq <- quantile(o, seq(0, 1, .01)); approx(pq, oq, p, rule = 2, ties = "ordered")$y }
pl <- D[, .(y = mean(ys), R1 = mean(R1)), by = .(k, year, INVYR)]; set.seed(20261112)
e <- pl$R1 - pl$y; cat("plots x years", nrow(pl), " plots", uniqueN(pl$k), "\n")
lo <- unique(pl$k); fo <- setNames(sample(rep(1:5, length.out = length(lo))), lo); pl[, fold := fo[k]]; pl[, cal := NA_real_]
for (f in 1:5) { m <- lm(y ~ R1, pl[fold != f]); pl[fold == f, cal := predict(m, pl[fold == f])] }
mfull <- lm(y ~ R1, pl); ec <- pl$cal - pl$y
cls <- function(x) cut(x, c(-Inf, 0.435, 0.535, Inf), labels = c("below", "in", "above"))
ct <- table(true = cls(pl$y), map_cal = cls(pl$cal))
out <- data.table(n = nrow(pl), plots = uniqueN(pl$k), raw_bias = mean(e), raw_rmse = sqrt(mean(e^2)), raw_mae = mean(abs(e)), raw_within05 = mean(abs(e) <= 0.05), raw_within10 = mean(abs(e) <= 0.10),
  cal_intercept = coef(mfull)[1], cal_slope = coef(mfull)[2], cv_cal_rmse = sqrt(mean(ec^2)), cv_cal_within05 = mean(abs(ec) <= 0.05), cv_cal_within10 = mean(abs(ec) <= 0.10),
  cv_cal_pi95_halfwidth = unname(quantile(abs(ec), 0.95)), north_band_class_agreement = sum(diag(ct)) / sum(ct), sd_true = sd(pl$y), sd_map = sd(pl$R1), r = cor(pl$y, pl$R1))
byc <- pl[, .(n = .N, bias_raw = mean(R1 - y), bias_cal = mean(cal - y), rmse_cal = sqrt(mean((cal - y)^2))), keyby = .(true_class = cut(y, c(0, 0.25, 0.435, 0.535, 0.75, 1.01)))]
print(out, digits = 3); print(byc, digits = 3); print(ct)
fwrite(out, "maperr_summary_DATA.csv"); fwrite(byc, "maperr_by_class_DATA.csv"); fwrite(as.data.table(ct), "maperr_band_confusion_DATA.csv"); cat("done\n")
