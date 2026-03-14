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

# Stack startup (~15s) + health checks (~7s) + provisioning (~2s) + demo (~30s) + buffer
Sleep 65s
