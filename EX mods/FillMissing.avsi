# Based on script created by Didée
# Modified by John Meyer on June 29, 2011/2013 (https://forum.doom9.org/showpost.php?p=1619555&postcount=3)
# v1.1  - Updated and Sanitized                  by Dogway on March 05, 2019
# v1.21 - Updated and Sanitized                  by Dogway on   May 18, 2021
# v1.3  - Further optimized (dcycle from DeJump) by Dogway on   Jul 15, 2021
#
# Dependencies:
#   masktools2
#   FrameRateConverter
#     mvtools2
#     RgTools
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


    JumpThresh = Default(JumpThresh,0.8) # Threshold for detecting jumps. Increase to catch more jumps. Should always be less than 1.0
    Fast       = Default(Fast,  false)   # true for fast mode
    dcycle     = Default(dcycle, 20)     # decimation cycle
    showdot    = Default(Show,  false)   # true for troubleshooting; otherwise, false
    Debug      = Default(Debug, false)   # true for troubleshooting; otherwise, false

    source

    double = FrameRateConverter(showdot ? Subtitle("***") : last, preset=Fast ? "fast" : "slow", Framedouble=true)

    #Remove comment from ShowMetrics, and change "return final" to "return test" to look at metrics in order to determine proper JumpThresh
    test=ShowMetrics(source)

    #Generate a white or black frame, depending on frame difference
    Black  = BlankClip( source, Color_yuv=$000000 )
    White  = BlankClip( source, Color_yuv=$FFFFFF )
    #This function returns a white clip whenever a big jump is detected; otherwise a black clip is returned
    #Each YDiff must eliminate Ydiff=0 (duplicate) from moving average
    BWMask = ScriptClip("
            YDif1 = YDifferenceFromPrevious(2)
            YDif1 = YDif1 < 0.2 ? YDifferenceFromPrevious(3)  : YDif1

            YDif2 = YDifferenceFromPrevious(1)
            YDif2 = YDif2 < 0.2 ? YDifferenceFromPrevious(2)  : YDif2

            YDif3 = YDifferenceFromPrevious(-1)
            YDif3 = YDif3 < 0.2 ? YDifferenceFromPrevious(-2) : YDif3

            YDif4 = YDifferenceFromPrevious(-2)
            YDif4 = YDif4 < 0.2 ? YDifferenceFromPrevious(-3) : YDif4

            YDiff = ((YDif1 + YDif2 + YDif3 + YDif4) / 4.0 ) / (YDifferenceFromPrevious() + 0.01) <= JumpThresh ? \
                                                                                                   source.White : \
                                                                                                   source.Black   \
            ",args="source,JumpThresh,Black,White")

    #Generate the 2x framerate mask needed to choose the motion-estimated frames
    themask = interleave(Black,trim(BWMask,1,0))

    #Merge double framerate from original with motion-esimated frames, but only where there are jumps
    #(i.e., original frames are used except at jump points)
    mt_merge(interleave(source,source),double,themask,luma=true,U=3,V=3)

    #Decimate
    RequestLinear(clim=100)
    dcycle = dcycle+dcycle%2
    final=tdecimate(display=false,mode=1,cycleR=dcycle/2,cycle=dcycle)  # Decimate half of all frames (set to twice the length of "normal" dup/drop cycle)


    return debug ? test : final
}

#----------------
#This function displays the YDiff value that will be used for detecting big jumps
#Each YDiff must eliminate Ydiff=0 (duplicate) from moving average

function ShowMetrics (clip c)
{
  fixed=c.ScriptClip("
        YDif1 = YDifferenceFromPrevious(2)
        YDif1 = YDif1 < 0.2 ? YDifferenceFromPrevious(3)  : YDif1

        YDif2 = YDifferenceFromPrevious(1)
        YDif2 = YDif2 < 0.2 ? YDifferenceFromPrevious(2)  : YDif2

        YDif3 = YDifferenceFromPrevious(-1)
        YDif3 = YDif3 < 0.2 ? YDifferenceFromPrevious(-2) : YDif3

        YDif4 = YDifferenceFromPrevious(-2)
        YDif4 = YDif4 < 0.2 ? YDifferenceFromPrevious(-3) : YDif4

        YDiff = ((YDif1 + YDif2 + YDif3 + YDif4) / 4.0 ) / (YDifferenceFromPrevious() + 0.01)

        Subtitle(String(YDiff))",args="c")
  return fixed
}