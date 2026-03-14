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

# Guarded run: ~2000 calls at 50ms each ≈ 100s real time.
# At 2x playback that's ~50s of GIF.
Sleep 110s
