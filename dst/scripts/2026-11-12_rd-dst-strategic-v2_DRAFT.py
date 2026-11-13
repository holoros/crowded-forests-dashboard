"""2026-11-12_rd-dst-strategic-v2_DRAFT.py: strategic view v2. Joins the symmetric band shares (Wilson 95% intervals) from the distribution step to the
v2 cost aggregates (per height ceilings, curve plus sampling uncertainty, suppression under 70% costed). Usage: <distribution dir> <cost v2 dir> <out csv>.
Population: unharvested FIA plots at their latest visit; shares are shares of plots, not forest area. No plot rows or coordinates."""
import sys, numpy as np, pandas as pd
dist, cdir, out = sys.argv[1:4]; z = 1.959964
def wilson(p, n):
    c = (p + z*z/(2*n)) / (1 + z*z/n); h = z*np.sqrt(p*(1-p)/n + z*z/(4*n*n)) / (1 + z*z/n); return c - h, c + h
key = {"hex": "hex", "state": "STATECD", "ecoregion": "L3", "region": "region", "national": "all"}; parts = []
for u, k in key.items():
    d = pd.read_csv(f"{dist}/dst_rd_distribution_{u}_DATA.csv"); c = pd.read_csv(f"{cdir}/dst_strategic2_cost_{u}_DATA.csv")
    o = pd.DataFrame({"level": u, "unit": d[k].astype(str), "n_plots": d.n, "band_center": d.opt_mean.round(3), "mean_rd": d.mean_rd.round(3), "median_rd": d.q50.round(3)})
    if u == "ecoregion": o["unit_name"] = d.L3NAME; o["region"] = d.region
    for s in ["below", "in", "above"]:
        p = d[f"{s}_reg"]; lo, hi = wilson(p, d.n); o[f"share_{s}_sym"] = p.round(4); o[f"share_{s}_sym_lo"] = lo.round(4); o[f"share_{s}_sym_hi"] = hi.round(4)
    c["unit"] = c[k].astype(str); lo, hi = wilson(c.share_ok, c.n)
    c = c.assign(share_ok_lo=lo.round(4), share_ok_hi=hi.round(4))
    keep = ["unit", "share_costed", "share_below_floor", "share_above_ceiling", "share_ok", "share_ok_lo", "share_ok_hi", "cost_c", "cost_c_lo", "cost_c_hi", "cost_c_curve_lo", "cost_c_curve_hi", "cost_c_sampling_se", "cost_v", "cost_suppressed"]
    m = o.merge(c[keep], on="unit", how="left", validate="one_to_one"); assert m.share_ok.notna().all(), u
    parts.append(m)
S = pd.concat(parts, ignore_index=True); num = S.select_dtypes("number").columns; S[num] = S[num].round(4); S.to_csv(out, index=False)
r = S[S.level.isin(["region", "national"])]
print(r[["unit", "n_plots", "share_in_sym", "share_ok", "share_ok_lo", "share_ok_hi", "share_below_floor", "share_above_ceiling", "cost_c", "cost_c_lo", "cost_c_hi", "cost_v", "share_costed"]].to_string(index=False))
h = S[S.level == "hex"]; print("hexes", len(h), " cost suppressed", int(h.cost_suppressed.sum()), " cost >= 0.10 among costed", int((h.cost_c >= 0.10).sum()), " median share_ok", round(h.share_ok.median(), 3))
