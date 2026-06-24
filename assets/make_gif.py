import matplotlib; matplotlib.use("Agg")
import matplotlib.pyplot as plt
from matplotlib.patches import FancyBboxPatch
import matplotlib.animation as animation
import numpy as np
BG="#0d1b2a"; AC="#00d3a7"; AM="#ffb347"; TEAL="#3ec5c1"; FG="#e6edf3"; SUB="#9fb3c8"
N=4
fig,ax=plt.subplots(figsize=(6.6,6.0),facecolor=BG); ax.set_facecolor(BG)
ax.set_xlim(-1.6,N+0.6); ax.set_ylim(-1.0,N+1.4); ax.set_aspect("equal"); ax.axis("off")
ax.text(N/2-0.5,N+1.0,"4×4 Systolic Array — dataflow",ha="center",color=FG,fontsize=14,fontweight="bold")
# PE grid
pes={}
for i in range(N):
    for j in range(N):
        r=FancyBboxPatch((j,N-1-i),0.82,0.82,boxstyle="round,pad=0.03",fc="#163450",ec=AC,lw=1.6)
        ax.add_patch(r); pes[(i,j)]=r
        ax.text(j+0.41,N-1-i+0.41,"·",ha="center",va="center",color=SUB,fontsize=9)
ax.text(-1.1,N-0.6,"A →",color=AM,fontsize=12,fontweight="bold")
ax.text(-1.1,N-1.6,"rows",color=SUB,fontsize=9)
ax.text(N/2-0.5,N+0.45,"B ↓  (weights)",ha="center",color=TEAL,fontsize=11,fontweight="bold")
acc=ax.text(N/2-0.5,-0.7,"",ha="center",color=AC,fontsize=11,fontweight="bold")
FR=34
def upd(f):
    t=f
    for i in range(N):
        for j in range(N):
            # a wave enters PE(i,j) at cycle i+j .. activate
            active = (t-1)<= (i+j) <=(t+0) or ((i+j)<t<=(i+j)+ N+2)
            wave = (i+j)==(t% (2*N))
            pe=pes[(i,j)]
            if (i+j)==(t-1):
                pe.set_facecolor(AM); pe.set_edgecolor("#fff")
            elif (i+j)==(t-2):
                pe.set_facecolor(TEAL); pe.set_edgecolor("#fff")
            elif (i+j)<t:
                pe.set_facecolor("#1d5e54"); pe.set_edgecolor(AC)
            else:
                pe.set_facecolor("#163450"); pe.set_edgecolor(AC)
    done=max(0,min(N*N, (t-1)*N))
    phase = "loading weights" if t<N else ("streaming + accumulating" if t<2*N+2 else "result ready")
    acc.set_text(f"cycle {t:>2}    ·    {phase}    ·    16 MACs / cycle")
    return list(pes.values())+[acc]
ani=animation.FuncAnimation(fig,upd,frames=FR,interval=180,blit=False)
ani.save("assets/systolic_dataflow.gif",writer=animation.PillowWriter(fps=5),dpi=95,savefig_kwargs={"facecolor":BG})
print("gif saved")
