# PartyCare

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
| **General** | Position, transparent grid columns/card size, adaptive text scaling, display options, and health thresholds. |
| **Direct Click** | Left, right, and middle party-frame bindings. |
| **Spells** | Manual action-bar bindings for Cure, Regen, emergency healing, and optional Refresh. |
| **Remedies** | Spell, enable state, and priority for each removable status. |

Use **Save** to persist changes, **Save & Close** to persist and close, or **Close** to dismiss the window.

## Grid Cards and Remedies

Each party member appears as a compact card with name, HP, optional MP, and a card-level **Remedy** button when PartyCare recognizes an enabled removable status. The Remedy button is independent of direct clicks: one explicit Remedy click resolves only the highest-priority recognized status for that member. **Minimal Live Frame** is on by default, leaving only the transparent party cards during play; use `/partycare` or `/pc` whenever you want to open Settings. **Adaptive Card Scaling** adjusts card and text scale as you resize the panel. See [UI_GUIDE.md](UI_GUIDE.md) for the complete card-layout reference.

## Direct Clicks

When Direct Click Mode is enabled, clicking an active party frame uses that mouse button’s configured spell. The default left-click binding is Cure IV; edit any spell name or button binding in **Direct Click**.

Direct Click Mode can be turned off at any time. With it off, party-frame clicks only select a member.

## Refresh

The **Spells** tab includes an optional Refresh binding for Red Mage play. Enable it to show Refresh in the manual action bar, then select a party member and click the action.

## Remedies

PartyCare reads recognized party status icons and maps them into configurable remedy rules. Select a member with a recognized status, then click **Remedy**. PartyCare evaluates all recognized active rules and uses the single highest-priority enabled remedy.

The default priority order is:

| Priority | Status | Default spell |
|---:|---|---|
| 100 | Paralyze | Paralyna |
| 90 | Gravity | Erase |
| 85 | Slow | Erase |
| 70 | Silence | Silena |
| 60 | Blind | Blindna |
| 50 | Poison | Poisona |
| 45 | Bio / Dia | Erase |

If several recognized statuses are active, one Remedy click resolves only the top-priority rule. Reconfigure the order or disable individual rules in the **Remedies** tab.

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
