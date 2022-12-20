## REMOVEGRAIN:

This is the original removegrain() guide I made back in 2011 and that was doing the rounds later on.
Additionally I attach a similar guide for Repair() I made recently.


removegrain(11)     # luma & chroma
removegrain(11,0)   # only luma
removegrain(0,11)   # only chroma
removegrain(0,11,0) # only U plane


*  -1 : bypass (output=0) faster than mode=0 (copy)
*   
*   0 : copy
*   
*   1 : medianblur. Same as Undot, but faster. (single dots) [Default]
*   2 : medianblur. Round up to the second closest minimum luma value in a 3x3 window matrix, if this second lowest value is lower than X pixel value, then leave unchanged. (1x2 spots)
*   3 : medianblur. Sames as mode 2 but rounded up to third  minimum value (but artifact risky). (3pixel-clusters)
*   4 : medianblur. Sames as mode 2 but rounded up to fourth minimum value (but artifact risky). (up to 2x2-pixel-clusters)
*   
*   5 : medianblur. Edge sensitive. Only line pairs are used. Strong  edge protection.
*   6 : medianblur. Edge sensitive. Only line pairs are used. Fairly  edge protection.
*   7 : medianblur. Edge sensitive. Only line pairs are used. Mild    edge protection.
*   8 : medianblur. Edge sensitive. Only line pairs are used. Faint   edge protection.
*   9 : medianblur. Edge sensitive. Only line pairs are used. Barely  edge protection. Practically a spatial variant of trbarry's ST Median filter.
 *   
*   10 : Minimal sharpening. Replaces center pixel by its nearest neighbour. "Very poor denoise sharpener"
*   
*   11 : Blur. 3x3 kernel convolution blur. Better than its counterpart internal Blur(1) (and faster)
*   12 : Blur. Same as 11 but fastest and only <= 1% less precise (still better than Blur(1))
*   
*   13 : Smart bob (for interlaced content). Interpolates the top field.    Similar to Trbarry's weird bob (Tomsmocomp).
*   14 : Smart bob (for interlaced content). Interpolates the bottom field. Similar to Trbarry's weird bob (Tomsmocomp).
*   15 : Smart bob (for interlaced content). Same as mode 13 but more quality and slightly slower.
*   16 : Smart bob (for interlaced content). Same as mode 14 but more quality and slightly slower.
*   
*   17 : medianblur. Same as mode 4 but better edge protection (similar to near artifact free mode 2). Probably best mode of all.
*   18 : medianblur. Same as mode 9 but better edge protection (Same as what mode 17 was to mode 4, but in this case to mode 9, and far less denoising than mode 17)
*   
*   19 : Blur.         Average of its 8 neighbours.
*   20 : Blur. Uniform average of its 8 neighbours. Better than 19 but slower. Very similar to blur(1.58) but faster.
*   
*   21 : medianblur. Clipping is done with respect to averages of neighbours. Best for cartoons.
*   22 : medianblur. Same as mode 21 but much faster (fastest mode of all)
*   
*   23 : Dehalo. Fixes small (as one pixel wide) haloes.
*   24 : Dehalo. Same as 23 but considerably more conservative and slightly slower. Preferred.
*   
*   25 : Minimal sharpening.
*   
*   26 : medianblur. Based off mode 17, but preserves corners, but not thin lines.
*   27 : medianblur. Same as mode 26 but preserves thin lines.


Recommended modes: 12,20 (Gaussian Blur), 17,22 (Median Blur), 22, 27 (Smart Medians)


------


## REPAIR:

These modes are similar to the RemoveGrain modes but requires two clips, as it includes the center pixel of the reference clip for min/max calculation.

*  -1 : Bypass - input plane is trashed thus faster than mode 1
*   
*   0 : Copy - input plane is left intact
*   
*   1 : Clips the source pixel with the Nth minimum and maximum found on the 3×3-pixel square from the reference clip.
*   2 : Clips the source pixel with the Nth minimum and maximum found on the 3×3-pixel square from the reference clip. [Default]
*   3 : Clips the source pixel with the Nth minimum and maximum found on the 3×3-pixel square from the reference clip.
*   4 : Clips the source pixel with the Nth minimum and maximum found on the 3×3-pixel square from the reference clip.
*   
*   5 : Line-sensitive clipping giving the minimal change.
*   
*   6 : Line-sensitive clipping, intermediate.
*   7 : Line-sensitive clipping, intermediate.
*   8 : Line-sensitive clipping, intermediate.
*   
*   9 : Line-sensitive clipping on a line where the neighbor pixels are the closest.
*   10 : Replaces the target pixel with the closest pixel from the 3×3-pixel reference square.
*   
*   11 : Same as modes 1–4 but uses min(Nth_min, c) and max(Nth_max, c) for the clipping, where c is the value of the center pixel of the reference clip.
*   12 : Same as modes 1–4 but uses min(Nth_min, c) and max(Nth_max, c) for the clipping, where c is the value of the center pixel of the reference clip.
*   13 : Same as modes 1–4 but uses min(Nth_min, c) and max(Nth_max, c) for the clipping, where c is the value of the center pixel of the reference clip.
*   14 : Same as modes 1–4 but uses min(Nth_min, c) and max(Nth_max, c) for the clipping, where c is the value of the center pixel of the reference clip.
*   
*   15 : Clips the source pixels using a clipping pair from the RemoveGrain modes 5 and 6.
*   16 : Clips the source pixels using a clipping pair from the RemoveGrain modes 5 and 6.
*   
*   17 : Clips the source pixels using a clipping pair from the RemoveGrain modes 17 and 18.
*   18 : Clips the source pixels using a clipping pair from the RemoveGrain modes 17 and 18.
*   
*   19 :
*   20 :
*   21 :
*   22 :
*   23 :
*   24 :
*   25 : not available
*   26 : Clips the source pixels using a clipping pair from the RemoveGrain mode 26.
*   27 : Clips the source pixels using a clipping pair from the RemoveGrain mode 27.
*   28 : Clips the source pixels using a clipping pair from the RemoveGrain mode 28.

