## 2026-11-13_rd-dst-sdimax-typegroup_DRAFT.R: rebuilds dst_sdimax_typegroup_DATA.csv (median, 10th and 90th percentile plot SDImax and
## median top height by region and forest type group) from the engine input, so the table has a deposited producer. Two candidate row
## definitions are written; the one that reproduces the 12 November table is kept. Runs on firebreather in jobs/rd_dst_engine_20261112.
## Aggregates only: no plot keys or locations are written.
suppressMessages(library(data.table)); setwd("~/jobs/rd_dst_engine_20261112")
x <- as.data.table(readRDS("dst_engine_input_DATA.rds"))
agg <- function(d) d[, .(n = .N, sdimax_med = round(median(SDImax)), sdimax_p10 = round(quantile(SDImax, 0.10, names = FALSE)),
                         sdimax_p90 = round(quantile(SDImax, 0.90, names = FALSE)), ht_med = round(median(HT0), 1)), by = .(region, TYPGRPCD)][order(region, TYPGRPCD)]
A <- agg(x)                                                            # every interval
setorder(x, LOC, ti); B <- agg(x[, .SD[which.max(ti)], by = LOC])       # latest interval per plot, chosen by time
dir.create("output_prov", showWarnings = FALSE)
ref <- fread("output/dst_sdimax_typegroup_DATA.csv")
for (nm in c("A", "B")) { d <- get(nm); m <- merge(ref, d, by = c("region", "TYPGRPCD"), suffixes = c("", ".new"))
  ok <- nrow(m) == nrow(ref) && all(m$n == m$n.new) && all(m$sdimax_med == m$sdimax_med.new) && all(m$sdimax_p10 == m$sdimax_p10.new) &&
        all(m$sdimax_p90 == m$sdimax_p90.new) && all(abs(m$ht_med - m$ht_med.new) < 1e-9)
  cat(nm, "rows in ref", nrow(ref), "matched", nrow(m), "identical", ok, "\n")
  if (ok) fwrite(d[paste(region, TYPGRPCD) %in% paste(ref$region, ref$TYPGRPCD)], "output_prov/dst_sdimax_typegroup_DATA.csv") }
