###
### Logo v11.1  (https://forum.doom9.org/showthread.php?t=182881)
###
###  (18-05-2020)
###
### By Dogway with help from Gavino and Didée   (http://forum.doom9.org/showthread.php?t=160285)
### Blending Modes adapted from:Blend_MT_alpha3 (http://forum.doom9.org/showthread.php?p=1400434#post1400434)
### Watermark code adapted from:Didée's Ylevels (http://forum.doom9.org/showthread.php?p=525465#post525465)
### mmod2 function adapted from:                (http://forum.doom9.org/showthread.php?t=157632)
###
###-It is a fast and handy function for adding logos or other type of
### elements upfront the video image in YV12 space.
###-It will stack on the video using a mask if the image has alpha.
### Moreover you can blend it using a blending mode.
###-It will only call the logo once, so you might want to add several
### instances of Logo() for multiple displays.
###-For help on parameters, read the #comments on the .avsi script
### right next to the "Defaults()" column.
###-Report bugs or errors if you find any not listed here.
###
### Dependencies:
###    AviSynth+ 3.5+
###
### Todo / Known bugs: 
###   -Add YUY2 and interlaced support
###   -Fix Chroma in Blending Modes
###   -Fix FadeOut problem when end=Framecount-1
###   -Add option for negative "y" values (hidden logo)
###   -Use dissolve and masktools2 to avoid using Blackness in FadeX()(?)
###   -Wiser trim mechanics(?)
###   -Add a loop option (repeat every n frames)
###   -Replace frames with seconds (or add option)
###   -Add option to load an external mask
###   -Add horizontal and vertical logo panning option
###   -Add ability to resize logo internally
###   -Better matte workaround
###
### Changelog:
###
### 11.1 -Updated to ExTools wrappers, including convolutions
###
### 11.0 -Updated to internal Expr() (faster and HBD support)
###      -Replaced resizers to Bicubic (faster without quality loss)
###      -Cosmetics
###
### 10.2 -Swapped CoronaSequence for ImageSource
###
### 10.1 -Added MT support
###      -Defaulted FadeIn FadeOut to 1 second
###
### 10.0 -Optimized (and fixed) modes code
###
### 9.0c -Changed DAR parameter to PAR
###      -Added option to copy over logo chroma in screen/multiply modes
###      -Minor tweaks
###
### 9.0  -Fixed minor bugs
###
### 8.1  -Corrected bug for logo only first frame
###
### 8.0  -Fixed frame alignment bug
###      -Others
###
### 7.1  -Optimized mmod2 function
###      -Fixed some bugs for "end" parameter    
###      -Other minor adjustments
###
### 6.0  -Added DAR flag for anamorphic sources
###      -Added watermark "blending" mode
###      -Fixed FadeIn/Out bug
###      -Other minor adjustments
###
### 5.0  -Fixed and Optimized code (Working Release)
###
### 4.0  -Code rethinking
###      -Fixed code
###      -Added Over blending mode
###      -Added option for matte carving
###
### 3.0  -Automatic alpha detection
###      -Fixed and optimized code
###      -Changed parameters
###      -Added option for animated gifs
###      -Added Multiply blending mode
###
### 2.0  -Fixed and optimized code
###      -Added alpha option
###
### 1.5  -Added logo masking for images with alpha
###      -Added blur parameter
###      -Optimized code
###
### 1.0  -Initial release (26-03-2011)
###
###
########################################################################