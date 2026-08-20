# PartyCare Direct-Click Contract

## Manual Interaction Model

A direct-click binding is a user-configured association between one mouse button and one configured spell. A dispatch may occur only from the immediate PartyCare frame-click handler after the player deliberately clicks an active, visible party-member frame.

| Input | Default behavior | Configurable action |
|---|---|---|
| Left click | Select member | Optional direct spell binding |
| Right click | No action | Optional direct spell binding |
| Middle click | No action | Optional direct spell binding |

## Required Dispatch Preconditions

Direct-click dispatch requires all of the following conditions: direct-click mode is enabled, manual dispatch is armed, the emergency stop is off, the clicked member has a valid displayed party slot, the bound spell is enabled and non-empty, and the event is an actual click rather than hover/focus/layout interaction.

## Explicitly Excluded Behavior

PartyCare must not cast on hover, member updates, health thresholds, debuff updates, timers, queued sequences, retries, recurring checks, target changes, or any background event. Each click produces at most one spell request and one audit record.

## Visual Safety Cues

The main window must show `DIRECT CLICK: ARMED` or `DIRECT CLICK: DISARMED` at all times when direct-click bindings exist. A separate Settings control toggles direct-click mode, while `/partycare dispatch off` activates the emergency stop and blocks both action buttons and direct-click requests.

## Recommended Test Defaults

The feature is disabled by default. The initial left-click binding is `Cure IV`; right and middle click are unbound. Users must intentionally enable direct-click mode and separately arm dispatch during a supervised test.
