# VHS tape for the Cycles runaway demo GIF — both modes side by side.
# https://github.com/charmbracelet/vhs
#
# record.sh pre-warms the stack and exports CYCLES_BASE_URL / CYCLES_API_KEY /
# CYCLES_TENANT before invoking vhs, so this tape skips docker entirely and
# starts at the MODE 1 banner.

Output demo.gif

Set Width 1000
Set Height 600
Set FontSize 14
Set Theme "Dracula"
Set PlaybackSpeed 1.0

Hide
Type "clear"
Enter
Sleep 200ms
Show

Type "python3 agent/record_orchestrator.py"
Enter

# Total budget: 12s unguarded + 0.5s interstitial + ~8s guarded + 4s summary
# + small startup + buffer = ~32s.
Sleep 32s
