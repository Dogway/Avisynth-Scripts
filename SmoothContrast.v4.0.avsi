###
###                    v3.0 (19-01-2014)
### SmoothContrast() - v4.0 (02-05-2021)
###                  By Dogway
###
### Applies contrast in the "S" (sigmoidal) curve fashion.
###
###
### Dependencies: Avisynth+ r2420 and above
### 
### Performs better in gamma encoded space
###
### Example: SmoothContrast(0.7, 128, 0.0, "PC")
###
####################################


function SmoothContrast(clip c, float "cont", int "pivot", float "sat", string "range"){


    cont    = Default(cont, 0.0)          # [-1.0 to +1.0] can set further though
    sat     = Default(sat,  cont/1.5)     # [-1.0 to +1.0]
    range   = Default(range,  "TV")       # TV or PC. Luma range of your source
										  # Pivot: 64 to 192 (roughly)
    pivot   = Defined(pivot) ? range == "TV" ? (pivot-16.)/219. : pivot/255. : range == "TV" ? 0.50913 : 0.5

    Assert(AvsPlusVersionNumber > 2294, "Update Avisynth+ version")

    range = range == "TV"
    cont    = pow(cont + sign(cont), 3.)
    sat     = sat != 0. ? (1.-max(min(sat, 1.), -1.))/2. - 0.5 : 0.

    rangePC  = range ? "x ymin - ymax ymin - /" : "x range_max /"
    rangeTV  = range ? "ymax ymin - * range_max / ymin +" : ""
    str    = "1. 1. {cont} {pivot}"
    knee   = str + " * exp + /"
    shldr  = str + " 1. - * exp + /"
    ycont  = ""+knee+" A^ "+str+" "+rangePC+" - * exp + / A - "+shldr+" A - / range_max * "+rangeTV+""
    yconti = ""+knee+" A^ {pivot} 1. "+rangePC+" "+shldr+" A - * A + / 1. - log {cont} / - range_max * "+rangeTV+""
    cntrst = cont != 0. ? cont > 0. ? Format(ycont) : Format(yconti) : ""

    rangePCc  = range ? "x range_half - cmax cmin - / range_max * range_half +" : "x"
    rangeTVc  = range ?   "range_half - cmax cmin - * range_max / range_half +" : ""

    strtn  = IsRGB(c) && IsPlanar(c) ? cntrst : sat != 0. ? Format(""+rangePCc+" A^ 1. {sat} - A * {sat} range_max A - * + "+rangeTVc+"") : ""

    expr(c, cntrst, strtn, strtn, scale_inputs = "none" ) }
