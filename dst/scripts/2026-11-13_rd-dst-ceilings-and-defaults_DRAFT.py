"""2026-11-13_rd-dst-ceilings-and-defaults_DRAFT.py: writes the two calculator inputs that were derived by hand on 12 November,
so that both now have a deposited producer. Usage: python3 <this> <stats csv> <sdimax typegroup csv> <out dir>
1. 2026-11-12_rd-dst-ceilings-by-height_DATA.csv from dst_engine2_stats_DATA.csv (direct net carbon, Ndc): a ceiling is applied at a
   height when the point estimate of the ceiling contrast is testable, at least half the replicates are testable, and the upper 95%
   bound is below zero; the ceiling is the higher of the band top (leveling point plus 0.05) and the measured peak. Floor verdict from
   the floor contrast interval.
2. 2026-11-12_rd-dst-sdimax-defaults_DATA.json from dst_sdimax_typegroup_DATA.csv: median SDImax, 10th and 90th percentiles and median
   top height (rounded to 0.5 m) by region and forest type group; names are the FIA forest type group names (compiled reference)."""
import sys, json, math, pandas as pd
stats, sdi, out = sys.argv[1], sys.argv[2], sys.argv[3]
LEV = {"North": 0.485, "Central": 0.400, "Southeast": 0.385, "West": 0.405}
s = pd.read_csv(stats); s = s[s.curve == "Ndc"]
rows = []
for (r, h), g in s.groupby(["region", "HT"], sort=True):
    g = g.set_index("stat")
    c = g.loc["ceil_contrast"]; f = g.loc["floor_contrast"]; rmax = g.loc["rd_max", "est"]
    test = pd.notna(c.est) and c.defined_share >= 0.5 and c.hi < 0
    ceiling = round(max(LEV[r] + 0.05, rmax), 3) if test else None
    if pd.isna(f.est) or f.defined_share < 0.5: ft = "not testable"
    elif f.lo > 0: ft = "floor supported"
    elif f.hi < 0: ft = "floor contradicted"
    else: ft = "not distinguishable"
    rows.append(dict(region=r, HT=h, rd_max=rmax, ceil_contrast=c.est, ceil_lo=c.lo, ceil_hi=c.hi, ceil_defined_share=c.defined_share, ceiling=ceiling, floor_test=ft))
pd.DataFrame(rows).to_csv(f"{out}/2026-11-12_rd-dst-ceilings-by-height_DATA.csv", index=False)
NAMES = {100: "White/red/jack pine", 120: "Spruce/fir", 140: "Longleaf/slash pine", 160: "Loblolly/shortleaf pine", 180: "Pinyon/juniper",
         200: "Douglas-fir", 220: "Ponderosa pine", 260: "Fir/spruce/mountain hemlock", 280: "Lodgepole pine", 300: "Hemlock/Sitka spruce",
         360: "Other western softwoods", 370: "California mixed conifer", 400: "Oak/pine", 500: "Oak/hickory", 600: "Oak/gum/cypress",
         700: "Elm/ash/cottonwood", 800: "Maple/beech/birch", 900: "Aspen/birch", 920: "Western oak", 940: "Tanoak/laurel",
         960: "Other hardwoods", 970: "Woodland hardwoods"}
t = pd.read_csv(sdi)
J = [dict(region=x.region, code=int(x.TYPGRPCD), name=NAMES[int(x.TYPGRPCD)], sdimax=int(x.sdimax_med), p10=int(x.sdimax_p10), p90=int(x.sdimax_p90),
          ht=math.floor(x.ht_med * 2 + 0.5) / 2) for x in t.itertuples()]
with open(f"{out}/2026-11-12_rd-dst-sdimax-defaults_DATA.json", "w") as fh: json.dump(J, fh)
print("wrote", len(rows), "height rows and", len(J), "type groups")
