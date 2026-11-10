# Minimized-window overview handoff

## Goal

Provide two Hyprland shortcuts for the minimize face:

- `Alt+M` minimizes the focused window while preserving its origin workspace.
- `Super+Alt+M` toggles a focused-monitor overview containing only shelf-minimized windows. The overview uses the screen wallpaper behind its cards and closes via the same shortcut, Escape, or a backdrop click. Selecting a card restores it to its remembered workspace.

## Design decisions

- Keep the current `MinimizeFace.qml` minimize and restore paths as the source of truth; shortcut actions must not bypass `minimizedOrigins`.
- Create the overview as a dedicated local QML component, visually and behaviorally aligned with Serpantinum Expose: wallpaper background, thumbnail grid, arrows, Enter, and `1`–`9` selection.
- Filter overview entries strictly with `isMinimized(t)`, excluding the temporary peek workspace.
- Place one overlay only on the focused monitor. An IPC ownership guard prevents other bar instances from acting on the same shortcut request.
- Every repository implementation step has two commits: implementation, then this checklist update. Push `codex-feature` after each commit.

## Files touched

- `HANDOFF.md` — durable task state and step checklist.
- `MinimizeFace.qml` — IPC actions, focused-monitor ownership, and overview integration.
- `MinimizedOverview.qml` — full-screen minimized-window overview.
- `ScreenLayout.js` — local grid sizing helper derived from the existing Expose layout algorithm.

## Approved edits outside this repository

- `/home/zain/.config/hypr/config/keybinds.lua`: inserted two `hl.bind` blocks at lines 146–158, immediately after the existing Quicklayout toggle bind at lines 139–144:
  - `ALT + M` invokes `qs -p /home/zain/.local/share/serpantinum/src/quickshell/Shell.qml ipc call minimize minimize`.
  - `mainMod + ALT + M` invokes `qs -p /home/zain/.local/share/serpantinum/src/quickshell/Shell.qml ipc call minimize toggleOverview`.

## Checklist

- [x] Step 0 — Record the approved plan in this handoff file; commit and push it.
- [x] Step 1 — Add the local grid helper and minimized-window overview component; `qmlformat` parsing and `qmllint -I . MinimizedOverview.qml` pass. Live test after Step 2: open the overview and verify wallpaper background, minimized-only cards, arrows, Enter, `1`–`9`, Escape, and backdrop dismissal; commit and push.
- [x] Step 2 — Integrate overview state, wallpaper snapshot selection, minimized-only filtering, remembered-workspace restoration, and focused-monitor ownership in `MinimizeFace.qml`; `qmlformat`, `qmllint -I .`, and `git diff --check` pass. Live test after Step 3: run the IPC toggle on each monitor, confirm the overlay appears only on the focused monitor over wallpaper, then select a card and verify its remembered-workspace restore; commit and push.
- [x] Step 3 — Add the focused-monitor-gated `minimize` IPC handler; `qmlformat`, `qmllint -I .`, `git diff --check`, and `qs … ipc call --help` pass. Live test after reload: `qs -p /home/zain/.local/share/serpantinum/src/quickshell/Shell.qml ipc call minimize minimize`, then `… ipc call minimize toggleOverview`; only the focused monitor must respond; commit and push.
- [x] Step 4 — Add the two approved Hyprland bindings at `/home/zain/.config/hypr/config/keybinds.lua:146-158`; `luac -p` passes. The configuration directory is not a Git repository, so the external edit has no separate commit; this handoff update records it and is committed/pushed from this repository.
- [x] Step 5 — Final static review passes: `qmlformat` parses both QML files and the helper; `qmllint -I . MinimizeFace.qml MinimizedOverview.qml`, `luac -p /home/zain/.config/hypr/config/keybinds.lua`, and `git diff --check` pass. No verified defects found; this final handoff checkpoint is committed and pushed.

## Current step

Implementation is complete. The repository is clean on `codex-feature`; the latest implementation and handoff checkpoint commits are pushed to `origin/codex-feature`.

## Next step

Run the live acceptance test after reloading the active Quickshell/Hyprland configuration:

1. Focus a normal window and press `Alt+M`; it must move to the minimize bar.
2. Invoke `Super+Alt+M`; the overview must appear only on the focused monitor, over wallpaper rather than the focused window, and list only shelf-minimized windows.
3. Restore an overview card by click, Enter, and a number key; each window must return to its remembered workspace.
4. Confirm `Super+Alt+M`, Escape, and a backdrop click each close the overview without restoring a window.
5. On a multi-monitor setup, repeat steps 1–4 after moving focus to each monitor; exactly one bar instance must handle each shortcut.

If a live check fails, start from this file and make a new small, independently tested step; do not modify the approved Hyprland binding block unless the failure is binding-specific.
