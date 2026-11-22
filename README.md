# Puffshroom Assistant

Standalone Bee Swarm Simulator utility built with the Atlas+ UI.

## Loadstring

```lua
loadstring(game:HttpGet("https://raw.githubusercontent.com/DarkBotGen/puffshroom-assistant/main/loader.lua"))()
```

The loader resolves the latest `main` commit SHA from GitHub and fetches its immutable raw build (with `main` fallback).

## Features

- **Atlas+ WalkSpeed:** Fixed and dynamic walkspeed modes up to `90`
- **Token Hider:** Independently hide Honey, Soft Wax, and Bitterberry tokens
- **Puffshroom Transparency:** Adjust transparency for Common, Rare, and Epic puffshrooms while keeping Legendary and Mythic puffshrooms 100% visible
- **Mythic Monitor HUD:** Top-of-screen live indicator and spawn notification whenever a Mythic puffshroom is present on the map

> Offline compilation and unit tests pass. Live in-game Roblox behavior has not been verified yet.
