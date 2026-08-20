# PartyCare Remedy Status Troubleshooting

## Expected Local-Party Behavior

PartyCare reads the local player from Ashita's player-status sources and associates the five local-party status records with other cards by server ID. A local-party card should show a button such as **`Remedy: Poisona (poison)`** or **`Remedy: Erase (bio)`** whenever an enabled matching rule is active.

| Card text | Meaning | Next action |
|---|---|---|
| `Remedy: <spell> (<effect>)` | PartyCare detected an enabled, supported removable effect. | Click the card-level Remedy button once. |
| `Status icons detected — no enabled Remedy rule` | Ashita provided active status IDs, but none map to an enabled PartyCare rule. | Open **Remedies** and verify the matching rule remains enabled; report the specific status effect if it is absent. |
| `Status feed unavailable` | The runtime did not expose a usable local status source for that card. Current builds decode Ashita’s native userdata-backed indexed status arrays, so this message now indicates that no player-status source was returned at all. | Reload the current PartyCare build; if it persists, capture this card text and the active status name for diagnosis. |

The current supported local status catalog includes Poison, Paralyze, Blind, Silence, Petrify, Disease, Curse, Doom, Plague, Bind, Gravity/Weight, Slow, Bio, Dia, Addle, Flash, Stun, Elegy, Requiem, Helix, six elemental damage-over-time effects, and common stat-down effects. Erase handles one detrimental magic effect at a time, so the panel intentionally exposes one highest-priority remedy per click.

## Focused Retest

After replacing the addon files, reload PartyCare and use a local-party character. Test one effect at a time. For Poison, expect **`Remedy: Poisona (poison)`**. For Bio or Dia, expect **`Remedy: Erase (bio)`** or **`Remedy: Erase (dia)`**. For Burn, Frost, Choke, Rasp, Shock, or Drown, expect **`Remedy: Erase (elemental_dot)`**.

If the status line shows `Status icons detected — no enabled Remedy rule`, retain a screenshot that includes the card and the active status icon. If it shows `Status feed unavailable`, retain the same screenshot and the output of `/partycare status`.

## Scope

Status-derived Remedy controls remain limited to local-party cards. Alliance 2 and Alliance 3 cards continue to support direct manual healing but do not infer status effects because Ashita documents status records for the local-party view only.

## References

[1]: https://github.com/AshitaXI/sdktest/blob/main/SDK/Memory/IParty.lua "Ashita IParty SDK Test"
[2]: https://horizonffxi.wiki/Erase "HorizonXI Erase"
[3]: https://horizonffxi.wiki/Elemental_Debuff "HorizonXI Elemental Debuff"
