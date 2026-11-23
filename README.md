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
- **3D Rare Token Highlights:** Highlight, selection box, beacon beam, and floating label for Swirled Wax (Yellow), Caustic Wax (Green), and Turpentine (Red)
- **Puffshroom Transparency:** Adjust transparency for Common, Rare, and Epic puffshrooms while keeping Legendary and Mythic puffshrooms 100% visible
- **Mythic Monitor HUD:** Top-of-screen live indicator and spawn notification whenever a Mythic puffshroom is present on the map

> Offline compilation and unit tests pass. Live in-game Roblox behavior has not been verified yet.
