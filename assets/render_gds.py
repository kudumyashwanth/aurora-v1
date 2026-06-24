import klayout.lay as lay
import klayout.db as db
import sys
gds, png = sys.argv[1], sys.argv[2]
lv = lay.LayoutView()
opt = db.LoadLayoutOptions()
lv.load_layout(gds, opt, 0)
lv.max_hier()
lv.zoom_fit()
lv.save_image(png, 2400, 1760)
print("WROTE", png)
