# SceneStats_SC to bookmarks
import os
avsname = avsp.SaveScript()
exe = r'C:\AVSMeter3090\AVSMeter64.exe'

if avsname and exe:
    logfilename = avsname + '.log'
    SC_call = 'SceneStats("Range",path="%s")' % (logfilename)
    os.system('%s %s %s %s --stats %s -o nul' % (exe, avsname, logfilename))

    logfile = open(logfilename)
    logs = logfile.readlines()
    logfile.close()
    bookmarks = []
    for logline in logs:
        log = logline.split(' ')
        if log[2] == 'type:I':
            bmpoint = int(log[0].lstrip('in:'))
            bookmarks.append(bmpoint)
    avsp.SetBookmark(bookmarks)