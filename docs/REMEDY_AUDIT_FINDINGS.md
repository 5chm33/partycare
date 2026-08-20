# PartyCare Remedy Audit Findings

## Root Cause: Incorrect Status Record Association

The prior provider assumed that `GetStatusIcons(slot)` used the same index as the local-party member slot. Ashita exposes five separate local-party status records, each with its own server ID, target index, bit mask, and 32 icon values. The status record must therefore be associated with a displayed local member by **server ID**, not by a coincident slot number. This mismatch can make status effects such as Poison and Bio/Dia fail to appear on the correct card.

The Ashita SDK documents `GetStatusIconsServerId(index)`, `GetStatusIconsBitMask(index)`, and `GetStatusIcons(index)` for indices 0–4, while party member metadata is available for all 18 party/alliance slots.[1]

## Verified Effects and Remedy Categories

| Category | Status IDs | Configured response |
|---|---|---|
| Dedicated `-na` effects | Poison 3, Paralysis 4, Blindness 5, Silence 6, Petrification 7, Disease 8, Curse 9, Doom 15, Plague 31 | Poisona, Paralyna, Blindna, Silena, Stona, Viruna, Cursna, Cursna, Viruna |
| Erase effects | Bind 11, Weight/Gravity 12, Slow 13, Addle 21, Stun 10, Flash 156, Bio 135, Dia 134 | Erase |
| Elemental damage-over-time effects | Burn 128, Frost 129, Choke 130, Rasp 131, Shock 132, Drown 133 | Erase at the lowest configured priority tier |
| Common stat-down effects | STR/DEX/VIT/AGI/INT/MND/CHR down 136–142, max HP/MP down 144–145, accuracy/attack/evasion/defense down 146–149, magic-defense down 167, magic-accuracy down 174, magic-attack down 175, max TP down 189 | Erase |
| Song / damage-over-time effects | Requiem 192, Elegy 194, Helix 186 | Erase |

Erase removes one detrimental magic effect; it does not resolve every removable status in one cast. PartyCare will continue to create one explicit Remedy request for the single highest-priority matched rule.[2] The HorizonXI elemental-debuff documentation confirms that Burn, Frost, Choke, Rasp, Shock, and Drown are removed by Erase.[3]

## User-Visible Behavior After Correction

A local-party card will show `Remedy: <spell>` whenever an enabled configured rule matches a server-ID-associated status record. If several effects are active, the card shows the top priority. The user performs a separate deliberate Remedy click per effect, so the next recommendation updates after the prior effect clears.

## References

[1]: https://github.com/AshitaXI/sdktest/blob/main/SDK/Memory/IParty.lua "Ashita SDK IParty Test"
[2]: https://horizonffxi.wiki/Erase "HorizonXI Erase"
[3]: https://horizonffxi.wiki/Elemental_Debuff "HorizonXI Elemental Debuff"
