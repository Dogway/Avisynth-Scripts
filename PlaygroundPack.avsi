###                                                  #
###                                                  #
### Image Manipulation Playground Pack 1.0           #
###             By Dogway  (01-04-2012)              #
###                                                  #
###    (http://doom10.org/index.php?topic=2190.0)    #
######################################################
####
#### BitDepth
####
#### function by cretindesalpes (http://forum.doom9.org/showthread.php?p=1516096#post1516096)
#### wrapped by Dogway 30-08-2011
####
####
#### Changes/reduces bitdepth of your clip. I don't see a real use of this, but it's funny nonetheless.
####
#### You will need the Dither package and Masktools2
####
#### Masktools2: http://forum.doom9.org/showthread.php?t=98985
#### Dither:     http://forum.doom9.org/showthread.php?p=1386559#post1386559
####
######################################## 

function BitDepth (clip c, int "bits", int "mode"){

bits = default(bits, 2)    # Valid range: 0 - 8
mode = default(mode, 0)    # Valid modes: 0 - 8. Read Dither documentation for details
mul = String (Pow (2, 8 - bits))
c
Dither_convert_8_to_16()
Dither_lut16 (expr="x "+mul+" /")
DitherPost (mode=mode)
mt_lut ("x "+mul+" *", y=3, u=2, v=2)}


####
#### Scanlines
####
#### function by Didée  (http://forum.doom9.org/showthread.php?p=1432971#post1432971)
#### wrapped by Dogway 10-09-2011
####
####
#### Adds scanlines to your source in yuv space (tv range).
####
#### You will need Masktools2
####
#### Masktools2: http://forum.doom9.org/showthread.php?t=98985
####
######################################## 

function Scanlines(clip c, int "Str", int "Rate"){

strength = default(str, 128) # Strength of the scanline 0 - 255
scanrate = default(rate, 2)  # Define here every how many pixels you want a scanline

c
mt_lutxy(mt_lutspa(relative=false,expr="y "+string(scanrate)+" % 0.01 < "+string(strength)+" 235 ?",U=1,V=1),"x 16 - y 16 - * 219 / 16 +",U=1,V=1)
mt_merge(c,c.greyscale(),U=1,V=1)}



####
#### Dither_average
####
#### function by cretindesalpes  (In Dither Documentation)
#### wrapped and modified to accept 3 clips by Dogway 16-10-2011
####
####
#### Average 2 or 3 clips in high bitdepth linear light. Assumes TVRange inputs. Averaging 3 clips is SLOW.
####
#### Use "bl" to define the weight of the first clip, use "bl2" to define the weight of the second clip when averaging 3 clips.
####
#### You will need the Dither package and Masktools2
####
#### Masktools2: http://forum.doom9.org/showthread.php?t=98985
#### Dither:     http://forum.doom9.org/showthread.php?p=1386559#post1386559
####
######################################## 

function Dither_average(clip a, clip b, clip "c", float "bl", float "bl2", int "mode", bool "lsb_out"){

if1 = Defined(c) ? true : false
lsb_out = default(lsb_out, false)
mode    = default(mode, 6)
bl      = default(bl,  if1 ? 0.333 : 0.5)
bl2     = default(bl2, if1 ? (Defined(bl) ? 1.0-bl/2 : 1.0-bl-bl) : 1.0-bl)
bl3     = if1 ? 1.0-bl-bl2 : nop

bls1 = String ( bl)
bls2 = String ( bl2)
bls3 = String ( bl3)

if1 ? Assert(bl+bl2+bl3==1.0,"The sum of weights must be 1.0") : Assert(bl+bl2==1.0,"The sum of weights must be 1.0")


# 8-bit clips converted to linear 16-bit full range (gamma undone)
ug = " 16 - 0 max 1.41624 / 2.2 ^ "

# Redo the gamma, result in 16 bits YUV
rg = " 0.454545 ^ 362.5585 * 4096 +"


# Blend
if1 ? \
Dither_lutxyz8 (a, b, c,
\	expr ="x     " + bls1 + " * y     " + bls2 + " * z     " + bls3 + " * + + 256 *",
\	yexpr="x" + ug + bls1 + " * y" + ug + bls2 + " * z" + ug + bls3 + " * + + " + rg,
\	y=3, u=3, v=3)  : \
Dither_lutxy8 (a, b,
\	expr ="x     " + bls1 + " * y     " + bls2 + " * + 256 *",
\	yexpr="x" + ug + bls1 + " * y" + ug + bls2 + " * +" + rg,
\	y=3, u=3, v=3)

# Back to 8 bits
lsb_out ? last : DitherPost (mode=mode)}



####
#### Dither_LogPreview 
####
#### function by cretindesalpes (16-10-2011) (http://forum.doom9.org/showthread.php?t=162797)
####
#### The Technicolor CineStyle™ is a Picture Style (profile) for Canon EOS DSLR cameras that optimizes the dynamic range in the image by leveraging the capabilities
#### of the Canon imaging chipset. Cinematographers and their post-production partners will have greater flexibility in color grading and finishing their projects.
#### This script corrects the LUT for previewing purposes on CineStyle or original Cineon sources shot in Log color space.
#### In plain English: it will correct washed out video (due to being in LOG space) by precisely adjusting its contrast.
#### So don't use it for random washed out sources without knowing what you do first.
####
#### You will need the Dither package and Masktools2
####
#### Masktools2: http://forum.doom9.org/showthread.php?t=98985
#### Dither:     http://forum.doom9.org/showthread.php?p=1386559#post1386559
####
######################################## 


Function Dither_LogPreview (clip c)
{
	c
	Dither_convert_yuv_to_rgb (matrix="601", output="rgb48y")
	a  = "0.05"
	x1 = "x 32768 - 32768 /"
	x2 = x1 + " 1.5 * " + x1 + " 3 ^ 0.5 * -"
	x3 = x2 + " 1 " + a + " + * " + x2 + " 3 ^ "+ a +" * -"
	Dither_lut16 (x3 + " 32768 * 32768 +", y=3, u=1, v=1)
	Dither_convert_rgb_to_yuv (
	\	SelectEvery (3, 0),
	\	SelectEvery (3, 1),
	\	SelectEvery (3, 2),
	\	matrix="601", lsb=false, mode=6)
}