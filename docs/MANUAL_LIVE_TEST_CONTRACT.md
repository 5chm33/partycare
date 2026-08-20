# PartyCare Manual Live-Test Contract

## Allowed Trigger

The test edition may issue a spell command only from the immediate callback of an explicit PartyCare action-button click. No other module may call the dispatch adapter.

## Required Preconditions

| Condition | Required value |
|---|---|
| Live-test toggle | `live_test.manual_dispatch_enabled = true` |
| Emergency stop | `live_test.emergency_stop = false` |
| Intent kind | `MANUAL_CLICK_CAST_REQUEST` |
| Selected party member | Present in the current displayed party snapshot |
| Party slot | Integer 0–5 supplied by that snapshot |
| Spell | Non-empty validated binding string |

## Command Shape

The adapter builds exactly one command using the selected member’s **existing party slot**:

```text
/ma "<configured spell>" <p<slot>>
```

The adapter calls the documented Ashita chat-manager method `QueueCommand(1, command)` exactly once for an accepted click. It does not issue a target command before or after it. It does not use packets, input injection, target loops, timers, queues, recasts, automatic retries, health thresholds, or event listeners to generate casts.

## Emergency Controls

`/partycare dispatch off` sets the emergency stop immediately and blocks all future commands. `/partycare dispatch on` requires a separate explicit typed player command and only enables manual dispatch for the current session. Both actions are audit logged.

## Live Debuff Limitation

The remedy recommender consumes only debuff records present in the displayed party snapshot. It does not infer statuses. A live provider must be separately validated to supply those records before the Remedy button is treated as a live enfeeble-clearing control.
