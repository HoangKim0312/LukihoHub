# LukihoHub

External automation console injected into Roblox games via executor
loadstring. Each supported game lives in `games/<slug>/LukihoHub.client.lua`
and is gated by `game.GameId`.

## Project layout

| Path | Role |
| --- | --- |
| `loader.lua` | Public entry. Maps `game.GameId` → script path, fetches via `HttpGet`, then `loadstring`. |
| `games/aa/init.lua` | Shared bootstrap: remote catalog, fire/invoke helpers, lobby / stage detection, JSON helpers. |
| `games/aa/data.lua` | Static catalogs (MAPS, PORTALS, DIFFICULTIES, KNOWN_CODES, …) derived from the `.rbxlx` dump. |
| `games/aa/lobby.lua` | Auto Join Map / Challenge / Portal / Player + Auto Start. |
| `games/aa/shop.lua` | Delete Portal, Auto Open Capsules, Auto Sell Skins. |
| `games/aa/ingame.lua` | Auto Sell / Upgrade / Leave on wave, Auto Place, macro record/play. |
| `games/aa/eventcard.lua` | Event card (roguelike modifier) picker — auto pick with priority + debuff filter. |
| `games/aa/macro_storage.lua` | Macro save/load/import/export via executor `writefile`/`readfile`. |
| `games/aa/misc.lua` | Discord webhook, Hide UI/Map/Name, Fake Outfit, Auto Reconnect, Auto Claim Quests, Redeem Codes, FPS cap. |
| `games/aa/LukihoHub.client.lua` | MacLib UI: 8 tabs (Home, Lobby, Shop, In-Game, Event Card, Macro, Misc, Settings) wired to the modules above. |

## Adding a new game

1. Drop a new folder under `games/<slug>/LukihoHub.client.lua`.
2. Guard the file with `if game.GameId ~= TARGET_GAME_ID then return end`.
3. Add the mapping to `SCRIPTS_BY_GAME` in `loader.lua`.

## Anime Adventures specifics

| Concern | Approach |
| --- | --- |
| Combat | `VirtualInputManager` M1 taps + Z/X/C/V/B taps (the local handler reads `UserInputService`). |
| Economy remotes | Direct `InvokeServer` on `spawn_unit`, `upgrade_unit_ingame`, `sell_unit_ingame`, `change_priority`, `use_ingame_spell`. |
| Detection | `CollectionService` tags `Enemy` / `Boss` / `EventBoss`, with `workspace.Enemies` and `workspace.Bosses` fallbacks, with `GetPartBoundsInRadius` last resort. |
| ESP | Not implemented for this game. |

## Macro recorder

The recorder only tracks actions that mutate units on the field. Camera and
character movement are intentionally ignored.

### Actions captured

| Type | Required data | Source remote |
| --- | --- | --- |
| `place` | `unitName`, `x`, `y`, `z` | `MacroRemotes.PlaceUnit` |
| `upgrade` | `unitName` | `MacroRemotes.UpgradeUnit` |
| `sell` | `unitName` | `MacroRemotes.SellUnit` |
| `priority` | `unitName` | `MacroRemotes.SetTargetPriority` |
| `ability` | `unitName` | `MacroRemotes.UseAbility` |

All actions carry an absolute `time` value (seconds since `StartRecording`) so
playback can respect original pacing.

### Flow

1. Player opens the **Macros** tab in the UI and types a macro name.
2. Press **Record Macro**. The client hooks fire and forward every relevant
   action to the server.
3. Player plays the stage normally.
4. When the stage reaches `Completed`/`Victory`/`Failed`, `MacroServer`
   persists the captured actions under DataStore key `macros_<UserId>` and
   fires `MacroRecordEvent` back to the client, which switches the status to
   *"Saved macro '...' (N actions)"*.
5. Later, the player selects the macro and presses **Play Selected Macro**.
   The client calls `MacroPlay` action-by-action with the original delays.

### Wiring into your own placement code

The recorder exposes:

```lua
MacroRecorder.Place(unitName, x, y, z)
MacroRecorder.Upgrade(unitName)
MacroRecorder.Sell(unitName)
MacroRecorder.SetPriority(unitName, priority)
MacroRecorder.UseAbility(unitName)
```

Call these from the place where your game handles the real placement/upgrade/
sell. The functions both notify the server (so the macro can be saved) and
store the action in the in-memory buffer.

If your game already fires its own remotes on placement, you can also wrap
those existing remotes on the client side to mirror the calls into
`MacroRecorder`.

### Server-side apply

`MacroServer.server.lua` validates the unit name against
`ReplicatedStorage.Units` and the coordinate bounds, then calls
`applyActionToGame`. The default implementation only logs; replace it with
calls into your existing server handlers (cost check, cooldown, spawn, etc.).
The DataStore key is per player so the macro library travels with the account.

### Stage detection

`StageManager.lua` tries to `require` a module named `StageManager`, `Stages`,
or `WaveManager` from `ServerScriptService`. If one of them exposes
`GetState()` returning `"Playing"`/`"Completed"`/etc., that is used. Otherwise
it falls back to a `StringValue`/`IntValue` pair under `workspace.Stage`
(`State` and `CurrentStage`). Set these values from your own stage code when
the game does not have a dedicated module.

## Install with Rojo

1. Run `rojo serve` in this directory.
2. Connect the Rojo Studio plugin.
3. Place tower unit definitions under `ReplicatedStorage.Units`. Each unit
   folder should contain the unit data and a `Config` subfolder with a
   `Price`/`Cost` `NumberValue` used by the macro cost estimator.
4. Place NPC enemy models under `workspace.Enemies` and boss models under
   `workspace.Bosses`. The registry tags them with `Enemy`/`Boss`.

## Install without Rojo

- `MacroServer.server.lua` -> `ServerScriptService` as Script
- `StageManager.lua` -> `ServerScriptService` as ModuleScript
- `Remotes.lua` -> `ReplicatedStorage` as ModuleScript
- `FarmGui.client.lua` -> `StarterPlayer > StarterPlayerScripts` as LocalScript
- `MacroRecorder.lua` -> `StarterPlayer > StarterPlayerScripts` as ModuleScript
- `InputBridge.client.lua` -> `StarterPlayer > StarterPlayerScripts` as LocalScript (only if you want automatic capture from the existing hotbar/click inputs)
- `Fly.client.lua` -> `StarterPlayer > StarterPlayerScripts` as LocalScript (developer fly toggle)
- `FarmGui.client.lua` -> `StarterPlayer > StarterPlayerScripts` as LocalScript (main hub UI)

## Input bridge defaults

`InputBridge.client.lua` reads the hotbar from any of these shapes (first hit wins):

- `player.PlayerGui.Hotbar.Slots[<slot>]` with `UnitName` (StringValue) or `Unit` (ObjectValue)
- `workspace.Hotbar[<slot>]` (same attribute conventions)
- `player.PlayerGui.Hotbar.Selected` (NumberValue) or `Hotbar:GetAttribute("SelectedSlot")` (number)

If your hotbar is structured differently, edit the `getUnitNameAtSlot` and
`selectedUnitFromHotbar` functions inside `InputBridge.client.lua`. Default
keyboard shortcuts for unit-context actions:

- `U` upgrade the unit under the cursor
- `X` sell the unit under the cursor
- `Q` activate the unit's ability
- `1`-`6` select a hotbar slot; the next left-click places it on the map

## Public loader

`loader.lua` fetches a single script by `GameId` so a shared repository can
host multiple games. The current `SCRIPTS_BY_GAME` table is empty — add the
tower defense GameId and point it at `FarmGui.client.lua` once that ID is
known. Other client scripts should guard themselves with the same GameId.

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/loader.lua?cache=" .. tostring(os.time())))()
```

## Integration contract

`PlayerGui.FarmControlGui` exposes these attributes:

- `AutoFarm`
- `AutoFarmMobs`
- `SearchRadius`
- `SelectedMob`
- `WeaponSlot`
- `UndergroundRange`
- `HoldSkillMode`, `HeldSkill`, `AutoUseSkills`, `AutoSkills`
- `AutoLootTravel`, `LootTravelRadius`
- `AutoFarmBoss`, `SelectedBoss`, `BossPatrolWait`
- `PositionType`
- `OffsetDistance`
- `HeightOffset`
- `TrackSpeed`
- `DeveloperFly`, `FlySpeed`, `FlyVerticalSpeed`, `DeveloperNoClip`
- `CustomWalkSpeedEnabled`, `WalkSpeed`, `ExtendedJump`, `JumpBoost`
- `AutoOpenChest`, `AutoCollectLoot`, `SelectedChestTier`, `AutoFarmChest`, `LootRadius`
- `NotificationSide`, `InterfaceScale`, `ShowRuntimeStats`

Macro actions are sent through `MacroRemotes.*` events. The macro library
itself lives only on the server (DataStore) and is loaded on demand via
`MacroLoadRequest` when the UI opens the Macros tab.

Client-created GUI attributes do **not** replicate to the server. Send only
the necessary requests through a `RemoteEvent`; validate permissions,
distance, target, damage, rewards, and cooldowns on the server.
