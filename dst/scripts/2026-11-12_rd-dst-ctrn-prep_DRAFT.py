"""2026-11-12_rd-dst-ctrn-prep_DRAFT.py: plot-visit summaries of the CFRU Commercial Thinning Research Network (gydb-acadian CFRU/CTRN)
for validating the North thin-to floor. Runs on firebreather; writes interval rows (no coordinates) for the R validation step.
Live trees DBH >= 2.54 cm; SDI metric (Dr 25.4 cm) per ha from PTF; top height = mean height of the largest 100 trees per ha, with
missing heights filled from a per plot-visit fit ln(HT) = a + b / DBH (>= 5 measured heights, else the plot mean fit)."""
import sqlite3, os, numpy as np, pandas as pd
D = os.path.expanduser('~/gydb2/build/ws/gydb-acadian/data/CFRU/CTRN/2_Standardized/Standardized.sqlite'); c = sqlite3.connect(D)
t = pd.read_sql('select PlotID, VisitID, YR, DBH, HT, Live, PTF from SV_Trees', c)
v = pd.read_sql('select PlotID, VisitID, YR from S_Visits', c)
tr = pd.read_sql("select PlotID, YR as TYR from SV_PlotTreatments where TreatmentGroup = 'CT'", c).groupby('PlotID').TYR.min().reset_index()
sp = pd.read_sql('select PlotID, RegimeCTRN, TrtYrCTRN from S_Plots', c)
tr = sp.merge(tr, on='PlotID', how='outer'); tr['TYR'] = tr.TYR.fillna(tr.TrtYrCTRN)
tr.loc[tr.RegimeCTRN.fillna('').str.lower().eq('control'), 'TYR'] = np.nan; tr = tr[['PlotID', 'TYR']]
t = t[(t.Live == 1) & (t.DBH >= 2.54) & (t.PTF > 0)].copy()
def hfill(g):
    m = g[(g.HT > 1.3)]
    if len(m) >= 5:
        b = np.polyfit(1 / m.DBH, np.log(m.HT), 1); g['H'] = np.where(g.HT > 1.3, g.HT, np.exp(b[1] + b[0] / g.DBH))
    else: g['H'] = np.where(g.HT > 1.3, g.HT, np.nan)
    return g
t = t.groupby(['PlotID', 'VisitID'], group_keys=False).apply(hfill)
def pfill(g):                                                            # plot level fallback across visits
    m = g[g.HT > 1.3]
    if len(m) >= 5 and g.H.isna().any():
        b = np.polyfit(1 / m.DBH, np.log(m.HT), 1); g.loc[g.H.isna(), 'H'] = np.exp(b[1] + b[0] / g.DBH[g.H.isna()])
    return g
t = t.groupby('PlotID', group_keys=False).apply(pfill)
def top(g):
    g = g.sort_values('DBH', ascending=False); cum = g.PTF.cumsum(); w = np.clip(100 - (cum - g.PTF), 0, g.PTF); ok = g.H.notna() & (w > 0)
    return np.sum(g.H[ok] * w[ok]) / np.sum(w[ok]) if ok.any() else np.nan
pv = t.groupby(['PlotID', 'VisitID', 'YR']).apply(lambda g: pd.Series(dict(SDI=np.sum(g.PTF * (g.DBH / 25.4) ** 1.605), BA=np.sum(g.PTF * np.pi * (g.DBH / 200) ** 2),
     N=g.PTF.sum(), HT0=top(g)))).reset_index()
pv = pv.merge(tr, on='PlotID', how='left').sort_values(['PlotID', 'YR'])
rows = []
for p, g in pv.groupby('PlotID'):
    g = g.reset_index(drop=True)
    for i in range(len(g) - 1):
        a, b = g.iloc[i], g.iloc[i + 1]; T = b.YR - a.YR
        if T <= 0: continue
        thinned = pd.notna(a.TYR)
        if thinned and a.YR < a.TYR <= b.YR: continue                     # interval spans the thinning
        status = 'control' if not thinned else ('post_thin' if a.YR >= a.TYR else 'pre_thin')
        rows.append(dict(PlotID=p, status=status, yr0=a.YR, T=T, SDI0=a.SDI, BA0=a.BA, HT0=a.HT0, dBA=(b.BA - a.BA) / T, yrs_since_thin=(a.YR - a.TYR) if thinned else np.nan))
I = pd.DataFrame(rows); I.to_csv('ctrn_intervals_DATA.csv', index=False)
print(I.groupby('status').agg(n=('PlotID', 'size'), plots=('PlotID', 'nunique'), T=('T', 'median'), SDI0=('SDI0', 'median'), HT0=('HT0', 'median'), dBA=('dBA', 'median')).round(2))
print('missing HT0', I.HT0.isna().sum())
