# PartyCare Interface Polish Update

## What Changed

The previous single-window layout placed the Settings control beside a long title inside a narrow panel. The supplied screenshot showed that this clipped the control, forced a scrollbar, and made the configuration path hard to use.

PartyCare now uses **two independent windows**:

| Window | Purpose | Default behavior |
|---|---|---|
| `PartyCare` | Compact party-health panel and manual action palette | Auto-height, wider rows, no forced scrollbar from a fixed short height |
| `PartyCare Settings` | Layout and display controls | Opens from the full-width **Open Settings** button and moves independently |

## Main Panel

The main panel now places **Open Settings** on its own full-width row below the title. That prevents title/action clipping. Its height is automatic by default, allowing the party-frame list to grow naturally rather than immediately creating a scrollbar.

## Settings Window

The separate settings window provides panel-width, row-height, visibility, status, MP, action-bar, warning threshold, and critical threshold controls. Drag either window by its title bar. Both positions save independently, and **Reset Both Windows** restores the default locations and reinitializes their placement.

## Migration

Existing version-one and version-two settings are migrated to version three automatically. Version three adds:

```lua
ui.settings_x = 360
ui.settings_y = 180
```

The next successful save writes the complete version-three settings table.

## Practical Use

After replacing the addon files, reload and enter:

```text
/partycare config
```

Click **Open Settings** from the main PartyCare panel. You can then move the panel and the configuration window separately. The panel remains manual-only: its action buttons produce local confirmation records and do not select targets or issue casts.
