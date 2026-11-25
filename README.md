# Puffshroom Assistant

Standalone Bee Swarm Simulator utility built with the Atlas+ UI.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/puffshroom-assistant/main/loader.lua"))()
```

The loader resolves the latest `main` commit SHA from GitHub and fetches its immutable raw build (with `main` fallback).

## Features

- **Atlas+ WalkSpeed:** Fixed and dynamic walkspeed modes up to `90`
- **Hide Decorations:** Reversible World / Performance toggle matching `fullscript.txt` decoration targets cleanly restoring parents and platform collision on disable/unload
- **Auto Face Flames (`BodyGyro`):** Shift Lock–compatible (`Humanoid.AutoRotate` suppression + post-camera `BindToRenderStep`) Y-axis yaw facing (`MaxTorque = (0, inf, 0)`) that never locks your camera or overrides movement, prioritizes expiring flames for refresh, cleanly restores `AutoRotate`, and includes optional refresh-synced auto dig
- **Auto Stinger (Slot 5, Default `F` Keybind):** Rebindable hotkey (`F` by default, safely ignoring chat/UI focus) that toggles automatic Stinger use every `10s` via `PlayerActivesCommand` (with `VirtualInputManager` Slot `5` fallback and stock/cooldown checks)
- **Token Hider:** Independently hide Honey, Soft Wax, Bitterberry, Treat, and Royal Jelly tokens
- **3D Rare & Sticker Highlights:** Clean contour `Highlight` (`FillTransparency = 0.58`), sleek glowing `Cylinder` drop beam + `CylinderHandleAdornment` X-ray, and compact accent-bar `BillboardGui` label for Swirled Wax (Yellow), Caustic Wax (Green), Turpentine (Red), **Wavy Purple Hive Skin** (Purple, dynamically resolved via `StickerTypes`), plus optional **All Sticker Tokens** (Cyan)
- **Puffshroom Transparency & Non-Mythic Hiding:** Adjust transparency for Common, Rare, and Epic puffshrooms or enable **Hide Non-Mythic Puffshrooms** to hide non-Mythic models, spores, and labels completely during massive splits while keeping Legendary/Mythic puffshrooms 100% visible
- **Mythic Monitor HUD:** Slim top-of-screen live indicator with status halo and native dark-slate toast notifications whenever a Mythic puffshroom is present on the map

> **Performance & FPS Optimizer (`World / Performance`) & Clean UI**:
> - One-click **Ultra FPS Mode (Preset)** toggles extreme potato/anti-lag optimizations at once (Low Graphics + Clouds/world decals/emitters off, Hide Decorations, Hide Bees, Hide Flowers, Hide Field Balloons, Ultra LocalFX filter, Spore Trails off, Hide Non-Mythic Puffshrooms, **Skip Pickup Anim**, **Hide Player Amulets**, and **Hide Loot (Keep Bee + Rare)**) while keeping **other players** and **bee ability tokens** visible (`Hide Other Players` remains available separately)
> - Selective `CollectiblesAnimator.Spawn` culling (`Hide Loot (Keep Bee + Rare)`), `CollectiblesAnimator.AnimateCollect` skip (`Skip Pickup Anim`), and `LocalAmulets.CreatePlayerAmulets` / character amulet hiding (`Hide Player Amulets`) cut CPU/GPU spikes during heavy puffshroom chains and Token Link sweeps while preserving Caustic Wax, Swirled Wax, Turpentine, Wavy Purple Hive Skin, and **all bee ability tokens** (Token Link, Boosts, Haste, Focus, Melody, Marks, etc.)
> - Reversible **Low Graphics / Anti-Lag** (disables shadows, fog, IBL specular/diffuse, Atmosphere haze, `Clouds`, post-effects, water ripples, terrain grass, `PollenPopUps`, static scenery decals/textures/emitters, sets `Level01`, simplifies non-`Neon`/`Glass`/`ForceField` world parts without hot `workspace.DescendantAdded` overhead while preserving player characters and highlight/drop beams)
> - Debounced `task.defer` puff/monitor batching, fast `extractTokenIconId` token classification (skipping heavy watcher trees on pre-replicated tokens), weak `savedParticles` tracking, and `flameController` Shift Lock sync

> Offline compilation, static analysis, unit tests, and headless E2E checks pass. Live in-game Roblox behavior has not been verified yet.
