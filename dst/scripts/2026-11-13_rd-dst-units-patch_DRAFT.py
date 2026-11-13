"""Add a US customary / metric units switch to the RD stand calculator (built page or template).
Usage: python3 units_patch.py <in.html> <out.html>
Conversions are definitional (measurement-units skill): 1 ha = 2.47105 ac, 1 short ton = 0.907185 Mg, 1 m3 = 35.3147 ft3,
1 ft = 0.3048 m, 1 in = 2.54 cm, 1 m2/ha = 4.35600 ft2/ac. Carbon stays carbon (no biomass factor); volume stays cubic
(no cords or board feet, which need project-specific conventions). SDI in US units uses trees per acre and a 10 in reference
diameter, so SDI_us = SDI_metric x 0.404686 and relative density is unchanged. The engine runs in metric throughout; the
switch scales the carbon and volume curves and statistics at display time and converts the inputs."""
import sys
src, out = sys.argv[1], sys.argv[2]
h = open(src, encoding="utf8").read()
def rep(a, b, n=1):
    global h
    c = h.count(a)
    assert c == n, (c, a[:70])
    h = h.replace(a, b)

# ---- HTML: units switch at the top of the Stand card, labels with ids ----
rep('<section class="card"><h2>Stand</h2>',
    '<section class="card"><h2>Stand</h2>\n<div class="units"><label for="units">Units</label><select id="units"><option value="us">US customary (ft, in, acres, short tons, ft³)</option><option value="metric">Metric (m, cm, hectares, Mg, m³)</option></select></div>')
rep('<label>Top height (m)</label>', '<label id="l_ht">Top height (m)</label>')
rep('<label>SDI<sub>max</sub> (metric, D<sub>r</sub> = 25.4 cm)</label>', '<label id="l_sdi">SDI<sub>max</sub> (trees ha⁻¹, D<sub>r</sub> = 25.4 cm)</label>')
rep('<span>Net carbon growth, Mg C ha⁻¹ yr⁻¹</span>', '<span>Net carbon growth, <span class="u_c">Mg C ha⁻¹ yr⁻¹</span></span>')
rep('<span>Net merch. volume growth, m³ ha⁻¹ yr⁻¹</span>', '<span>Net merch. volume growth, <span class="u_v">m³ ha⁻¹ yr⁻¹</span></span>')
rep('<label><input id="imp" type="checkbox" style="width:auto"> Enter trees per acre and inches (both entry modes)</label>',
    '<input id="imp" type="checkbox" hidden>')
rep('ha⁻¹. The default SDI<sub>max</sub> is the median', 'ha⁻¹ (in US customary units, trees per acre with D<sub>r</sub> = 10 in, so SDI is 0.4047 times the metric value and relative density is the same). The default SDI<sub>max</sub> is the median')

# ---- JS: units layer ----
rep('const $=id=>document.getElementById(id);let mode="sum";',
    '''const $=id=>document.getElementById(id);let mode="sum";
const UF={c:1/(0.907185*2.47105),v:35.3147/2.47105,sdi:0.404686,ft:0.3048,inch:2.54};  // Mg C/ha to short tons C/ac = 0.44609; m3/ha to ft3/ac = 14.2913
let US=false;const UL={c:"Mg C ha⁻¹ yr⁻¹",v:"m³ ha⁻¹ yr⁻¹"};
const CKEYS=["Ndc","Gc","Mbc","Dcc"],VKEYS=["Ndv"],SKEYS=["floor_contrast","floor_lo","floor_hi"];
let ORIG=null;
function snap(){ORIG=JSON.parse(JSON.stringify({CURVES,TYPECURVES,STATS,TYPESTATS}));}
function scaleSet(dst,src,fac){for(const k in src){const C=src[k];for(const key of Object.keys(C)){const base=key.replace(/_(lo|hi)$/,"");let m=CKEYS.includes(base)?fac.c:VKEYS.includes(base)?fac.v:null;if(m==null)continue;for(const hh in C[key])dst[k][key][hh]=C[key][hh].map(x=>x==null?null:x*m);}}}
function scaleStats(dst,src,c){for(const k in src)src[k].forEach((s,i)=>SKEYS.forEach(q=>{dst[k][i][q]=s[q]==null?null:s[q]*c;}));}
function applyUnits(){const fac=US?{c:UF.c,v:UF.v}:{c:1,v:1};scaleSet(CURVES,ORIG.CURVES,fac);scaleSet(TYPECURVES,ORIG.TYPECURVES,fac);scaleStats(STATS,ORIG.STATS,fac.c);scaleStats(TYPESTATS,ORIG.TYPESTATS,fac.c);
 UL.c=US?"short tons C ac⁻¹ yr⁻¹":"Mg C ha⁻¹ yr⁻¹";UL.v=US?"ft³ ac⁻¹ yr⁻¹":"m³ ha⁻¹ yr⁻¹";
 document.querySelectorAll(".u_c").forEach(e=>e.textContent=UL.c);document.querySelectorAll(".u_v").forEach(e=>e.textContent=UL.v);
 $("l_ht").textContent=US?"Top height (ft)":"Top height (m)";$("ht").step=US?"1":"0.5";$("ht").min=US?"10":"3";$("ht").max=US?"150":"45";
 $("l_sdi").innerHTML=US?"SDI<sub>max</sub> (trees ac⁻¹, D<sub>r</sub> = 10 in)":"SDI<sub>max</sub> (trees ha⁻¹, D<sub>r</sub> = 25.4 cm)";
 $("l_n").textContent=US?"Trees per acre":"Trees ha⁻¹";$("l_d").textContent=US?"QMD (in)":"QMD (cm)";$("l_q2").textContent=US?"QMD after thinning, if thinning (in)":"QMD after thinning, if thinning (cm)";
 $("l_list").textContent=US?"One line per class: DBH (in), trees per acre":"One line per class: DBH (cm), trees ha⁻¹";}
const hm=()=>US?+$("ht").value*UF.ft:+$("ht").value;          // top height in m for the engine
const sm=()=>US?+$("sdimax").value/UF.sdi:+$("sdimax").value;  // SDImax in metric for the engine
const hd=m=>m==null?"this":(US?Math.round(m/UF.ft)+" ft":m+" m");
const sdiD=x=>US?Math.round(x*UF.sdi):x;
function setUnits(us,convert){const was=US;US=us;$("imp").checked=us;try{localStorage.setItem("rddst_units",us?"us":"metric");}catch(e){}
 if(convert&&was!==us){const cv=(id,fn,d)=>{const v=$(id).value;if(v!=="")$(id).value=+fn(+v).toFixed(d);};
  if(us){cv("ht",x=>x/UF.ft,0);cv("sdimax",x=>x*UF.sdi,0);cv("n",x=>x/2.47105,1);cv("d",x=>x/UF.inch,2);cv("q2",x=>x/UF.inch,2);}
  else{cv("ht",x=>x*UF.ft,1);cv("sdimax",x=>x/UF.sdi,0);cv("n",x=>x*2.47105,1);cv("d",x=>x*UF.inch,2);cv("q2",x=>x*UF.inch,2);}
  $("list").value=$("list").value.split(/\\n/).map(l=>{const p=l.split(/[,\\s]+/).filter(Boolean).map(Number);if(p.length<2)return l;return us?(+(p[0]/UF.inch).toFixed(1))+", "+(+(p[1]/2.47105).toFixed(1)):(+(p[0]*UF.inch).toFixed(1))+", "+(+(p[1]*2.47105).toFixed(1));}).join("\\n");}
 applyUnits();}''')
rep('function tgDefaults(){const t=cur();$("sdimax").value=t.sdimax;$("ht").value=t.ht;calc();}',
    'function tgDefaults(){const t=cur();$("sdimax").value=sdiD(t.sdimax);$("ht").value=US?Math.round(t.ht/UF.ft):t.ht;calc();}')
rep('function calc(){const R=$("region").value,h=+$("ht").value,smax=+$("sdimax").value,',
    'function calc(){const R=$("region").value,h=hm(),smax=sm(),')
rep('$("k_rd2").textContent="SDImax "+t.p10+" to "+t.p90+" gives "', '$("k_rd2").textContent="SDImax "+sdiD(t.p10)+" to "+sdiD(t.p90)+" gives "')
rep('("ceiling passed the growth test at "+B.ceilHT+" m")', '("ceiling passed the growth test at "+hd(B.ceilHT))')
rep('("no ceiling passed the test at "+(B.ceilHT??"this")+" m")', '("no ceiling passed the test at "+hd(B.ceilHT))')
rep('const ftxt=S?(" At "+S.HT+" m the floor test reads: "', 'const ftxt=S?(" At "+hd(S.HT)+" the floor test reads: "')
rep('return " Residual SDI "+Math.round(sdiT)+" ha⁻¹: about "+Math.round(nT)+" trees ha⁻¹ at a post-thin QMD of "+f(q2,1)+" cm ("+f(nT*Math.PI*Math.pow(q2/200,2),1)+" m² ha⁻¹).";',
    'const ba=nT*Math.PI*Math.pow(q2/200,2);return US?(" Residual SDI "+Math.round(sdiT*UF.sdi)+" ac⁻¹: about "+Math.round(nT/2.47105)+" trees per acre at a post-thin QMD of "+f(q2/UF.inch,1)+" in ("+f(ba*4.356,0)+" ft² ac⁻¹)."):(" Residual SDI "+Math.round(sdiT)+" ha⁻¹: about "+Math.round(nT)+" trees ha⁻¹ at a post-thin QMD of "+f(q2,1)+" cm ("+f(ba,1)+" m² ha⁻¹).");')
rep('" Mg C ha⁻¹ yr⁻¹ ("+f(bnv-nv)+" m³ ha⁻¹ yr⁻¹)', '" "+UL.c+" ("+f(bnv-nv,1)+" "+UL.v+")')
for a in ['f(nt-nc)+" Mg C ha⁻¹ yr⁻¹ "', 'f(nf-nc)+" Mg C ha⁻¹ yr⁻¹"', 'f(bnc-nc)+" Mg C ha⁻¹ yr⁻¹ (its upper', '"n/a")+" Mg C ha⁻¹ yr⁻¹."']:
    rep(a, a.replace("Mg C ha⁻¹ yr⁻¹", '"+UL.c+"'))
rep('const rows=[["Net carbon growth, direct fit (Mg C ha⁻¹ yr⁻¹)","Ndc",2],["Gross carbon growth (Mg C ha⁻¹ yr⁻¹)","Gc",2],["Mortality without natural disturbance (Mg C ha⁻¹ yr⁻¹) ⚑","Mbc",2],["Expected loss to natural disturbance (Mg C ha⁻¹ yr⁻¹)","Dcc",3],["Net merchantable volume growth (m³ ha⁻¹ yr⁻¹)","Ndv",2],',
    'const rows=[["Net carbon growth, direct fit ("+UL.c+")","Ndc",2],["Gross carbon growth ("+UL.c+")","Gc",2],["Mortality without natural disturbance ("+UL.c+") ⚑","Mbc",2],["Expected loss to natural disturbance ("+UL.c+")","Dcc",3],["Net merchantable volume growth ("+UL.v+")","Ndv",US?1:2],')
rep('font-weight="700">Net growth (Mg C ha⁻¹ yr⁻¹)</text>`', 'font-weight="700">Net growth (${UL.c})</text>`')
rep('band ${B.floor.toFixed(3)} to ${(B.ceil??B.top).toFixed(3)}; top height ${h} m</text>', 'band ${B.floor.toFixed(3)} to ${(B.ceil??B.top).toFixed(3)}; top height ${hd(h)}</text>')
# the old checkbox handler relabelled only; route everything through the units switch
i = h.find('$("imp").addEventListener("change"'); j = h.find('calc();});', i) + len('calc();});')
assert i > 0 and j > i
h = h[:i] + '$("units").addEventListener("change",()=>{setUnits($("units").value=="us",true);calc();});' + h[j:]
rep('\nfill();\n</script>', '''
snap();let u0="us";try{u0=localStorage.getItem("rddst_units")||"us";}catch(e){}
$("units").value=u0;setUnits(u0=="us",false);fill();
</script>''')
rep('.status{', '.units{display:flex;gap:8px;align-items:center;margin:0 0 10px}.units label{margin:0}.units select{flex:1}\n.status{')
rep('const step=(ymax-ymin)>2?0.5:0.25;','const rg=ymax-ymin,step=rg>2?0.5:rg>1?0.25:rg>0.5?0.1:0.05;')
rep('<option value="us">US customary (ft, in, acres, short tons, ft³)</option><option value="metric">Metric (m, cm, hectares, Mg, m³)</option>','<option value="us">US customary (ft, in, acres)</option><option value="metric">Metric (m, cm, hectares)</option>')
rep('$("k_nv").textContent=f(nv);','$("k_nv").textContent=f(nv,US?1:2);')
rep('"95% "+f(q("Ndv_lo"))+" to "+f(q("Ndv_hi"))','"95% "+f(q("Ndv_lo"),US?1:2)+" to "+f(q("Ndv_hi"),US?1:2)')
rep('if(w<=1e-9)return at(h0);if(w>=1-1e-9)return at(h1);','if((h-h0)<=0.25)return at(h0);if((h1-h)<=0.25)return at(h1);')
open(out, "w", encoding="utf8").write(h)
print("patched", out)
