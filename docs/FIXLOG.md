# Fix log

## 2026-11-08 The Guide stayed on screen after a sequence ended
Symptom: with the display asleep, the self-test found the Guide neither shown (alpha stuck at 0) nor hidden (the panel never ordered out).
Cause: `GuideController` treated "visible" as the panel's alpha and ordered the panel out in the fade's completion handler. While the display sleeps, Core Animation doesn't run the fade, so neither the alpha nor the completion ever arrived.
Fix: the controller keeps its own `isShown` state and orders the panel out by the clock (`asyncAfter` the fade's length), not by the animation's completion.
Rule: Never let an animation's completion decide state. Keep the state yourself and treat the animation as decoration.

## 2026-11-08 An in-place edit of the config didn't reload
Symptom: a script that rewrote `config.json` in place (open, truncate, write) changed the file, but the app kept running the old config until something else touched the folder.
Cause: `ConfigStore` watched only the config's folder. Replacing or renaming a file changes the folder; writing into an existing file doesn't, so no event arrived.
Fix: the store also watches the file itself (write, extend, delete, rename), and watches the file at the path again after every change and every save, since an atomic replace leaves the old watch on a file that's gone.
Rule: Watch a file and its folder. A folder watch misses in-place writes, and a file watch misses replacements unless it's reopened after each one.
