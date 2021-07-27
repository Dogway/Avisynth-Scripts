# AviSynth+ Scripts

Collection of filters for AviSynth+ 3.5 and above. Improved modern syntax allows much greater performance and HBD support (high bit depths).

For a full description of each check the main forum thread in [Doom9](https://forum.doom9.org/showthread.php?t=182881).

------

## License Disclaimer

This GitHUb repository is licensed under the GNU General Public License v3.0 (GPL3) license except noted otherwise below or within each script file.

**ExTools**: ex_expand(), ex_inpand(), ex_deflate(), ex_inflate() and some ex_median() and ex_repair() modes have been adapted and ported from RGTools under [MIT license](https://github.com/pinterf/RgTools/blob/master/LICENSE).

**ex_median()**
median    - removegrain(4)
undot     - removegrain(1)
undot2    - removegrain(2)
undot3    - removegrain(3)
undot4    - removegrain(4)
edgeS     - removegrain(17)
edgeW     - removegrain(18)
edgeC     - removegrain(26)
edgeCL    - removegrain(27)
cartoon   - removegrain(22)
vertical  - VerticalCleaner mode=1
verticalS - VerticalCleaner mode=2

**ex_repair()**
median    - repair(4)
medianc   - repair(14)
undot     - repair(1)
undot2    - repair(2)
undot3    - repair(3)
undot4    - repair(4)
undot4c   - repair(14)
edgeS     - repair(17)
edgeW     - repair(18)
cartoon   - repair(22)
cartoonc  - repair(19)
temp0     - TemporalRepair mode=0
temp1     - TemporalRepair mode=1
temp2     - TemporalRepair mode=2
temp3     - TemporalRepair mode=3
temp4     - TemporalRepair mode=4

**ExTools**: some **ex_edge()** modes are modified ports under [GPL2](https://github.com/pinterf/masktools/blob/16bit/LICENSE) and [Apache](https://github.com/groucho86/G41Fun/blob/master/LICENSE) licenses.

**ex_edge()** from masktools2 (GPL2):
prewitt
hprewitt
sobel  
roberts
laplace
cartoon
min/max

**ex_edge()** from G41fun.py (Apache):
scharr 
frei-chen
robinson
kayyali
FDoG   
TEdge  
kirsch 