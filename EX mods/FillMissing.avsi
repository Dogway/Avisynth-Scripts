# FillMissing v2.2 (03-01-2025)
#
# Based on a script created by Didée
# Check Changelog and contributors at the bottom
#
#
# Dependencies:
#   ExTools 10.5
#   ResizersPack 12.1
#   TransformsPack 2.2.1
#   TIVTC 1.0.29
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
# - If no drops or dups occur within "cycle," then no motion estimation happens, and decimation merely gets back to original, unchanged video.


function FillMissing(clip source, float "JumpThresh", bool "Fast", int "dcycle", int "gpuid", bool "Show", bool "debug") {

    source

    fs  = propNumElements("_ColorRange")  > 0 ? \
          propGetInt     ("_ColorRange") == 0 : isRGB(source)

    JumpThresh = Default(JumpThresh,0.8)   # Threshold for detecting jumps. Increase to catch more jumps. Should always be less than 1.0
    Fast       = Default(Fast,     true)   # true for fast mode
    dcycle     = Default(dcycle,     20)   # Decimation cycle
    gpuid      = Default(gpuid,       0)   # ID for the GPU to use
    showdot    = Default(Show,    false)   # true for troubleshooting; otherwise, false
    Debug      = Default(Debug,   false)   # true for debugging;       otherwise, false

    double = RIFEwrap(showdot ? Subtitle("***") : last, model=Fast ? 22 : 46, sc=false, gpuid=gpuid)

    # Remove comment from ShowMetrics, and change "return final" to "return test" to look at metrics in order to determine proper JumpThresh
    src8   = ConvertBits(8, dither=-1, fulls=fs)
    test   = ShowMetrics(src8)

    # Generate a white or black frame, depending on frame difference
    Black  = BlankClip( src8, Color_yuv=$000000, channels=0 )
    White  = BlankClip( src8, Color_yuv=$FFFFFF, channels=0 )

    # This function returns a white clip whenever a big jump is detected; otherwise a black clip is returned
    # Each YDiff must eliminate Ydiff=0 (duplicate) from moving average
    BWMask = ScriptClip(src8, function [src8,JumpThresh,Black,White] () {
            YDif1 = YDifferenceToNext(src8,2)
            YDif1 = YDif1 < 0.2 ? YDifferenceToNext(src8,3)  : YDif1

            YDif2 = YDifferenceToNext(src8,1)
            YDif2 = YDif2 < 0.2 ? YDifferenceToNext(src8,2)  : YDif2

            YDif3 = YDifferenceToNext(src8,-1)
            YDif3 = YDif3 < 0.2 ? YDifferenceToNext(src8,-2) : YDif3

            YDif4 = YDifferenceToNext(src8,-2)
            YDif4 = YDif4 < 0.2 ? YDifferenceToNext(src8,-3) : YDif4

            ((YDif1 + YDif2 + YDif3 + YDif4) * 0.25 ) / (YDifferenceToNext(src8,-1) + 0.01) <= JumpThresh ? White : Black
            })

    # Generate the 2x framerate mask needed to choose the motion-estimated frames
    themask = Interleave(Black,trim(BWMask,1,0)).ConvertBits(BitsPerComponent(source))

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

function ShowMetrics (clip c, float "jumpthresh") {

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

        Subtitle("Probability of frozen Frame= "+String(YDiff),y=26)
    } )
         Subtitle("JumpThreshold= "+String(jumpthresh),y=12)
    }



### Changelog:
###
### v2.2  - Fix for HBD and added Debug Symbols        by Emulgator   Aug 29, 2024
### v2.1  - Fix typo on gpu_id                         by Dogway      Mar 29, 2024
### v2.01 - Add 'sc=false' to RIFEwrap to force MI     by Dogway      Feb 18, 2024
### v2.00 - Replace with RIFEwrap and hence an EX mod  by Dogway      Feb 18, 2023
### v1.41 - Rebase with latest FrameRateConverter      by Dogway      Jan 10, 2022
### v1.40 - BWmask bugfixes                            by Dogway      Oct 28, 2021
### v1.35 - Tdecimate modifications                    by John Meyer  Oct 26, 2021
### v1.32 - Remove GrunT dependency                    by Dogway      Oct 02, 2021
### v1.31 - Optimize for HBD                           by Dogway      Aug 15, 2021
### v1.30 - Further optimized (dcycle from DeJump)     by Dogway      Jul 15, 2021
### v1.21 - Updated and Sanitized                      by Dogway      May 18, 2021
### v1.10 - Updated and Sanitized                      by Dogway      Mar 05, 2019
### v1.05 - Further modifications                      by John Meyer  Mar 13, 2013
### v1.01 - Modified                                   by John Meyer  Jun 29, 2011
### v1.00 - Original script                            by Didée