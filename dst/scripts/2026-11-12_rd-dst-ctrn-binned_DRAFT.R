## 2026-11-12_rd-dst-ctrn-binned_DRAFT.R: replaces the spline test in ctrn-validate (k = 6 spline overfit noisy annual intervals; its pass flags were an edge artifact).
## Binned comparison of mean net basal area growth (interval weighted) in three classes around the North floor (0.435), RD = SDI / 1,132,
## controls plus post-thin intervals, whole plot bootstrap B = 1,000. Also restricted to intervals >= 3 yr after thinning.
suppressPackageStartupMessages(library(data.table)); set.seed(20261112)
I <- fread("ctrn_intervals_DATA.csv")[status != "pre_thin"][, RD := SDI0 / 1132]
I[, cls := fcase(RD >= 0.235 & RD < 0.335, "below floor (0.24 to 0.33)", RD >= 0.385 & RD < 0.485, "at floor (0.39 to 0.48)", RD >= 0.535 & RD < 0.70, "above band (0.54 to 0.69)", default = NA_character_)]
run <- function(d, lab) { d <- d[!is.na(cls)]; cl <- split(seq_len(nrow(d)), d$PlotID)
  st <- function(z) { m <- z[, .(g = weighted.mean(dBA, T)), by = cls]; setNames(m$g, m$cls)[c("below floor (0.24 to 0.33)", "at floor (0.39 to 0.48)", "above band (0.54 to 0.69)")] }
  e <- st(d); B <- t(replicate(1000, st(d[unlist(cl[sample(names(cl), length(cl), TRUE)])])))
  dd <- B[, 2] - B[, 1]; du <- B[, 3] - B[, 2]
  data.table(subset = lab, class = names(e), intervals = as.integer(table(factor(d$cls, names(e)))), plots = vapply(names(e), function(k) uniqueN(d[cls == k, PlotID]), 1L),
    net_ba_growth = round(e, 3), lo = round(apply(B, 2, quantile, .025, na.rm = TRUE), 3), hi = round(apply(B, 2, quantile, .975, na.rm = TRUE), 3),
    floor_minus_below = sprintf("%.3f (%.3f to %.3f)", e[2] - e[1], quantile(dd, .025, na.rm = TRUE), quantile(dd, .975, na.rm = TRUE)),
    above_minus_floor = sprintf("%.3f (%.3f to %.3f)", e[3] - e[2], quantile(du, .025, na.rm = TRUE), quantile(du, .975, na.rm = TRUE)), median_height_m = round(median(d$HT0), 1)) }
R <- rbind(run(I, "all control and post-thin intervals"), run(I[status == "control" | yrs_since_thin >= 3], "control and >= 3 yr after thinning"))
print(R); fwrite(R, "ctrn_validation_binned_DATA.csv"); cat("done\n")
