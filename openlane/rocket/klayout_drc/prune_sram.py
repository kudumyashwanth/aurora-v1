import pya
ly = pya.Layout()
ly.read("/home/yashwanth/aurora_v1/openlane/rocket/rocket_tile/runs/rt6/results/final/gds/RocketTile.gds")
cleared=0
for cell in ly.each_cell():
    if cell.name.startswith("sky130_fd_bd_sram"):
        cell.clear(); cleared+=1
print("emptied bitcell cells:", cleared)
ly.write("/home/yashwanth/aurora_v1/openlane/rocket/klayout_drc/rocket_pruned.gds")
print("wrote pruned GDS")
