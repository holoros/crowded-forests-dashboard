## 2026-11-12_rd-dst-engine-v2-checks_DRAFT.R: runs only the confounding and measurement error checks of engine v2 (its main fits completed; the checks block
## failed because the input has no tj column). Evaluates the v2 definitions and checks block from 2026-11-12_rd-dst-engine-v2_DRAFT.R with tj = ti + T.
src <- readLines("2026-11-12_rd-dst-engine-v2_DRAFT.R"); i0 <- grep("^ALL <- list", src); i1 <- grep("^## confounding", src)
lagold <- 'lag <- d[consecutive == TRUE, .(LOC, tj, RDlag = RD)]; dl <- merge(d, lag, by.x = c("LOC", "ti"), by.y = c("LOC", "tj"))'
stopifnot(sum(src == paste0("  ", lagold)) == 1)
src[src == paste0("  ", lagold)] <- '  lag <- d[consecutive == TRUE, .(LOC, tj = round(ti + T, 3), RDlag = RD)]; dl <- merge(d[, ti3 := round(ti, 3)], lag, by.x = c("LOC", "ti3"), by.y = c("LOC", "tj"))'
t0 <- Sys.time(); eval(parse(text = c(src[1:(i0 - 1)], src[i1:length(src)])))
