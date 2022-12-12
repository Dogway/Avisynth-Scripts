# Macro for AvsPmod
# Adds r1(n,n);  for every bookmark
 
bookmarks = avsp.GetBookmarkList()
bookmarks.sort()
avsp.InsertText("\n\n")
bkNum = len(bookmarks)
def trim(first,last,n):
    return "r1(%d,%d)%s" % (first+1, last-1, n)
if bkNum > 1:
#    avsp.InsertText(trim(0-1,bookmarks[0],"; "))
    for i in range(0,bkNum-1):
        if (i % 2 != 0):
            avsp.InsertText(trim(bookmarks[i],bookmarks[i+1],"; "))
#    avsp.InsertText(trim(bookmarks[-1],avsp.GetVideoFramecount(),""))
elif bkNum == 1:
    avsp.InsertText(trim(bookmarks[0],avsp.GetVideoFramecount(),""))
else:
    avsp.MsgBox("Must set at least one bookmark")