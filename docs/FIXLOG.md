# Fix log

## 2026-11-08 The Guide stayed on screen after a sequence ended
Symptom: with the display asleep, the self-test found the Guide neither shown (alpha stuck at 0) nor hidden (the panel never ordered out).
Cause: `GuideController` treated "visible" as the panel's alpha and ordered the panel out in the fade's completion handler. While the display sleeps, Core Animation doesn't run the fade, so neither the alpha nor the completion ever arrived.
Fix: the controller keeps its own `isShown` state and orders the panel out by the clock (`asyncAfter` the fade's length), not by the animation's completion.
Rule: Never let an animation's completion decide state. Keep the state yourself and treat the animation as decoration.
