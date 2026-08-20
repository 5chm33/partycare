# PartyCare Grid Interface

PartyCare now uses a compact transparent party grid inspired by traditional healer-frame layouts. Each active party member has one card, arranged in one, two, or three configurable columns. **Minimal Live Frame** is enabled by default, so only the party cards remain visible during play; use `/partycare` or `/pc` to open the Settings window.

## Member Cards

Every card presents the information needed for a manual healing decision without opening another panel.

| Element | Meaning |
|---|---|
| **Name header** | The party member’s name and current status text. One configured direct input acts on this frame. |
| **HP bar** | A fully readable compact percentage. HP is green above the warning threshold, yellow between warning and critical, and red at critical levels. |
| **MP bar** | A fully readable compact percentage; hide it from the General tab when it is not needed. MP is blue at high values, shifts through teal/yellow as it falls, and becomes red when critical. |
| **Remedy button** | Appears only for a member with a recognized, enabled removable status. A light amber pulse draws attention to it; it names the spell currently selected by the priority rules. |

The card-level **Remedy** button is separate from direct healing clicks. It does not run when you left-click a party frame. One deliberate Remedy click applies one configured remedy to that card’s member, using the highest-priority recognized active status.

Alliance 2 and Alliance 3 cards support the same direct healing bindings as local-party cards. Their HP/MP cards appear when enabled, but the Remedy button remains local-party-only because the documented Ashita status-icon interface does not expose equivalent per-member alliance status records.

> If a member has Paralyze, Slow, and Blind simultaneously, the card initially displays `Remedy: Paralyna`. After Paralyze is cleared, the next deliberate Remedy click can select Erase for Slow.

## Visual Controls

Open `/partycare config` and use the **General** tab to customize the grid.

| Setting | Effect |
|---|---|
| **Grid Columns** | One, two, or three cards per row. |
| **Card Width** | Width of each party frame. |
| **Card Height** | Space reserved for each party frame. |
| **Adaptive Card Scaling** | Updates card width, height, and text scale as you resize the panel. Resource labels consistently use the clear compact `HP 72%` / `MP 48%` format so they never clip. Turn it off to use a manual Text Scale. |
| **Minimal Live Frame** | Hides PartyCare’s in-panel title and Settings control during play. |
| **Transparency** | Panel background opacity, from subtle to nearly opaque. |
| **Show MP Bar** | Shows or hides MP within every card. |
| **Show Status Text** | Shows or hides the status label in the card header. |
| **Show Remedy Button** | Shows or hides the card-level remedy control. |
| **Show Alliance 2 / 3** | Adds that alliance party as a labeled grid section only when enabled and active members are present. |
| **Full Alliance Layout Preview** | Shows all eighteen display-only preview cards so you can arrange card size, column count, and position before a live alliance. Preview cards cannot select targets or create casts. |

## Direct Bindings

Direct card inputs are the primary healing interaction. Configure left, right, middle, Mouse 4, Mouse 5, Wheel Up, and Wheel Down spell bindings in the **Direct Click** tab. Mouse 4 and Mouse 5 require a mouse that exposes those buttons to Ashita; wheel bindings require the cursor to remain over the intended card. Each recognized input creates at most one manual cast request, and all optional extended bindings start disabled.
