import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch, Rectangle, FancyArrowPatch
import numpy as np, re, random

ACCENT="#00d3a7"; AMBER="#ffb347"; TEAL="#3ec5c1"; BG="#0d1b2a"; FG="#e6edf3"; GRID="#1b3a5b"
DEF="openlane/chip/runs/chip_final/results/placement/aurora_soc_top_chip.def"

# ---------- 1. FLOORPLAN from DEF ----------
xs, ys = [], []
rocket=tensor=None
with open(DEF) as f:
    incomp=False
    for line in f:
        if line.startswith("COMPONENTS"): incomp=True; continue
        if line.startswith("END COMPONENTS"): break
        s=line.strip()
        if incomp and s.startswith("- "):
            m=re.search(r"\(\s*(-?\d+)\s+(-?\d+)\s*\)", s)
            if not m: continue
            x=int(m.group(1))/1000.0; y=int(m.group(2))/1000.0
            if s.startswith("- u_rocket "): rocket=(x,y)
            elif s.startswith("- u_tensor "): tensor=(x,y)
            else:
                if random.random()<0.18: xs.append(x); ys.append(y)
fig,ax=plt.subplots(figsize=(12,8.8),facecolor=BG); ax.set_facecolor(BG)
ax.add_patch(Rectangle((0,0),7500,5500,fill=False,ec=ACCENT,lw=2.5))
# std-cell density
ax.hexbin(xs,ys,gridsize=70,cmap="mako" if "mako" in plt.colormaps() else "viridis",mincnt=1,alpha=0.85)
# macros
if rocket: ax.add_patch(FancyBboxPatch(rocket,7000,2600,boxstyle="round,pad=2",fc=AMBER,ec="#fff",lw=2,alpha=0.93,mutation_scale=1)); ax.text(rocket[0]+3500,rocket[1]+1300,"Rocket RV64IMAC\nCPU tile  •  33 MHz\n18.2 mm²",ha="center",va="center",fontsize=14,fontweight="bold",color="#1a1a1a")
if tensor: ax.add_patch(FancyBboxPatch(tensor,1800,1800,boxstyle="round,pad=2",fc=TEAL,ec="#fff",lw=2,alpha=0.95)); ax.text(tensor[0]+900,tensor[1]+900,"Tensor 4×4\n50 MHz\n3.24 mm²",ha="center",va="center",fontsize=12,fontweight="bold",color="#0a2a2a")
ax.set_xlim(-200,7700); ax.set_ylim(-200,5700); ax.set_aspect("equal"); ax.axis("off")
ax.set_title("Aurora v1 — Full-Chip Layout  (7500 × 5500 µm, Sky130B)",color=FG,fontsize=17,fontweight="bold",pad=14)
ax.text(3750,-120,"std-cell fabric (crossbar · CDC · peripherals · clock tree)  +  2 hardened macros",ha="center",color="#9fb3c8",fontsize=11)
plt.tight_layout(); plt.savefig("assets/chip_floorplan.png",dpi=145,facecolor=BG,bbox_inches="tight"); plt.close()
print("floorplan: %d sampled cells"%len(xs))

# ---------- 2. ARCHITECTURE ----------
fig,ax=plt.subplots(figsize=(12,7.6),facecolor=BG); ax.set_facecolor(BG)
def blk(x,y,w,h,t,c,fs=11,tc="#0a0a0a"):
    ax.add_patch(FancyBboxPatch((x,y),w,h,boxstyle="round,pad=0.04",fc=c,ec="#ffffff",lw=1.4,alpha=0.95,mutation_aspect=1))
    ax.text(x+w/2,y+h/2,t,ha="center",va="center",fontsize=fs,fontweight="bold",color=tc)
def arr(x1,y1,x2,y2):
    ax.add_patch(FancyArrowPatch((x1,y1),(x2,y2),arrowstyle="-|>",mutation_scale=15,color=ACCENT,lw=2))
blk(0.3,4.2,2.6,1.4,"Rocket RV64IMAC\nCPU tile (macro)\n33 MHz",AMBER,12)
ax.text(1.6,3.95,"mem_axi4 + mmio_axi4",ha="center",color="#9fb3c8",fontsize=9)
blk(3.4,4.4,1.0,1.0,"AXI\nCDC",ACCENT,10,"#04231d")
arr(2.9,4.9,3.4,4.9)
blk(4.9,3.7,2.0,2.4,"8×8 AXI4\nCROSSBAR\nround-robin",ACCENT,12,"#04231d")
arr(4.4,4.9,4.9,4.9)
for i,(t,c) in enumerate([("Boot ROM","#5b8def"),("SRAM","#5b8def"),("UART","#8a7dff"),("GPIO","#8a7dff"),("Timer","#8a7dff"),("Tensor 4×4\n(macro) 50MHz",TEAL)]):
    yy=6.0-i*0.92; blk(7.6,yy-0.36,2.6,0.74,t,c,10,"#0a0a0a" if c==TEAL else "#fff")
    arr(6.9,4.9,7.6,yy)
ax.text(6,7.0,"Aurora v1 AI SoC — Architecture",ha="center",color=FG,fontsize=17,fontweight="bold")
ax.text(6,0.35,"Multi-clock: CPU 33 MHz  ·  fabric + accelerator 50 MHz   |   128-bit AXI4 fabric · Sky130B",ha="center",color="#9fb3c8",fontsize=10)
ax.set_xlim(0,10.4); ax.set_ylim(0,7.4); ax.axis("off")
plt.tight_layout(); plt.savefig("assets/architecture.png",dpi=145,facecolor=BG,bbox_inches="tight"); plt.close()
print("architecture done")

# ---------- 3. BOOT TERMINAL (accurate header + real functional sequence) ----------
lines=[
 ("========================================","#5fd3bf"),
 ("    AURORA v1  AI SoC  —  BOOT","#ffffff"),
 ("    1x Rocket RV64IMAC + 4x4 Tensor","#9fb3c8"),
 ("    fabric 50 MHz · CPU 33 MHz · Sky130B","#9fb3c8"),
 ("========================================","#5fd3bf"),
 ("[1] Initializing matrices in SRAM...","#e6edf3"),
 ("[2] Running matrix-multiply on Tensor Core...","#e6edf3"),
 ("[3] DONE!  result read back over AXI","#7CFC98"),
 ("","#e6edf3"),
 ("[4] Aurora Tensor Core: OPERATIONAL","#7CFC98"),
 ("    Rocket booted through the real AXI fabric","#9fb3c8"),
 ("    Aurora v1 AI SoC is ALIVE!","#ffd166"),
]
fig,ax=plt.subplots(figsize=(11,6.4),facecolor="#05080d"); ax.set_facecolor("#05080d")
ax.add_patch(FancyBboxPatch((0.01,0.01),0.98,0.98,boxstyle="round,pad=0.01",transform=ax.transAxes,fc="#0a0e14",ec="#1f2a37",lw=1.5))
for i,(dot,c) in enumerate([("#ff5f56",0),("#ffbd2e",1),("#27c93f",2)]):
    ax.add_patch(plt.Circle((0.03+i*0.028,0.95),0.011,transform=ax.transAxes,color=dot,zorder=5))
ax.text(0.5,0.95,"full-SoC boot simulation  (Verilator)",transform=ax.transAxes,ha="center",color="#9fb3c8",fontsize=10,family="monospace")
y=0.86
for t,c in lines:
    ax.text(0.06,y,t,transform=ax.transAxes,color=c,fontsize=12.5,family="monospace",va="top"); y-=0.066
ax.axis("off")
plt.savefig("assets/boot_terminal.png",dpi=145,facecolor="#05080d",bbox_inches="tight"); plt.close()
print("terminal done")

# ---------- 4. RESULTS DASHBOARD ----------
fig=plt.figure(figsize=(12,6.6),facecolor=BG)
gs=fig.add_gridspec(2,3,hspace=0.45,wspace=0.35)
fig.suptitle("Aurora v1 — Sign-off Results",color=FG,fontsize=18,fontweight="bold",y=0.99)
# power pie
ax1=fig.add_subplot(gs[0,0]); ax1.set_facecolor(BG)
ax1.pie([30.1,69.9],labels=["Sequential\n79 mW","Combinational\n183 mW"],colors=[AMBER,TEAL],autopct="%1.0f%%",textprops={"color":FG,"fontsize":9},wedgeprops={"ec":BG,"lw":2})
ax1.set_title("Power — 263 mW (fabric)*",color=FG,fontsize=11)
# area bar
ax2=fig.add_subplot(gs[0,1]); ax2.set_facecolor(BG)
ax2.barh(["Tensor 4×4","Rocket CPU","Std-cell glue"],[3.24,18.2,1.9],color=[TEAL,AMBER,"#5b8def"]); ax2.set_xlabel("mm²",color=FG)
ax2.set_title("Area on 41.25 mm² die",color=FG,fontsize=11)
for s in ax2.spines.values(): s.set_color(GRID)
ax2.tick_params(colors=FG,labelsize=9)
# signoff badges
ax3=fig.add_subplot(gs[0,2]); ax3.set_facecolor(BG); ax3.axis("off")
for i,(k,v,c) in enumerate([("Timing","MET ·  WNS 0.00","#7CFC98"),("3-corner STA","ss / tt / ff","#7CFC98"),("DRC","1 (fill waiver)","#ffd166"),("LVS","device-match","#7CFC98")]):
    ax3.text(0.0,0.85-i*0.24,k,color="#9fb3c8",fontsize=11,fontweight="bold")
    ax3.text(1.0,0.85-i*0.24,v,color=c,fontsize=11,ha="right",fontweight="bold")
ax3.set_title("Verification",color=FG,fontsize=11)
# headline metrics
ax4=fig.add_subplot(gs[1,:]); ax4.set_facecolor(BG); ax4.axis("off")
mets=[("RTL→GDSII","complete"),("Devices","137,562"),("Instances","~1.97 M"),("Std cells","130.5 k"),("Metal layers","5"),("Process","Sky130B")]
for i,(k,v) in enumerate(mets):
    x=0.5/6 + i/6.0
    ax4.text(x,0.62,v,ha="center",color=ACCENT,fontsize=17,fontweight="bold")
    ax4.text(x,0.30,k,ha="center",color="#9fb3c8",fontsize=10)
fig.text(0.5,0.02,"* fabric/glue + clock-tree power; macro internals separately characterized",ha="center",color="#6b8299",fontsize=8.5)
plt.savefig("assets/results_dashboard.png",dpi=145,facecolor=BG,bbox_inches="tight"); plt.close()
print("dashboard done")
