# PartyCare

> **By: Schmeee**

![PartyCare interface preview](assets/partycare-preview.png)

PartyCare is a compact Ashita party-healing panel for HorizonXI. It displays party members as transparent grid cards with HP/MP bars, recognized status effects, configurable direct-click bindings, and per-member remedy controls.

## Install

Copy the `partycare` folder into Ashita's `addons` directory, then load it with:

```text
/addon load partycare
```

Open the configuration panel with either:

```text
/partycare
```

or the short alias:

```text
/pc
```

## Settings

The compact Settings window has four tabs.

| Tab | Purpose |
|---|---|
| **General** | Position, transparent grid columns/card size, adaptive text scaling, Alliance 2/3 visibility, display options, a safe Full Alliance layout preview, and health thresholds. |
| **Direct Click** | Left, right, and middle party-frame bindings. |
| **Spells** | Manual action-bar bindings for Cure, Regen, emergency healing, and optional Refresh. |
| **Remedies** | Spell, enable state, and priority for each removable status. |

Use **Save** to persist changes, **Save & Close** to persist and close, or **Close** to dismiss the window.

## Alliance Grid

PartyCare always displays your local party. In **General**, enable **Show Alliance 2** and/or **Show Alliance 3** to add those parties when they contain active members. Empty or disabled alliance parties add no blank cards or empty sections.

Direct clicks retain each member’s actual alliance slot. Local party members use party targets; Alliance 2 and Alliance 3 members use the corresponding in-game alliance target ranges.[1]

Alliance member HP/MP data is available through Ashita’s party interface. PartyCare intentionally does not infer removable status effects for Alliance 2/3 because Ashita’s documented status-icon records are limited to the local-party view.[2]

## Grid Cards and Remedies

Each party member appears as a compact card with name, unclipped HP/MP percentage bars, and a card-level **Remedy** button when PartyCare recognizes an enabled removable status. The Remedy button receives a subtle amber pulse but remains independent of direct clicks: one explicit Remedy click resolves only the highest-priority recognized status for that member. **Minimal Live Frame** is on by default, leaving only the transparent party cards during play; use `/partycare` or `/pc` whenever you want to open Settings. The Settings window includes a top-right **X** as well as its labeled Close controls. **Adaptive Card Scaling** adjusts card and text scale as you resize the panel, and **Full Alliance Layout Preview** displays eighteen inert cards so you can position the grid before a live alliance. See [UI_GUIDE.md](UI_GUIDE.md) for the complete card-layout reference.

## Direct Clicks

When Direct Click Mode is enabled, clicking an active party frame uses that mouse button’s configured spell. The default left-click binding is Cure IV; edit any spell name or button binding in **Direct Click**.

Direct Click Mode can be turned off at any time. With it off, party-frame clicks only select a member.

## Refresh

The **Spells** tab includes an optional Refresh binding for Red Mage play. Enable it to show Refresh in the manual action bar, then select a party member and click the action.

## Remedies

PartyCare associates local-party status records with member cards by server ID and reads the local player’s documented status sources separately. Its decoder explicitly supports Ashita’s native indexed status arrays, including userdata-backed arrays exposed by the HorizonXI runtime. This corrects both the prior member-record mismatch and the plain-table-only decoding issue that could hide effects such as Poison, Bio/Dia, or Frost. When a rule matches, the affected card shows a clear label such as **`Remedy: Erase (bio)`**.

Each Remedy click resolves **one** highest-priority enabled effect. It does not attempt to chain casts. If several statuses are active, the next explicit click reevaluates the current status list after the prior spell resolves.

| Priority tier | Covered statuses | Default response |
|---:|---|---|
| 93–100 | Paralyze, Doom, Petrify, Curse, Plague, Disease | Paralyna, Cursna, Stona, Cursna, Viruna, Viruna |
| 70–90 | Gravity/Weight, Bind, Slow, Silence, Blind | Erase, Erase, Erase, Silena, Blindna |
| 38–50 | Poison, Bio, Dia, Addle, Flash, Stun, Elegy, Requiem, Helix | Poisona or Erase |
| 10 | Burn, Frost, Choke, Rasp, Shock, Drown | Erase |
| 5 | Common attribute, combat-stat, maximum-resource, and magic-stat down effects | Erase |

The full behavior remains configurable in the **Remedies** tab. PartyCare only shows status-derived Remedy controls for the local party because Ashita documents local-party status records only; Alliance 2/3 cards remain direct-healing cards.[2] Erase removes one detrimental magical effect, so the UI intentionally recommends one highest-priority Erase target at a time.[3]

## Commands

| Command | Purpose |
|---|---|
| `/partycare` or `/pc` | Open the Settings window. |
| `/partycare show` / `hide` | Show or hide the panel. |
| `/partycare toggle` | Toggle panel visibility. |
| `/partycare config` | Open the Settings window. |
| `/partycare reset` | Reset panel and Settings-window positions. |
| `/partycare save` | Save current settings. |
| `/partycare dispatch off` | Immediately disable PartyCare actions. |
| `/partycare dispatch on` | Re-enable PartyCare actions. |
| `/partycare status` | Print panel and action status. |

## References

[1]: https://horizonffxi.wiki/Macro "HorizonXI Macro Target Placeholders"
[2]: https://github.com/AshitaXI/sdktest/blob/main/SDK/Memory/IParty.lua "Ashita IParty SDK Test"
[3]: https://horizonffxi.wiki/Erase "HorizonXI Erase"
