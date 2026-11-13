## 2026-11-12_rd-dst-engine-v2-lagcheck_DRAFT.R: the regression calibration check of engine v2, rerun with a tolerant match. The previous consecutive
## interval is the one whose end time (ti + T) is within 0.1 yr of this interval's start; exact rounded matching in the checks script found too few pairs.
src <- readLines("2026-11-12_rd-dst-engine-v2_DRAFT.R"); i0 <- grep("^ALL <- list", src); i1 <- grep("^chk <- function", src)
eval(parse(text = src[1:(i0 - 1)])); eval(parse(text = src[i1:(i1 + 7)])); t0 <- Sys.time(); CK <- list()
for (R in names(LEV)) { d <- D[region == R]
  lag <- d[consecutive == TRUE, .(LOC, tend = ti + T, tend_lag = ti + T, RDlag = RD)]; d[, tstart := ti]
  dl <- lag[d, roll = "nearest", on = .(LOC, tend = tstart)][!is.na(RDlag) & abs(tend_lag - ti) <= 0.1 & tend_lag <= ti + 0.1]
  cat(R, "intervals with a previous visit", nrow(dl), "\n")
  if (nrow(dl) > 5000) { f1 <- bam(RD ~ s(RDlag, k = 8) + s(lh, k = 5), data = dl, discrete = TRUE, method = "fREML"); dl[, RDc := as.numeric(predict(f1, dl))]
    cat(R, "first stage R2", round(summary(f1)$r.sq, 3), "\n")
    CK[[length(CK) + 1]] <- chk(dl, R, lab = "subset with previous visit, observed start RD"); CK[[length(CK) + 1]] <- chk(dl, R, xvar = "RDc", lab = "subset with previous visit, calibrated start RD") } }
CKs <- rbindlist(CK); fwrite(CKs, file.path(OD, "dst_engine2_lagcheck_DATA.csv")); print(dcast(CKs[stat %in% c("rd_max", "ceil_contrast", "floor_contrast")], region + check ~ stat, value.var = "est"), digits = 3); cat("done\n")
