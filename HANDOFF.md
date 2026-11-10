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

- `/home/zain/.config/hypr/config/keybinds.lua`: insert two `hl.bind` blocks immediately after current line 144 (the existing Quicklayout toggle bind):
  - `ALT + M` invokes `qs -p /home/zain/.local/share/serpantinum/src/quickshell/Shell.qml ipc call minimize minimize`.
  - `mainMod + ALT + M` invokes `qs -p /home/zain/.local/share/serpantinum/src/quickshell/Shell.qml ipc call minimize toggleOverview`.

## Checklist

- [x] Step 0 — Record the approved plan in this handoff file; commit and push it.
- [x] Step 1 — Add the local grid helper and minimized-window overview component; `qmlformat` parsing and `qmllint -I . MinimizedOverview.qml` pass. Live test after Step 2: open the overview and verify wallpaper background, minimized-only cards, arrows, Enter, `1`–`9`, Escape, and backdrop dismissal; commit and push.
- [ ] Step 2 — Integrate overview state, wallpaper selection, filtering, restoration, and focused-monitor ownership in `MinimizeFace.qml`; statically validate imports/references and document the live behavior test; commit and push.
- [ ] Step 3 — Add the minimize IPC handler, verify it preserves existing minimize behavior, and document the IPC command test; commit and push.
- [ ] Step 4 — Add the two approved Hyprland bindings at `/home/zain/.config/hypr/config/keybinds.lua`; validate Lua syntax/config reload instructions; commit the handoff update and push the repository branch.
- [ ] Step 5 — Run the complete static review, record required live-session checks, and finalize this handoff; commit and push.

## Current step

Step 1 implementation is committed and pushed as `463475a`. This handoff update is the remaining Step 1 commit.

## Next step

After this handoff update is committed and pushed, implement Step 2 only: wire the overview into `MinimizeFace.qml`, including wallpaper source, minimized-only filtering, restoration, and focused-monitor ownership. Do not add IPC bindings yet.
