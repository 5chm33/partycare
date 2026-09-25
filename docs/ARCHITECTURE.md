# PartyCare Architecture

## Design Goal

PartyCare separates three concerns that are frequently conflated in party-helper addons: **party data**, **triage presentation**, and **player choice**. Player choice is represented as a local intent record. The shipped Ashita adapter may consume that intent and queue one external client command, but only behind explicit manual-dispatch and emergency-stop gates.

```text
party snapshot → normalize → severity/decorate → ImGui panel
                                                   ↓
                              explicit member click + action click
                                                   ↓
                                  MANUAL_CLICK_CAST_REQUEST
                                                   ↓
                         gated Ashita /ma command (manual only)
```

## Module Contracts

| Module | Input | Output | Forbidden responsibility |
|---|---|---|---|
| `config.lua` | Literal user configuration | Normalized presentation/action configuration | Host APIs or action execution |
| `party.lua` | Raw party-like records | Clamped, unique, decorated member records | Rendering or game access |
| `intents.lua` | Explicit selected member/action/time | Immutable-like local intent data | Targeting, commands, casts, packets |
| `panel_model.lua` | Config, party records, selection/action calls | View model and audit records | ImGui or Ashita globals |
| `ashita_shell.lua` | Panel model and ImGui | Rendered panel plus local audit data | Ashita command dispatch |
| `manual_dispatch_adapter.lua` | Validated manual intent and live-test flags | One queued Ashita `/ma` command plus audit record | Autonomous loops, arbitrary commands, or packets |
| `partycare.lua` | Ashita UI lifecycle and provider | Live-party panel and explicit dispatch handoff | Autonomous healing automation |

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

The top-level entrypoint hands `MANUAL_CLICK_CAST_REQUEST` records to `manual_dispatch_adapter.lua`. When `manual_dispatch_enabled == true`, `emergency_stop == false`, and a chat manager is available, the adapter queues exactly one `/ma "Spell" <target>` command via Ashita `QueueCommand(1, command)`. Disabled, stopped, malformed, or unavailable-host requests are rejected without queueing. There is no scheduler, chain-cast loop, or arbitrary command execution.

## Provider Boundary

The Ashita provider supplies a normalized plain array to `PanelModel:update_members`:

```lua
{
  {id = 1, name = 'Member', hp = 500, hp_max = 900, mp = 100, mp_max = 200, status = ''},
}
```

The provider does not issue actions; only explicit UI intents reach the dispatch adapter. Provider compatibility should be tested against synthetic fixtures before connection to a visual shell. The live provider is implemented in `src/ashita_party_provider.lua`; Ashita remains a runtime dependency.
