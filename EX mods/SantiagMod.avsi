###
### SantiagMod  (19-04-2010)
### Simple antialiasing
###
### Original by cretindesalpes (Santiag: https://forum.doom9.org/showthread.php?p=1393006)
### Mod      by Archimedes  (SantiagMod: https://forum.doom9.org/showthread.php?p=1419815)
### Dogway mod: Removed GScript call (GScript builtin in AVS+)
###             Added 'gpuid' arg for EEDI3CL and NNEDI3CL
###             Speed optimizations
###
###
### Requires either of:
###
### EEDI3    (http://avisynth.nl/index.php/Eedi3)
### EEDI3CL  (http://avisynth.nl/index.php/EEDI3CL)
### NNEDI2   (http://avisynth.nl/index.php/Nnedi2)
### NNEDI3   (http://avisynth.nl/index.php/Nnedi3)
### NNEDI3CL (http://avisynth.nl/index.php/NNEDI3CL)
###
###
### Archimedes quote:
### "I've changed the posted function santiag a little bit.
###
###  Santiag has now three parameters: type, strh and strv. Type means the antialiasing type.
###  Possible values are "EEDI3", "NNEDI2" and "NNEDI3". 'strh' is the strength for the horizontal
###  anti aliasing and 'strv' is the strength for the vertical anti aliasing. Default values are:
###  type="nnedi3", strh=1 and strv=1.
###
###  Contrary to the first posted function, santiag(strh=0, strv=0) now means no anti aliasing.
###  I've also corected the center shift. With NNEDI3 as type, the center shift now works correct
###  for all possible input clips (YV12, YUY2 and RGB24)."


function SantiagMod(clip input, int "strh", int "strv", string "type", int "UV", int "threads", int "cores", int "gpuid") {

    input
    bi   = BitsPerComponent()
    rgb  = isRGB()
    fch  = is444() || rgb
    fs   = propNumElements("_ColorRange")  > 0 ? \
           propGetInt     ("_ColorRange") == 0 : rgb

    strh = Default(strh,         1)
    strv = Default(strv,      strh)
    type = Default(type,  "NNEDI3")
    UV   = Default(UV, fch ? 3 : 1)
    gpu  = Default(gpuid,        0)
    th   = Default(threads,      8) # Only for gpu=-1 ("cpu" nnedi3)
    co   = Default(cores,        4) # Only for gpu=-1 ("cpu" nnedi3)

    UV3  = UV!=3 && !isY()
    UV3  ? ExtractY() : last
    bi>8 ? ConvertBits(8, dither=-1, fulls=fs, fulld=fs)       : last

    strh > 0 ? Santiag_helper(type, strh, bi, fs, th, co, gpu) : last
    TurnLeft()
    strv > 0 ? Santiag_helper(type, strv, bi, fs, th, co, gpu) : last
    TurnRight()

    bi>8 ? ConvertBits(bi, fulls=fs, fulld=fs) : last
    UV3  ? CombinePlanes(last, input, planes=rgb ? "RGB" : "YUV", pixel_type=PixelType(input)) : last
    }


function Santiag_helper(clip input, string type, int strength, int bi, bool fulls, int threads, int cores, int gpu) {

    input
    w   = Width()
    h   = Height()
    cpu = gpu < 0

    if (type == "EEDI3") {
      cpu ? EEDI3  (0, dh=True, threads=0) : \
            EEDI3CL(0, dh=True, device=gpu)
      for (i = 2, strength, 1) {
      cpu ? EEDI3  ((i + 1) % 2, dh=False, threads=0) : \
            EEDI3CL((i + 1) % 2, dh=False, device=gpu)
      }
    }
    else if (type == "NNEDI2") {
        NNEDI2(dh=True,  field=0)
      for (i = 2, strength, 1) {
        NNEDI2(dh=False, field=(i + 1) % 2)
      }
    }
    else {
      cpu ? NNEDI3  (0,           qual=2, dh=True,  threads=cores, prefetch=(threads+cores)/2, range=fulls?1:2) : \
            NNEDI3CL(0,           qual=2, dh=True,  device=gpu)
      for (i = 2, strength, 1) {
      cpu ? NNEDI3  ((i + 1) % 2, qual=2, dh=False, threads=cores, prefetch=(threads+cores)/2, range=fulls?1:2) : \
            NNEDI3CL((i + 1) % 2, qual=2, dh=False, device=gpu)
      } }

    Spline36Resize(w, h, 0, 0.5, w, h * 2)
    }