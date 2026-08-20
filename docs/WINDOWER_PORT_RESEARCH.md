# Windower Port Research

PartyCare’s shared model, configuration, remedy rules, resource styling, and layout logic can be reused across Ashita and Windower. The platform boundary must be replaced because Windower exposes its own party snapshots, event registration, UI primitives, and command entry points.

## Verified integration points

| Concern | Windower pattern | PartyCare port decision |
|---|---|---|
| Addon metadata | `_addon` table | Use a `partycare.lua` entrypoint with Windower metadata and a `partycare` command alias. |
| User command handling | `windower.register_event('addon command', ...)` | Support `//partycare` and `//pc` for settings and dispatcher controls. |
| Party data | `windower.ffxi.get_party()` | Normalize local and alliance party data into the existing PartyCare member contract. |
| Explicit command issue | `windower.send_command('input ' .. command)` | Keep one-request/one-dispatch behavior inside a guarded Windower adapter. |
| UI approach | Windower primitives and text/image objects | Use a dedicated Windower renderer rather than importing Ashita ImGui calls. |

The maintained XivParty addon demonstrates that Windower can render party and alliance lists, supports optional alliance display, and provides party-status presentation patterns. PartyCare will retain its own compact transparent-grid visual language and will not copy XivParty code or assets.

## Scope boundary

The port will preserve PartyCare's explicit direct-click model. There will be no health-triggered action, automatic target selection, retry loop, timer, or unattended behavior. All shared intent validation remains platform-independent.

## References

[1]: https://docs.windower.net/addons/ "Windower Addons Documentation"
[2]: https://github.com/Windower/Lua/blob/master/addons/send/send.lua "Windower Send Addon Source"
[3]: https://github.com/Tylas11/XivParty "XivParty Windower Addon"
