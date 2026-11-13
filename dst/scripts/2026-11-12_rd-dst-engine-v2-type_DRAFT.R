## 2026-11-12_rd-dst-engine-v2-type_DRAFT.R: direct net carbon curves by region x forest type group over the full top height grid (4 to 30 m), with the
## replicate-wise floor and ceiling tests of engine v2 at every height (B = 100), for groups with at least 6,000 intervals. Lets the calculator use a type
## curve and type ceilings where the type has enough data, as the red team asked. Uses the v2 definitions unchanged; one Gaussian net fit per replicate.
src <- readLines("2026-11-12_rd-dst-engine-v2_DRAFT.R"); i0 <- grep("^ALL <- list", src); eval(parse(text = src[1:(i0 - 1)])); t0 <- Sys.time()
B2 <- as.integer(Sys.getenv("NBOOTV", "100")); D[, tg := TYPGRPCD]; cnt <- D[, .N, by = .(region, tg)][N >= 6000][order(region, -N)]; print(cnt)
fitN <- function(d, grid) { m <- fitg(nc ~ te(RD, lh, k = c(8, 5)), d); if (is.null(m)) return(NULL); list(Ndc = as.numeric(predict(m, data.frame(RD = grid$RD, lh = log(grid$HT))))) }
CV <- list(); ST <- list()
for (i in seq_len(nrow(cnt))) { R <- cnt$region[i]; g <- cnt$tg[i]; d <- D[region == R & tg == g]
  grid <- CJ(HT = HTG, RD = RDG); sup <- support(d, grid); pe <- fitN(d, grid); if (is.null(pe)) next; pe <- mask(pe, sup)
  ps <- mask(fitN(d[sample(.N)], grid), sup); shuf <- isTRUE(all.equal(pe, ps, tolerance = 1e-6))
  cl <- split(seq_len(nrow(d)), d$LOC); nm <- names(cl)
  bs <- mclapply(seq_len(B2), function(b) { set.seed(40261112 + b); f <- fitN(d[unlist(cl[sample(nm, length(nm), TRUE)], use.names = FALSE)], grid); if (is.null(f)) NULL else mask(f, sup) }, mc.cores = NC)
  bs <- bs[!vapply(bs, is.null, TRUE)]; M <- do.call(rbind, lapply(bs, `[[`, "Ndc"))
  CV[[length(CV) + 1]] <- data.table(region = R, tg = g, grid, support_n = sup, Ndc = pe$Ndc, Ndc_lo = apply(M, 2, quantile, 0.025, na.rm = TRUE), Ndc_hi = apply(M, 2, quantile, 0.975, na.rm = TRUE))
  s0 <- stats_h(pe, grid, FLOOR[[R]], "Ndc"); sb <- lapply(bs, stats_h, grid = grid, fl = FLOOR[[R]], col = "Ndc")
  for (H in s0[, "HT"]) { m <- do.call(rbind, lapply(sb, function(s) if (!is.null(s) && H %in% s[, "HT"]) s[s[, "HT"] == H, ] else NULL)); e <- s0[s0[, "HT"] == H, ]
    qq <- function(v, p) if (all(is.na(v))) NA_real_ else unname(quantile(v, p, na.rm = TRUE))
    ST[[length(ST) + 1]] <- data.table(region = R, tg = g, HT = H, intervals = nrow(d), boot = nrow(m), shuffle_identical = shuf, stat = names(e)[-1], est = as.numeric(e[-1]),
      lo = apply(m[, -1, drop = FALSE], 2, qq, 0.025), hi = apply(m[, -1, drop = FALSE], 2, qq, 0.975), defined_share = colMeans(!is.na(m[, -1, drop = FALSE]))) }
  cat(R, g, "done", format(Sys.time() - t0), "shuffle", shuf, "\n") }
fwrite(rbindlist(CV), file.path(OD, "dst_engine2_type_curves_DATA.csv")); fwrite(rbindlist(ST), file.path(OD, "dst_engine2_type_stats_DATA.csv")); cat("done\n")
