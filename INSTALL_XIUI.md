# PartyCare XIUI-Compatible Build — Installation Guide

## What This Build Changes

This build preserves PartyCare’s manual healing bindings, local-party remedy recommendations, dedicated Remedy click, alliance support, and safety controls. It corrects the reported Level Sync false-positive problem by preferring remote-party status effects from the server-backed party-status packet (`0x076`). If that packet has not yet arrived after loading or zoning, it falls back to Ashita’s normal party-memory record so genuine effects, such as Poison, remain visible. The fallback retains a single-member Slow report, such as Darthbeast’s genuine Slow, but suppresses a simultaneous multi-member Slow burst as transitional. Grouped and derived effects, including `stat_down`, require confirmation from the authoritative packet. Poison and the other direct supported fallback statuses remain available normally. It also adds an opt-in **XIUI-compatible party presentation**: a transparent, single-column party list with blue member headers, compact HP/MP bars, and amber Remedy controls.

> **Important:** The new visual presentation is intentionally a compatibility skin, not a replacement for XIUI’s installed source. To avoid duplicate party frames, use PartyCare’s XIUI-compatible panel *instead of* XIUI’s Party List while retaining XIUI’s other modules.

## Install

| Step | Action |
|---|---|
| 1 | Exit Final Fantasy XI and Ashita completely. |
| 2 | Back up your existing `Ashita/addons/partycare` folder by renaming it to `partycare-backup-1.2.3`. |
| 3 | Extract this release so its `partycare` folder is directly inside `Ashita/addons/`. Do not create a nested `partycare/partycare` folder. |
| 4 | Start the game and load the add-on with `/addon load partycare`. |
| 5 | Open PartyCare with `/pc`, or apply the matching layout preset directly with `/pc xiui`. |
| 6 | Open XIUI with `/xiui` and disable **Party List**. Leave your other XIUI modules enabled. |

The preset makes PartyCare single-column, applies a narrow transparent frame, enables the XIUI-compatible visual treatment, and preserves MP, remedy, and direct-click features. The panel remains movable unless you enable **Lock Panel Position** under `/pc`.

## Verification After a Level Sync Change

After a Level Sync increase or decrease, wait for the party display to refresh. Members with no removable debuff should show no `Remedy` line. A genuine displayed remedy reflects the latest received party-status packet; for example, an actual Slow status may correctly show `Remedy: Erase (slow)`. Test only with a willing party and click a Remedy control deliberately: every Remedy click still produces one manual spell request for the highest-priority configured status.

| Expected result | Meaning |
|---|---|
| No repeated `Remedy: Erase (slow)` labels after level-sync refresh | The false stale-memory classification is fixed. |
| `Remedy: Erase (slow)` on one genuinely affected member | Normal guarded-fallback or packet-confirmed remedy behavior. |
| `Status feed unavailable` immediately after loading or zoning | No packet or compatible party-memory record is available yet; wait briefly for the normal party refresh. A real Poison should appear as a Poisona recommendation once the card has data. |

## Controls and Safety

PartyCare direct-click bindings and Remedy clicks remain separate. The direct-click safety switch can be disabled immediately with `/partycare dispatch off`; re-enable it only with `/partycare dispatch on`. The XIUI-compatible layout can be toggled in **General → XIUI-Compatible Party Style**. Use `/partycare reset` if the panel appears off-screen.

## Rollback

Unload PartyCare with `/addon unload partycare`, remove the new `Ashita/addons/partycare` folder, and restore your backed-up folder name. Then re-enable XIUI’s Party List in `/xiui` if you previously disabled it. No XIUI files are changed by this package.

## References

[1]: https://github.com/tirem/XIUI "XIUI — Ashita v4 UI replacement"
[2]: https://github.com/AshitaXI/sdktest/blob/main/SDK/Memory/IParty.lua "Ashita IParty SDK test"

## Remedy Priority and Learned Spells

PartyCare now resolves remedy candidates in priority order **after** checking the local spellbook whenever Ashita exposes spell data. If a member has both Slow and Poison but the local player has not learned Erase, the Slow/Erase candidate is skipped and the next learned, enabled candidate—such as Poisona—becomes the displayed Remedy button. If the spellbook or resource data is temporarily unavailable, PartyCare preserves the enabled remedy rules you configured rather than guessing that a spell is missing.

| Situation | Expected Remedy result |
|---|---|
| Slow and Poison; Erase is unlearned; Poisona is learned | `Remedy: Poisona (poison)` |
| Slow and Poison; Erase and Poisona are learned | `Remedy: Erase (slow)` because Slow has higher configured priority |
| A remedy rule is disabled in the Remedies menu | The rule is skipped and the next enabled candidate is considered |

## Refresh Alert and Compact Debuff Display

Under `/pc` → **General**, enable **Pulse Names Missing Refresh** to make a member’s name box pulse when their maximum MP is **above** the configured threshold (150 by default), PartyCare has a usable status record for that member, and the Refresh icon is absent. The setting is intentionally opt-in and does not pulse for unknown status data, members at or below the threshold, or members already carrying Refresh.

Enable **Compact Debuff Alert Mode** to reduce the party panel to a small empty footprint until an enabled, actionable remedy is detected. When an alert exists, only that member’s name and one deliberate Remedy button appear. The name retains normal manual click behavior, and the Remedy button still sends one manual request for the current highest-priority available remedy. Alliance alerts appear when Alliance 2 and/or Alliance 3 are enabled in the same settings screen.

## True Hidden-Idle Compact Alerts

In Compact Debuff Alert Mode, PartyCare now creates **no visible window at all** while no enabled, learned remedy is actionable. Its last saved position is retained internally. When a party or enabled-alliance member receives a recognized debuff, PartyCare displays only that member’s name and the single Remedy action selected by the existing priority list. The affected name pulses red to draw attention.

Use `/pc` → **General** → **Show Compact Placement Preview** only when you need to move the alert location. The preview is intentionally blank and has no party names, settings button, health bars, MP bars, direct-click banner, or branding. Turn the preview back off after positioning; the alert then disappears entirely until PartyCare has a priority-selected remedy to show.

## Adaptive Spellbook, Refresh, and Status Filtering

PartyCare now accepts both boolean and numeric Ashita spellbook-readiness values before checking learned spells. This means an unlearned spell such as **Erase** is definitively excluded from remedy selection, allowing a lower-priority learned remedy such as **Poisona** to remain available. The missing-Refresh threshold now uses a member’s actual current MP from the party data source, rather than an unusable percentage-backed maximum, and the qualifying member name pulses yellow visibly.

Generic stat-down icons, including Evasion Down, are intentionally not auto-routed to the broad `stat_down` Erase rule. That grouping is ambiguous and can be transitional during Level Sync. PartyCare still reports the individually mapped and verified removable effects; it will not create a misleading generic `Remedy: Erase (stat_down)` prompt.
