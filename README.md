# Roblox NPC Farm UI (owned experience)

## Standalone reference adaptation

`LukihoHub.client.lua` is a separate single-file Obsidian hub adapted from the
provided Project Slayers 2 reference. It targets the reference's `CAM` module paths,
`Workspace.Humanoids`, `Workspace.Bosses`, `Workspace.BossSpawns`, `Workspace.Chests`,
and `Workspace.LootDrops`. Run it only in an environment you own and can test. Do not
run it alongside `FarmGui.client.lua`; the two interfaces are independent.

Obsidian, ThemeManager, and SaveManager are fetched from the upstream `main` branch
at runtime. A network connection and an environment with `game:HttpGet` and
`loadstring` are required. The script has not been tested inside the target game;
module paths, animation naming, boss markers, prompts, and combat timing may differ.
It respects the game's observed cooldown indicator and does not bypass server
cooldowns. Unload with the UI button or `_G.LukihoHubUnload()`.

### Public loader

Upload both `loader.lua` and `LukihoHub.client.lua` to the root of the public
`HoangKim0312/LukihoHub` repository on its `main` branch. The shared entry point is:

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/HoangKim0312/LukihoHub/main/loader.lua?cache=" .. tostring(os.time())))()
```

The loader fetches the hub from the same repository and reports fetch/compile/start
errors. Both the shared command and the loader's hub request use a cache-busting query,
so executors do not keep running an older raw GitHub response after an update. It does
not hide the hub source: both files must be publicly accessible to
an unauthenticated client. Verify both raw URLs in a signed-out browser before sharing.
It only loads `LukihoHub.client.lua` when `game.GameId` is `5595353122`; the hub
also checks this ID when called directly. This covers root place `16205713724` and
the current subplace `136406881576517` in the same experience. For another game,
add its GameId and a different script filename to `SCRIPTS_BY_GAME` in `loader.lua`,
and set the matching GameId guard in that script. Other experiences are ignored.

The hub catalogs NPCs in `Workspace.Humanoids`, `Workspace.Bosses`, and the
`Enemy`/`Boss`/`EventBoss` tags, remembering names seen during the session. It also
reads `ReplicatedStorage.Regions.NpcSpawns`, the `WorldBosses` module, and boss hunts
when available. The selectors refresh every two seconds; clicking a selected value
again clears it. No selection means auto-farm has no target, while `All` explicitly
targets any NPC in that category. **Travel to Selected** moves toward a live target or
a registered spawn at **NoClip Travel Speed**, temporarily disabling collision.
It does not instant-teleport. The hotbar selector scans toolbar metadata, Tool slot
attributes, visible labels, and item icons; if none expose a name, it explicitly
shows `Name unavailable`. Only NPCs and data replicated to the client can be detected;
the server may still enforce its own movement and combat rules.

The Movement tab also includes **Map Travel**. Its area selector discovers replicated
region/location/waypoint markers and common region-module coordinate tables. Its
NPC/mob selector combines live mobs, bosses, registered spawns, quest givers,
merchants, trainers, and talk/shop prompts. Manual travel searches the full replicated
map instead of using the auto-farm search radius, enables collision bypass only while
moving, and can be cancelled with **Stop Travel**. Destinations that are not replicated
to the client and have no registered coordinates cannot be listed or reached.
The area catalog ignores dialogue, conversation, choice, quest, response, and objective
branches inside region modules. Sentence-like quest answers and names containing a
level requirement are rejected even when they share a valid boss/NPC position.

Auto Level reads the player level from attributes, nested data/leaderstats, or visible
HUD labels such as `117`, `Lv. 117`, and `Level: 117`. Mastery, combat, dialogue,
and quest UI values are excluded. Read-only character-info getters and an explicit
`CombatLevel` value in player data are fallback sources. The most recently verified
player level is retained when the HUD is temporarily hidden.

Before choosing a new quest, Auto Level opens every detected quest conversation and
caches only kill/defeat/hunt/slay choices that explicitly include a positive level,
such as `I'll take the bandit boss (Lv 7)`. Choices without a level are never treated
as level zero. A generic `Talk`, `Chat`, `Interact`, or Humanoid NPC is not enough to
enter this scan: the giver must also expose a quest tag, quest folder, quest attribute,
quest prompt text, level, or target metadata. Explicit delivery, letter, gathering,
collection, talk, and escort quest types are excluded unless they provide a mob target.
Multi-page conversations are advanced through visible Next/Continue/Advance controls,
dialogue arrows, or the large clickable dialogue surface itself, up to 20 steps per
interaction before choices are evaluated. Frame/TextLabel dialogue surfaces use a
virtual click at the center. Unrecognized choice buttons are not clicked automatically.
After the scan, it selects the highest quest level not exceeding the
player's current level, accepts that exact choice, derives the mob target, completes
the objective, and returns to repeat it. Whenever a higher eligible quest becomes
available, the next selection moves to that NPC. **Rescan Quest NPCs** clears the
conversation catalog when newly streamed NPCs need to be discovered again.

Structured quest metadata (`RequiredLevel`/`MinLevel` plus
`QuestTarget`/`TargetMob`) is accepted without opening a conversation. Visible
objectives such as `Bandits defeated 0/3` are used to track progress. NPCs, prompts,
or conversations not replicated to the client cannot be inspected until the game
streams them in.

Hotbar names are cached per slot so a temporary empty toolbar during death/respawn
does not replace `2 - Sickles` with `2`. Internal dropdown refreshes do not fire the
equip callback. The selected slot index survives respawn and is equipped once after
the new character and toolbar are ready; periodic checks no longer toggle an already
equipped weapon off.

Auto Skill Keys and Hold Skill Keys are independent multi-select controls. Auto Cast
can use the known Z/X/C/V/B input mapping before the skill provider or `SHC` cooldown
folder has initialized and rechecks those modules after respawn. Skill input runs
alongside the original five-hit normal attack combo, so enabling Auto Cast does not
truncate the M1 chain. It still respects cooldown markers when they are available and
does not remove server cooldowns. Holding multiple actions depends on what the game's
InputHandler supports. ESP displays up to 250 nearest
replicated mobs, bosses, quest NPCs, and interactable prompts within a configurable
10,000-stud radius. Loot Radius is a **search radius**: auto-loot travels toward a
matching drop and only activates its prompt within `MaxActivationDistance`.

The UI uses a graphite neutral Obsidian theme with restrained blue accents, off-white
text, Gotham font, and separate Farm, Combat, Movement, Loot, ESP, and Settings views.
Slider value outlines are removed to avoid the library's heavy bold-number effect.
ThemeManager uses a `Graphite` folder so older saved palettes do not override it.

## Studio UI prototype

This project contains the Lukiho Automation Console and NPC registries for an
experience you own. It does not use an executor, injection, `loadstring`, `CoreGui`,
or a remotely downloaded UI library.

## Install with Rojo

1. Run `rojo serve` in this directory.
2. Connect the Rojo Studio plugin.
3. Put normal NPC models under `workspace.Enemies`.
4. Put boss models under `workspace.Bosses`.
5. Each NPC model must contain a `Humanoid` and `HumanoidRootPart`.

The server script automatically tags valid enemy models with `Enemy`. Boss models receive
both `Enemy` and `Boss` tags.
The client UI reads those tags, groups living NPCs by model name, and lets the player
select a type. It also falls back to scanning nearby models for existing projects.

## Install without Rojo

- Copy `EnemyRegistry.server.lua` into `ServerScriptService` as a Script.
- Copy `FarmGui.client.lua` into `StarterPlayer > StarterPlayerScripts` as a LocalScript.

## Integration contract

The generated `PlayerGui.FarmControlGui` exposes these attributes:

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

Your client-side controller can observe attribute changes with
`GetAttributeChangedSignal`. Client-created GUI attributes do **not** replicate to the
server. Send only the necessary requests through a `RemoteEvent`; validate permissions,
distance, target, damage, rewards, and cooldowns on the server.

This release remakes the reference script's control surface and NPC discovery, not its
game-specific automation. Auto-farm, skill casting, movement overrides, chest opening,
and rewards require your experience's own combat, inventory, loot, and authorization APIs.
The UI deliberately displays `UI ONLY` until those controllers are connected.
