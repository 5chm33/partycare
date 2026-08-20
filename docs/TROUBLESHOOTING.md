# PartyCare Visibility and Configuration Guide

## If the Panel Does Not Appear

PartyCare 1.1 adds explicit visibility recovery. After reloading the addon, run:

```text
/partycare config
```

This command forces the panel-visible setting on, asks Ashita ImGui to unhide UI objects when that control is available, and opens the configuration area. Use the following commands if needed:

| Command | Recovery behavior |
|---|---|
| `/partycare show` | Enables panel visibility and clears the global ImGui hide flag when supported |
| `/partycare config` | Shows the panel and opens the settings area |
| `/partycare reset` | Restores the panel’s default position and size, then opens settings |
| `/partycare status` | Reports panel state, demo state, member count, and ImGui availability/visibility state |

The entrypoint now catches and reports rendering failures once instead of silently returning from the presentation callback. Check the in-game chat for a line beginning with `[PartyCare] Panel unavailable` or `[PartyCare] Render error`.

## Moving the Panel

Open **Settings** from the panel title row. With **Lock Position** set to `OFF`, drag the title bar to the desired location. PartyCare captures the final window position and saves it after the movement settles. Use **Lock Position** to prevent accidental repositioning.

## In-Panel Configuration

The settings area uses button-based controls for broad Ashita ImGui compatibility. It supports:

| Control | Effect |
|---|---|
| Lock Position | Enables/disables title-bar movement persistence |
| Show MP | Toggles MP bars |
| Show Status | Toggles non-normal priority text |
| Show Action Bar | Shows/hides manual action labels |
| Width / Height | Resizes the panel |
| Row Height | Adjusts party-frame height |
| Warning HP / Critical HP | Alters visual triage thresholds |
| Reset Layout | Restores default panel geometry |
| Save Configuration | Immediately writes `settings.lua` |

The package migrates existing version-one settings files to version two in memory. The next successful save writes the version-two format, which adds `ui.height` and `ui.settings_open`.

> The configuration menu controls only PartyCare’s own presentation and local intent labels. It cannot enable targeting, spell casts, packet operations, or automated gameplay.
