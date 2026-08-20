# PartyCare Architecture

## Design Goal

PartyCare separates three concerns that are frequently conflated in party-helper addons: **party data**, **triage presentation**, and **player choice**. Only the first two exist in this package. Player choice is represented as a local intent record, not an external game operation.

```text
party snapshot → normalize → severity/decorate → ImGui panel
                                                   ↓
                              explicit member click + action click
                                                   ↓
                                  MANUAL_HEAL_ACTION audit record
```

## Module Contracts

| Module | Input | Output | Forbidden responsibility |
|---|---|---|---|
| `config.lua` | Literal user configuration | Normalized presentation/action configuration | Host APIs or action execution |
| `party.lua` | Raw party-like records | Clamped, unique, decorated member records | Rendering or game access |
| `intents.lua` | Explicit selected member/action/time | Immutable-like local intent data | Targeting, commands, casts, packets |
| `panel_model.lua` | Config, party records, selection/action calls | View model and audit records | ImGui or Ashita globals |
| `ashita_shell.lua` | Panel model and ImGui | Rendered panel plus local audit data | Client control or action dispatch |
| `partycare.lua` | Ashita UI lifecycle | Demo-mode shell | Live-party extraction or healing automation |

## Invariants

The configuration parser rejects unsupported keys. Resource values are finite and clamped to their respective maxima. Each visible member must have a unique identity. Selection is cleared when its member leaves the latest model. An action request fails unless its action is enabled and a member was explicitly selected.

The only action-shaped output has the form below:

```lua
{
  kind = 'MANUAL_HEAL_ACTION',
  sequence = 1,
  at = 12.5,
  action_key = 'primary',
  member_id = 2,
  member_name = 'Willow',
}
```

No module consumes this data to affect an external client. The top-level entrypoint only reports it as a confirmation message.

## Provider Boundary

A future data provider, if developed under appropriate permissions, should supply only a plain array to `PanelModel:update_members`:

```lua
{
  {id = 1, name = 'Member', hp = 500, hp_max = 900, mp = 100, mp_max = 200, status = ''},
}
```

It must not be allowed to issue actions through PartyCare, and it must be independently tested against synthetic fixtures before it is ever connected to a visual shell. This package intentionally includes no provider implementation.
