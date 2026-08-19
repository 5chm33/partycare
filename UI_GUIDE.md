# PartyCare Grid Interface

PartyCare now uses a compact transparent party grid inspired by traditional healer-frame layouts. Each active party member has one card, arranged in one, two, or three configurable columns. **Minimal Live Frame** is enabled by default, so only the party cards remain visible during play; use `/partycare` or `/pc` to open the Settings window.

## Member Cards

Every card presents the information needed for a manual healing decision without opening another panel.

| Element | Meaning |
|---|---|
| **Name header** | The party member’s name and current status text. A direct-click binding acts on this frame. |
| **HP bar** | Current and maximum HP with percentage. HP is green above the warning threshold, yellow between warning and critical, and red at critical levels. |
| **MP bar** | Current and maximum MP; hide it from the General tab when it is not needed. MP is blue at high values, shifts through teal/yellow as it falls, and becomes red when critical. |
| **Remedy button** | Appears only for a member with a recognized, enabled removable status. It names the spell currently selected by the priority rules. |

The card-level **Remedy** button is separate from direct healing clicks. It does not run when you left-click a party frame. One deliberate Remedy click applies one configured remedy to that card’s member, using the highest-priority recognized active status.

> If a member has Paralyze, Slow, and Blind simultaneously, the card initially displays `Remedy: Paralyna`. After Paralyze is cleared, the next deliberate Remedy click can select Erase for Slow.

## Visual Controls

Open `/partycare config` and use the **General** tab to customize the grid.

| Setting | Effect |
|---|---|
| **Grid Columns** | One, two, or three cards per row. |
| **Card Width** | Width of each party frame. |
| **Card Height** | Space reserved for each party frame. |
| **Adaptive Card Scaling** | Updates card width, height, and text scale as you resize the panel. At small scales, bar labels collapse to a clear `HP 72%` / `MP 48%` format rather than clipping. Turn it off to use a manual Text Scale. |
| **Minimal Live Frame** | Hides PartyCare’s in-panel title and Settings control during play. |
| **Transparency** | Panel background opacity, from subtle to nearly opaque. |
| **Show MP Bar** | Shows or hides MP within every card. |
| **Show Status Text** | Shows or hides the status label in the card header. |
| **Show Remedy Button** | Shows or hides the card-level remedy control. |
| **Show Legacy Spell Bar** | Restores the old Cure/Regen/Refresh action row beneath the grid. It is off by default. |

## Direct Clicks and Spell Bar

Direct frame clicks are the primary healing interaction. Configure left, right, and middle-click spell bindings in the **Direct Click** tab.

The legacy spell bar remains available as an optional accessibility preference. Enable it in **General**, then adjust Cure, Regen, emergency healing, and Refresh in the **Spells** tab.
