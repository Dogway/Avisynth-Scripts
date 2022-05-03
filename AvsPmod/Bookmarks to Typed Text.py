# Macro for AvsPmod
# Just types the bookmarks numbers in your script
# for reusing with DeleteFrame(), ReplaceFramesSimple(), etc

bookmarks = avsp.GetBookmarkList()
bookmarks.sort()
avsp.InsertText("%s, \n"  % bookmarks, )