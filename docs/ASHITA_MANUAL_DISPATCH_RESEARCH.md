# Ashita Manual Dispatch Research — 2026-08-19

## Sources Examined

| Source | Verified finding |
|---|---|
| AshitaCore documentation | `AshitaCore` exposes party information through its party/memory interfaces and a chat manager containing `QueueCommand`. |
| Ashita SDK test addon (`SDK/IChatManager.lua`) | Demonstrates the Lua call shape `mgr:QueueCommand(1, '/echo sdktest:queuecommand');`. |
| Ashita SDK test addon (`SDK/Memory/IParty.lua`) | Exercises `mgr:GetParty()` and party member methods such as `GetMemberIndex`, `GetMemberNumber`, and `GetMemberName`. |
| XIUI source | Uses `AshitaCore:GetMemoryManager():GetParty()` and `party:GetMemberIsActive(i)` in maintained Ashita v4 UI code. |

## Proposed Manual Test Contract

The live test edition may build one command only inside the immediate handler for one explicit PartyCare action-button click. It must use the selected member’s currently displayed party-slot value. It must not create commands from party HP/debuff updates, hover events, timers, queues, repeated logic, or background callbacks.

## Remaining Runtime Verification

Before a live session, validate the exact party-member HP/MP method names and slot-to-target notation on the approved HorizonXI build. The command dispatch adapter should fail closed unless it has a valid explicitly selected party slot, a non-empty spell name, and manual dispatch is enabled in settings.

## References

[1]: https://wiki.ashitaxi.com/oldwiki/doku.php?id=addons:using_ashitacore "AshitaCore Documentation"
[2]: https://github.com/AshitaXI/sdktest/blob/main/SDK/IChatManager.lua "Ashita SDK IChatManager Test"
[3]: https://github.com/AshitaXI/sdktest/blob/main/SDK/Memory/IParty.lua "Ashita SDK IParty Test"
[4]: https://github.com/tirem/XIUI "XIUI Ashita v4 Source"
