"""2026-11-12_rd-dst-strategic_DRAFT.py: strategic view of the RD decision support tool.
Input: the five aggregate distribution files (latest visit of 85,821 unharvested FIA plots; hexagons of 60 km with n >= 20).
Output: share of plots below, inside and above the regional band (leveling point +/- 0.05) per unit, with Wilson 95% intervals
(each plot treated as one sample of forest area), and a score equal to the share inside the band. No plot rows or coordinates."""
import sys, numpy as np, pandas as pd
src, out = sys.argv[1], sys.argv[2]
z = 1.959964
def wilson(p, n):
    c = (p + z*z/(2*n)) / (1 + z*z/n); h = z*np.sqrt(p*(1-p)/n + z*z/(4*n*n)) / (1 + z*z/n)
    return c - h, c + h
units = {"hex": "hex", "state": "STATECD", "ecoregion": "L3", "region": "region", "national": "all"}
frames = []
for u, key in units.items():
    d = pd.read_csv(f"{src}/dst_rd_distribution_{u}_DATA.csv")
    o = pd.DataFrame({"level": u, "unit": d[key].astype(str), "n_plots": d.n, "band_center": d.opt_mean.round(3),
                      "mean_rd": d.mean_rd.round(3), "median_rd": d.q50.round(3)})
    if u == "ecoregion": o["unit_name"] = d.L3NAME; o["region"] = d.region
    for s in ["below", "in", "above"]:
        p = d[f"{s}_reg"]; lo, hi = wilson(p, d.n)
        o[f"share_{s}"] = p.round(4); o[f"share_{s}_lo"] = lo.round(4); o[f"share_{s}_hi"] = hi.round(4)
    o["score_in_band"] = o.share_in
    o["mean_in_band_but_share_low"] = ((d.mean_rd - d.opt_mean).abs() <= 0.05) & (d.in_reg < 0.30)
    frames.append(o)
S = pd.concat(frames, ignore_index=True)
S.to_csv(f"{out}/dst_strategic_band_shares_DATA.csv", index=False)
h = S[S.level == "hex"]
print("hexes", len(h), " median score", h.score_in_band.median().round(3), " hexes whose mean is in band but < 30% of plots are:", int(h.mean_in_band_but_share_low.sum()))
print("median CI width of hex score", (h.share_in_hi - h.share_in_lo).median().round(3))
print(S[S.level.isin(["region", "national"])][["unit", "n_plots", "band_center", "share_below", "share_in", "share_in_lo", "share_in_hi", "share_above"]].to_string(index=False))

## Join the expected cost of sitting outside the band (floor plus evidence ceiling rule, 12 November 2026) from the Cardinal cost step.
if len(sys.argv) > 3:
    cdir = sys.argv[3]; key = {"hex": "hex", "state": "STATECD", "ecoregion": "L3", "region": "region", "national": "all"}; parts = []
    for u, k in key.items():
        c = pd.read_csv(f"{cdir}/dst_strategic_cost_{u}_DATA.csv"); c["unit"] = c[k].astype(str); c["level"] = u
        p = c.share_in_band_floor_rule; lo, hi = wilson(p, c.n)
        c["share_ok"] = p.round(4); c["share_ok_lo"] = lo.round(4); c["share_ok_hi"] = hi.round(4)
        for cc in ["cost_c", "cost_c_se", "cost_v", "cost_v_se"]: c[cc] = c[cc].round(4)
        c["share_cost_supported"] = (c.n_supported / c.n).round(3)
        parts.append(c[["level", "unit", "share_below_floor", "share_above_ceiling", "share_ok", "share_ok_lo", "share_ok_hi", "cost_c", "cost_c_se", "cost_v", "cost_v_se", "share_cost_supported"]])
    M = S.merge(pd.concat(parts), on=["level", "unit"], how="left", validate="one_to_one")
    assert len(M) == len(S) and M.share_ok.notna().all()
    M.to_csv(f"{out}/dst_strategic_view_DATA.csv", index=False)
    r = M[M.level.isin(["region", "national"])]
    print(r[["unit", "share_in", "share_ok", "share_ok_lo", "share_ok_hi", "cost_c", "cost_c_se", "cost_v", "share_cost_supported"]].to_string(index=False))
    h = M[M.level == "hex"]; print("hex share_ok median", h.share_ok.median().round(3), " hexes with cost >= 0.10 Mg C ha-1 yr-1:", int((h.cost_c >= 0.10).sum()), "of", len(h))
