# VHS tape file for recording the Cycles guarded-mode demo
# https://github.com/charmbracelet/vhs

Output demo.gif

Set Width 1000
Set Height 600
Set FontSize 14
Set Theme "Dracula"
Set PlaybackSpeed 2.0

Type "./demo.sh guarded"
Enter

# In Docker: startup (~20s) + guarded run (~75s) + buffer (10s)
Sleep 105s
