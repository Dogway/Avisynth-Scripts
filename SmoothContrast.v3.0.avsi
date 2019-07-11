###
### SmoothContrast() - v3.0
###                  By Dogway (19-01-2014)
###                  Big thanks to LaTo for all the support.
###
### Applies contrast in the "S" (sinusoidal) curve fashion using SmoothAdjust by LaTo.
### As a side effect you can also process saturation.
###
###  (http://forum.videohelp.com/threads/369143#post2364054)
###
###
### Dependencies:
###
### Required:
### ------------
###
###   SmoothAdjust      (v3.0 or higher)                    (http://forum.doom9.org/showthread.php?t=154971)
###
### Optional:
### ------------
###        Dither       (1.26.5 or higher for lsb=true)     (http://forum.doom9.org/showthread.php?p=1386559#post1386559)
###
###
####################################

function SmoothContrast( clip c, float "contrast", float "sat",    float  "median", string "range", bool "lsb", \
                                 int   "smooth",   int   "dither", int    "interp", bool   "limit", bool "show" )
{

contrast = default(contrast, 0.0)      # [-1.0 to +1.0]
sat      = default(sat,      contrast) # [-1.0 to +1.0]  Saturation. By default contrast is also applied to the UV planes
range    = default(range,    "TV")     # TV or PC. Luma range of your source, probably TV as SmoothAdjust only accepts yuv
smooth   = default(smooth,   20)       # same as Interp in SmoothAdjust; strength of the smoothing. 0 = off
dither   = default(dither,   100)      # same as Dither in SmoothAdjust; fuzziness of the dither.  -1 = off
interp   = default(interp,   100)      # same as Mode   in SmoothAdjust; curve interpolation curve. 0 = linear
lsb      = default(lsb,      false)    # 16 bits I/O. For using in a 16 bits stacked MSB+LSB chain.
limit    = default(limit,    false)    # Clamp the output to 16-235 for luma & 16-240 for chroma (TVRange)
show     = default(show,     false)    # Show debug. Doesn't work when using "local" mode

median   = Defined(median)?(range=="TV" && contrast!= 0.0\
? ((median-16)/219.0)*255:median):127.5# median defines the luma center point of your source to process contrast from


# Error Report

Assert(range=="TV" || range=="PC", "Unrecognised Range")


# Variables

m   = (!lsb) ? median : median*256
w   = (!lsb) ? 255    : 65280
Cb  = (m)  /2.0
Cw  = (w+m)/2.0
Chw = (w-m)/2.0


# Strings

no = (!lsb) ? "0-0;255-255"
   \        : "0-0;65535-65535"

Y  = (!lsb) ? "0-0;"+string(Cb)+"-"+string(Cb-Cb*contrast)+";"+string(m)+"-"+string(m)+";"+string(Cw)+"-"+string(Cw+Chw*contrast)+";255-255"
   \        : "0-0;"+string(Cb)+"-"+string(Cb-Cb*contrast)+";"+string(m)+"-"+string(m)+";"+string(Cw)+"-"+string(Cw+Chw*contrast)+";65280-65280;65535-65280"

UV = (!lsb) ? "0-"+string(127.5*(-sat))+";255-"+string(255-127.5*(-sat))
   \        : "0-"+string(32640*(-sat))+";65280-"+string(65280-32640*(-sat))+";65535-"+string(65280-32640*(-sat))

Y  = (contrast==0.0) ? no : Y
UV = (sat     ==0.0) ? no : UV


# Contrast

code="""( Ycurve=Y, Ucurve=UV, Vcurve=UV, TVrange=(range=="TV")?2:0, interp=smooth, dither=dither, debug=show, limiter=limit, mode=interp, HQ=true )"""
!lsb ? eval("c.SmoothCurve" + code) : eval("c.SmoothCurve16" + code) }