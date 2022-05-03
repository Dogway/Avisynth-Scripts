# python macro for avsp
# replaces current frame with previous.

current = avsp.GetFrameNumber()
margin = 1
previous = current - margin
avsp.InsertText('freezeframe(%i,%i,%i)\n' % (previous, current, previous))
avsp.ShowVideoFrame(forceRefresh=True)