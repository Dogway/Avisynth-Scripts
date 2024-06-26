# Based on script created by Did�e
# Based on script created by Did�e
# Modified by John Meyer on June 29, 2011
# Further modification on June 8, 2013
# Tdecimate modifications on October 26, 2021
# v2.1 Modernized by Dogway on March 29, 2024
#
#
# Dependencies:
#   ExTools
#   ResizersPack
#   TransformsPack
#   TIVTC
#
#
# - Create interpolated frames at 2x original frame rate using RIFE
# - Detect jumps
# - Create white mask at each jump point; black mask for all other frames
# - Repeat each frame of original video and use mask to "choose" between original video, or motion estimated video
# - Decimate exactly 50% to get back to original frame rate.
# - This decimation removes the dup frames from the original video and also the dups created by repeating each frame of original video
# - However, at each point where motion-estimated frame was inserted, no decimation occurs. Thus, if dups=drops, and the drop happens
#   within < "cycle" (TDecimate parameter) of the dup, the dup will be removed and the drop will be filled.
# - If no drops or dups occur within "cycle," then no motion estimation happens, and decimation merely gets back to original,
#   unchanged video.


function FillMissing(clip source, float "JumpThresh", bool "Fast", int "dcycle", bool "Show", int "gpuid", bool "debug") {

    source

    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : isRGB(source)

    JumpThresh = Default(JumpThresh,0.8)   # Threshold for detecting jumps. Increase to catch more jumps. Should always be less than 1.0
    Fast       = Default(Fast,     true)   # true for fast mode
    dcycle     = Default(dcycle,     20)   # Decimation cycle
    showdot    = Default(Show,    false)   # true for troubleshooting; otherwise, false
    gpuid      = Default(gpuid,       0)   # ID for the GPU to use
    Debug      = Default(Debug,   false)   # true for troubleshooting; otherwise, false

    double = RIFEwrap(showdot ? Subtitle("***") : last, model=Fast ? 22 : 23, sc=false, gpuid=gpuid)

    # Remove comment from ShowMetrics, and change "return final" to "return test" to look at metrics in order to determine proper JumpThresh
    src8   = ConvertBits(8, dither=-1, fulls=fs)
    test   = ShowMetrics(src8)

    # Generate a white or black frame, depending on frame difference
    Black  = BlankClip( src8, Color_yuv=$000000, channels=0 )
    White  = BlankClip( src8, Color_yuv=$FFFFFF, channels=0 )

    # This function returns a white clip whenever a big jump is detected; otherwise a black clip is returned
    # Each YDiff must eliminate Ydiff=0 (duplicate) from moving average
    BWMask = ScriptClip(last, function [src8,JumpThresh,Black,White] () {
            YDif1 = YDifferenceToNext(src8,2)
            YDif1 = YDif1 < 0.2 ? YDifferenceToNext(src8,3)  : YDif1

            YDif2 = YDifferenceToNext(src8,1)
            YDif2 = YDif2 < 0.2 ? YDifferenceToNext(src8,2)  : YDif2

            YDif3 = YDifferenceToNext(src8,-1)
            YDif3 = YDif3 < 0.2 ? YDifferenceToNext(src8,-2) : YDif3

            YDif4 = YDifferenceToNext(src8,-2)
            YDif4 = YDif4 < 0.2 ? YDifferenceToNext(src8,-3) : YDif4

            ((YDif1 + YDif2 + YDif3 + YDif4) * 0.25 ) / (YDifferenceToNext(src8,-1) + 0.01) <= JumpThresh ? White : Black
            } )

    # Generate the 2x framerate mask needed to choose the motion-estimated frames
    themask = Interleave(Black,trim(BWMask,1,0))

    # Merge double framerate from original with motion-esimated frames, but only where there are jumps
    # (i.e., original frames are used except at jump points)
    ex_merge(Interleave(source,source), double, themask, luma=false, UV=3)

    # Decimate half of all frames (set to twice the length of "normal" dup/drop cycle)
    RequestLinear(clim=100)
    dcycle = dcycle+dcycle%2
    final  = TDecimate(display=false, mode=1, cycleR=dcycle/2, cycle=dcycle, vfrDec=1, sdlim=0 )


    return debug ? test : final }

#----------------
# This function displays the YDiff value that will be used for detecting big jumps
# Each YDiff must eliminate Ydiff=0 (duplicate) from moving average

function ShowMetrics (clip c) {

    ScriptClip(c, function [c] () {

        YDif1 = YDifferenceToNext(2)
        YDif1 = YDif1 < 0.2 ? YDifferenceToNext(3)  : YDif1

        YDif2 = YDifferenceToNext(1)
        YDif2 = YDif2 < 0.2 ? YDifferenceToNext(2)  : YDif2

        YDif3 = YDifferenceToNext(-1)
        YDif3 = YDif3 < 0.2 ? YDifferenceToNext(-2) : YDif3

        YDif4 = YDifferenceToNext(-2)
        YDif4 = YDif4 < 0.2 ? YDifferenceToNext(-3) : YDif4

        YDiff = ((YDif1 + YDif2 + YDif3 + YDif4) * 0.25 ) / (YDifferenceToNext(-1) + 0.01)

        Subtitle(String(YDiff))
    } ) }