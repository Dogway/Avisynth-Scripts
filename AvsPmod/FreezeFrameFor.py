# python macro for avsp
# replaces current frame with next's.

current = avsp.GetFrameNumber()
margin = 1
next = current + margin
avsp.InsertText('freezeframe(%i,%i,%i)\n' % (current, next, next))
avsp.ShowVideoFrame(forceRefresh=True)