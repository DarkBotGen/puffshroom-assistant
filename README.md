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
- **Token Hider:** Independently hide Honey, Soft Wax, Bitterberry, Treat, and Royal Jelly tokens
- **3D Rare Token Highlights:** Clean contour `Highlight` (`FillTransparency = 0.58`), sleek glowing `Cylinder` drop beam + `CylinderHandleAdornment` X-ray, and compact accent-bar `BillboardGui` label for Swirled Wax (Yellow), Caustic Wax (Green), and Turpentine (Red)
- **Puffshroom Transparency:** Adjust transparency for Common, Rare, and Epic puffshrooms while keeping Legendary and Mythic puffshrooms 100% visible
- **Mythic Monitor HUD:** Slim top-of-screen live indicator with status halo and native dark-slate toast notifications whenever a Mythic puffshroom is present on the map

> **Performance & FPS Optimizer (`World / Performance`) & Clean UI**:
> - Reversible **Low Graphics / Anti-Lag** (disables shadows, fog, IBL specular/diffuse, Atmosphere haze, post-effects, water ripples, terrain grass, `PollenPopUps`, sets `Level01`, simplifies non-`Neon`/`Glass`/`ForceField` world parts while preserving `LocalPlayer.Character` and highlight/drop beams)
> - Reversible **Hide Bees**, **Hide Other Players**, **Hide Flowers**, **Hide Field Balloons**, and **Filter Particles (Keep Key FX)** (with **Keep Spore Trails** toggle)
> - Zero-VRAM chevron icons, modern pill switches, scale-based sliders with zero drag tweens, 20Hz token beacon tracking, `puffMetaCache`, `puffVisuals` caching, `tokenHider` caching, and `flameController` Shift Lock sync

> Offline compilation, static analysis, unit tests, and headless E2E checks pass. Live in-game Roblox behavior has not been verified yet.
