# Based on script created by Didée
# Modified by John Meyer on June 29, 2011/2013 (https://forum.doom9.org/showpost.php?p=1619555&postcount=3)
# v1.10 - Updated and Sanitized                  by Dogway on   Mar 05, 2019
# v1.21 - Updated and Sanitized                  by Dogway on   May 18, 2021
# v1.30 - Further optimized (dcycle from DeJump) by Dogway on   Jul 15, 2021
# v1.31 - Optimize for HBD                       by Dogway on   Aug 15, 2021
# v1.32 - Remove GrunT dependency                by Dogway on   Oct 02, 2021
# v1.40 - BWmask bugfixes                        by Dogway on   Oct 28, 2021
#
# Dependencies:
#   masktools2
#   FrameRateConverter
#     mvtools2
#     RgTools / ExTools
#   TIVTC
#
#
# Create interpolated frames a 2x original frame rate using MVTools2
# Detect jumps
# Create white mask at each jump point; black mask for all other frames
# Repeat each frame of original video and use mask to "choose" between original video, or motion estimated video
# Decimate exactly 50% to get back to original frame rate.
# This decimation removes the dup frames from the original video and also the dups created by repeating each frame of original video
# However, at each point where motion-estimated frame was inserted, no decimation occurs. Thus, if dups=drops, and the drop happens
# within < "cycle" (TDecimate parameter) of the dup, the dup will be removed and the drop will be filled.
# If no drops or dups occur within "cycle," then no motion estimation happens, and decimation merely gets back to original,
# unchanged video.



function FillMissing(clip source, float "JumpThresh", bool "Fast", int "dcycle", bool "Show", bool "debug") {


    JumpThresh = Default(JumpThresh,0.8)   # Threshold for detecting jumps. Increase to catch more jumps. Should always be less than 1.0
    Fast       = Default(Fast,    false)   # true for fast mode
    dcycle     = Default(dcycle,     20)   # Decimation cycle
    showdot    = Default(Show,    false)   # true for troubleshooting; otherwise, false
    Debug      = Default(Debug,   false)   # true for troubleshooting; otherwise, false

    source

    double = FrameRateConverter(showdot ? Subtitle("***") : last, preset=Fast ? "fast" : "slow", Framedouble=true)

    #Remove comment from ShowMetrics, and change "return final" to "return test" to look at metrics in order to determine proper JumpThresh
    src8   = ConvertBits(source, 8, dither=-1)
    test   = ShowMetrics(src8)

    #Generate a white or black frame, depending on frame difference
    Black  = BlankClip( source, Color_yuv=$000000 )
    White  = BlankClip( source, Color_yuv=$FFFFFF )

    #This function returns a white clip whenever a big jump is detected; otherwise a black clip is returned
    #Each YDiff must eliminate Ydiff=0 (duplicate) from moving average
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

    #Generate the 2x framerate mask needed to choose the motion-estimated frames
    themask = Interleave(Black,trim(BWMask,1,0))

    #Merge double framerate from original with motion-esimated frames, but only where there are jumps
    #(i.e., original frames are used except at jump points)
    mt_merge(Interleave(source,source), double, themask, U=3, V=3)

    #Decimate
    RequestLinear(clim=100)
    dcycle = dcycle+dcycle%2
    final  = TDecimate(display=false, mode=1, cycleR=dcycle/2, cycle=dcycle)  # Decimate half of all frames (set to twice the length of "normal" dup/drop cycle)


    return debug ? test : final }

#----------------
#This function displays the YDiff value that will be used for detecting big jumps
#Each YDiff must eliminate Ydiff=0 (duplicate) from moving average

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