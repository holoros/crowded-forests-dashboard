"""Build the v2 stand calculator from engine v2 aggregates. Usage: build_calc_v2.py <output_v2 dir> <out html>"""
import sys, json, pandas as pd
src, out = sys.argv[1], sys.argv[2]
c = pd.read_csv(f"{src}/dst_engine2_curves_DATA.csv")
keys = ["Ndc", "Ndv", "Gc", "Mbc", "Dcc", "h1"]
cur = {}
for r, g in c.groupby("region"):
    g = g.sort_values(["HT", "RD"]); cur[r] = {"HT": sorted(g.HT.unique().tolist()), "RD": sorted(g.RD.round(2).unique().tolist())}
    for k in keys:
        for s in ["", "_lo", "_hi"]:
            cur[r][k + s] = {str(int(h) if float(h).is_integer() else h): [None if pd.isna(v) else round(float(v), 4) for v in gg.sort_values("RD")[k + s]] for h, gg in g.groupby("HT")}
st = pd.read_csv(f"{src}/dst_engine2_stats_DATA.csv"); st = st[st.curve == "Ndc"]
S = {}
for (r, h), g in st.groupby(["region", "HT"]):
    d = g.set_index("stat")
    if "floor_contrast" not in d.index: continue
    e, lo, hi = d.loc["floor_contrast", ["est", "lo", "hi"]]
    test = "floor supported" if lo > 0 else ("floor contradicted" if hi < 0 else "not distinguishable")
    rm = d.loc["rd_max", "est"] if "rd_max" in d.index else None
    S.setdefault(r, []).append(dict(HT=float(h), rd_max=None if rm is None or pd.isna(rm) else float(rm), floor_contrast=None if pd.isna(e) else round(e, 4), floor_lo=None if pd.isna(lo) else round(lo, 4), floor_hi=None if pd.isna(hi) else round(hi, 4), floor_test=test if pd.notna(lo) else "not testable at this height"))
v = pd.read_csv(f"{src}/dst_engine2_verdicts_DATA.csv")
LEV = {"North": 0.485, "Central": 0.400, "Southeast": 0.385, "West": 0.405}
sa = pd.read_csv(f"{src}/dst_engine2_stats_DATA.csv"); sa = sa[(sa.curve == "Ndc") & (sa.ref_height == True)].set_index(["region", "stat"])
CEIL = {}
for r in LEV:   # ceiling only where the replicate test indicates one with a testable point estimate and >= 50% of replicates defined
    cc = sa.loc[(r, "ceil_contrast")]; mx = sa.loc[(r, "rd_max")]
    ok = pd.notna(cc.est) and cc.defined_share >= 0.5 and cc.hi < 0
    CEIL[r] = round(max(LEV[r] + 0.05, mx.est), 3) if ok else None
ct = pd.read_csv("2026-11-12_rd-dst-ceilings-by-height_DATA.csv")
for r in S:
    for e in S[r]:
        m = ct[(ct.region == r) & (ct.HT == e["HT"])]
        e["ceiling"] = None if m.empty or pd.isna(m.ceiling.iloc[0]) else float(m.ceiling.iloc[0])
        if not m.empty: e["floor_test"] = m.floor_test.iloc[0]
MAPCONF = {"below": dict(below=66, **{"in": 14}, above=20), "in band": dict(below=45, **{"in": 17}, above=38), "above band": dict(below=12, **{"in": 12}, above=76)}
tg = open("2026-11-12_rd-dst-sdimax-defaults_DATA.json").read()
html = open("2026-11-12_rd-dst-calculator-template-v2_DRAFT.html").read()
for a, b in [("__CURVES__", json.dumps(cur, separators=(",", ":"))), ("__STATS__", json.dumps(S)), ("__CEIL__", json.dumps(CEIL)), ("__MAPCONF__", json.dumps(MAPCONF)), ("__TG__", tg)]:
    assert html.count(a) == 1, a; html = html.replace(a, b)
open(out, "w").write(html); print("CEIL", CEIL, " bytes", len(html))
