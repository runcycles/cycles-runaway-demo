# VHS tape file for recording the RunCycles guarded-mode demo
# https://github.com/charmbracelet/vhs

Output demo.gif

Set Width 1000
Set Height 600
Set FontSize 14
Set Theme "Dracula"
Set PlaybackSpeed 2.0

Type "./demo.sh guarded"
Enter

# Stack startup (~20s) + guarded run (~76s) + buffer
Sleep 110s
