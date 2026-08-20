# Ashita ImGui Compatibility Fix

## What the Screenshot Confirmed

The screenshot showed that PartyCare loaded successfully but printed:

```text
Panel unavailable: Ashita ImGui bindings are unavailable.
```

The original shell incorrectly assumed that the ImGui API would already be available as a global `imgui` table. Maintained Ashita v4 UI code imports the API explicitly:

```lua
local imgui = require('imgui')
```

PartyCare now follows that pattern. It imports the Ashita ImGui module first and only uses a global `imgui` table as a compatibility fallback.

## API Convention Update

The current Ashita v4 ImGui bindings used by maintained UI addons pass positions and sizes as vector tables, for example:

```lua
imgui.SetNextWindowPos({24, 180})
imgui.SetNextWindowSize({300, 360})
imgui.Button('Label', {-1, 42})
```

PartyCare now uses these conventions rather than scalar coordinate arguments. This is the primary display fix.

## What to Do

1. Replace the previous PartyCare folder with this compatibility-update package.
2. Reload the addon through your ordinary Ashita workflow.
3. Run `/partycare config`.
4. If a panel still does not appear, run `/partycare status` and send the complete PartyCare chat line it reports.

The panel starts with demo data. If the UI renders, you should see entries named **Aegis**, **Willow**, **Kite**, and **Rook**. Open **Settings** in the title row to move, resize, lock, and save the panel.

> This update only corrects the UI-binding path and controls PartyCare’s presentation. It does not add target selection, casting, input injection, packet logic, or automation.

## Sources

[1]: https://github.com/tirem/XIUI "XIUI — maintained Ashita v4 interface reference"
[2]: https://wiki.ashitaxi.com/oldwiki/doku.php?id=addons:functions:imgui "Ashita ImGui Lua API reference"
