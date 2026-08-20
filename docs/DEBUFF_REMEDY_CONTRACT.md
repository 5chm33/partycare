# PartyCare Debuff-Remedy Contract

## Manual Interaction Boundary

PartyCare may **recommend** one remedy from the currently displayed status data. Hovering a party frame is informational only. A remedy request is created only when the player deliberately clicks the single **Remedy** button after selecting a party member.

No recommendation causes a cast, queue, timer, target selection, or other game action. The output is a local typed request record pending the separately approved integration specification.

## Default Priority Model

The configured rules evaluate every displayed removable debuff and select exactly one deterministic recommendation.

| Priority tier | Default status examples | Default remedy |
|---|---|---|
| 100 | Paralyze | Paralyna |
| 90 | Gravity | Erase |
| 85 | Slow | Erase |
| 70 | Silence | Silena |
| 60 | Blind | Blindna |
| 50 | Poison | Poisona |
| 45 | Bio or Dia | Erase |
| 40 | Other enabled mapped rules | Their configured remedy |

When two rules share a priority, PartyCare breaks the tie alphabetically by rule identifier. The decision is therefore deterministic and testable. Rules can be disabled or their spell/priority values changed in the settings file and in the configuration window.

## Data Contract

A party member can expose a `debuffs` list:

```lua
{ 'Paralyze', 'Slow', 'Blind' }
```

For compatibility, a legacy single `status` string is treated as a one-item debuff list. The panel reports the recommendation but does not infer unprovided status data.

## Request Contract

A manual remedy click produces one `MANUAL_CLICK_CAST_REQUEST` with `action_key = 'remedy'`, the selected member, one configured spell name, the matching rule identifier, a timestamp, and a sequence number. It has no execution path in this package.
