## 2026-11-12_rd-dst-engine-typegroup_DRAFT.R: realism follow-up to the engine. Density related mortality fell above the band at fixed top height in every
## region, against self-thinning. Test: refit the same engine within region x forest type group (TYPGRPCD at the start visit), for groups with at least
## 6,000 intervals, B = 50 whole plot bootstrap, and also express background mortality as a share of standing biomass (B0) to remove the size effect.
suppressPackageStartupMessages({library(data.table); library(mgcv); library(parallel)})
ex <- parse("2026-11-12_rd-dst-engine_DRAFT.R"); stop_at <- which(vapply(ex, function(e) grepl("^ALL <- list", deparse(e)[1]), TRUE))[1]
Sys.setenv(NBOOT = "50"); for (i in seq_len(stop_at - 1)) eval(ex[[i]], globalenv())
TG <- c(`100` = "White/red/jack pine", `120` = "Spruce/fir", `140` = "Longleaf/slash pine", `160` = "Loblolly/shortleaf pine", `200` = "Douglas-fir", `220` = "Ponderosa pine",
        `280` = "Lodgepole pine", `400` = "Oak/pine", `500` = "Oak/hickory", `600` = "Oak/gum/cypress", `700` = "Elm/ash/cottonwood", `800` = "Maple/beech/birch", `900` = "Aspen/birch", `180` = "Pinyon/juniper", `260` = "Fir/spruce/mtn hemlock", `300` = "Hemlock/Sitka spruce", `370` = "California mixed conifer", `920` = "Western oak")
D[, tg := as.character(TYPGRPCD)]; cnt <- D[, .N, by = .(region, tg)][N >= 6000][order(region, -N)]; print(cnt)
RES <- list(); CUR <- list()
for (i in seq_len(nrow(cnt))) { R <- cnt$region[i]; g <- cnt$tg[i]; d <- D[region == R & tg == g]; Hm <- round(median(d$HT0))
  grid <- CJ(HT = Hm, RD = RDG); sup <- support(d, grid); pe <- fit_unit(d, grid); if (is.null(pe)) next; for (nm in names(pe)) pe[[nm]][sup < 30] <- NA
  ps <- fit_unit(d[sample(.N)], grid); for (nm in names(ps)) ps[[nm]][sup < 30] <- NA
  cl <- split(seq_len(nrow(d)), d$LOC); nm <- names(cl)
  bs <- mclapply(seq_len(B), function(b) { set.seed(20261112 + b); ii <- unlist(cl[sample(nm, length(nm), replace = TRUE)], use.names = FALSE)
    f <- fit_unit(d[ii], grid); if (is.null(f)) return(NULL); for (z in names(f)) f[[z]][sup < 30] <- NA; f }, mc.cores = NC); bs <- bs[!vapply(bs, is.null, TRUE)]
  ## background mortality relative to standing biomass: ratio of smooths on undisturbed intervals
  du <- d[dist == 0 & B0 > 10]; fr <- fitg(I(100 * mc / (0.48 * B0)) ~ te(RD, lh, k = c(8, 5)), du); rr <- as.numeric(predict(fr, data.frame(RD = grid$RD, lh = log(Hm)))); rr[sup < 30] <- NA
  q <- function(z, p) apply(do.call(rbind, lapply(bs, `[[`, z)), 2, quantile, p, na.rm = TRUE)
  cv <- data.table(region = R, tg = g, tgname = TG[g], grid, support_n = sup, Mb_rel_pct = rr)
  for (z in c("Nc", "Gc", "Mbc", "Dcc", "h1", "Nv")) { cv[, (z) := pe[[z]]]; cv[, (paste0(z, "_lo")) := q(z, 0.025)]; cv[, (paste0(z, "_hi")) := q(z, 0.975)] }
  CUR[[length(CUR) + 1]] <- cv; k <- cv[!is.na(Nc)]; b <- BAND[[R]]; inb <- abs(k$RD - b) <= 0.0501; hi <- k$RD >= b + 0.15; lo <- k$RD <= b - 0.15
  RES[[length(RES) + 1]] <- data.table(region = R, tg = g, tgname = TG[g], intervals = nrow(d), ref_height_m = Hm, rd_max_supported = max(k$RD), rd_netmax_c = k$RD[which.max(k$Nc)],
    net_band = mean(k$Nc[inb]), net_above15 = mean(k$Nc[hi]), net_below15 = mean(k$Nc[lo]), Mb_band = mean(k$Mbc[inb]), Mb_above15 = mean(k$Mbc[hi]),
    Mbrel_band = mean(k$Mb_rel_pct[inb]), Mbrel_above15 = mean(k$Mb_rel_pct[hi]), h1_band = mean(k$h1[inb]), h1_above15 = mean(k$h1[hi]), shuffle_identical = isTRUE(all.equal(pe, ps, tolerance = 1e-6)))
  cat(R, TG[g], "done\n") }
RS <- rbindlist(RES); print(RS, digits = 3); fwrite(RS, "output/dst_engine_typegroup_summary_DATA.csv"); fwrite(rbindlist(CUR), "output/dst_engine_typegroup_curves_DATA.csv"); cat("done\n")
