# Feature Design Document: Companion API & Remote Interface System

## Overview

The game runs a lightweight local HTTP server exposing game state through a RESTful API. External devices on the same network (phones, tablets, browsers) can query this API to power companion experiences: a live minimap, game state display, and a hidden remote debug console. All queryable data is backed by **universal game functions** decoupled from the API layer, enabling future transports (database sync, cloud relay) without rewriting game logic.

---

## Architecture

### Layered Design

```
┌─────────────────────────────────────┐
│        Companion App / Website      │  ← Polls or connects to API
├─────────────────────────────────────┤
│       HTTP API Server (Godot)       │  ← Transport layer (local network)
├─────────────────────────────────────┤
│     Universal Query Functions       │  ← Pure game-state accessors
├─────────────────────────────────────┤
│         Game Systems / Scene        │  ← Source of truth
└─────────────────────────────────────┘
```

- **Universal Query Functions** are callable from anywhere in the game — UI, scripting, debug tools, not just the API.
- **HTTP API Server** is one consumer of those functions, serializing responses to JSON.
- **Future transports** (e.g., database sync for remote/global access) consume the same universal functions.

### Server Details

| Property        | Detail                                              |
|-----------------|-----------------------------------------------------|
| Runtime         | Embedded in the Godot process (HTTPServer or TCP)   |
| Default Port    | TBD (e.g., `7700`)                                  |
| Binding         | `0.0.0.0` (LAN-accessible)                         |
| Startup         | Automatic on game launch; always running             |
| Format          | JSON responses, standard HTTP status codes           |

---

## Map Bounds & Normalized Coordinates

### Editor Setup

Two empty `Marker3D` (or `Node2D`) nodes are placed in the scene to define the queryable area:

- **`MapBoundMin`** — Bottom-left corner of the playable/viewable area.
- **`MapBoundMax`** — Top-right corner of the playable/viewable area.

These are positioned by the designer in the editor to frame the region the companion minimap should represent.

### Normalization

Player world position is normalized to a **0–100** range (per axis) relative to the bounds:

```
normalized_x = ((player.x - min.x) / (max.x - min.x)) * RANGE_MAX
normalized_y = ((player.y - min.y) / (max.y - min.y)) * RANGE_MAX
```

- `RANGE_MAX` defaults to `100` but is configurable. A higher value (e.g., `1000`) gives finer positional granularity for larger maps.
- Values outside `0–RANGE_MAX` indicate the player is outside the defined bounds. The API should still return the value (not clamp), but may include an `out_of_bounds: true` flag.

### Companion Rendering

On the companion app/website:

- The minimap image represents the bounded area exactly.
- **Bottom-left pixel** = `MapBoundMin` world position = normalized `(0, 0)`.
- **Top-right pixel** = `MapBoundMax` world position = normalized `(RANGE_MAX, RANGE_MAX)`.
- Player marker is placed at the proportional position on the image.

---

## API Endpoints

### `GET /player/location`

Returns the player's normalized position within the map bounds.

```json
{
  "x": 43.7,
  "y": 81.2,
  "out_of_bounds": false,
  "range_max": 100
}
```

**Backed by:** `GameQuery.get_player_location() -> Dictionary`

### `GET /player/info`

Returns general player information (extensible).

```json
{
  "name": "PlayerName",
  "health": 85,
  "location": { "x": 43.7, "y": 81.2, "out_of_bounds": false },
  "custom": {}
}
```

**Backed by:** `GameQuery.get_player_info() -> Dictionary`

### `GET /state`

Returns the current game state for UI decisions on the companion.

```json
{
  "scene": "gameplay",
  "paused": false,
  "in_menu": false,
  "menu_context": null
}
```

Possible `scene` values: `"main_menu"`, `"gameplay"`, `"settings"`, `"cutscene"`, `"loading"`, etc.

The companion app uses this to decide what to render — e.g., hide the minimap on the main menu, show a "Paused" overlay, display settings mirrors, etc.

**Backed by:** `GameQuery.get_game_state() -> Dictionary`

### `GET /debug/status`

Returns whether the debug API is currently enabled.

```json
{
  "enabled": false
}
```

### `POST /debug/command`

Executes a debug action remotely. **Only functional when debug mode is enabled.**

```json
// Request
{
  "action": "teleport",
  "params": { "x": 50, "y": 50 }
}

// Response
{
  "success": true,
  "message": "Teleported player to (50, 50)"
}
```

Debug actions are defined as a registry of named commands. Examples:

| Action              | Description                          |
|---------------------|--------------------------------------|
| `teleport`          | Move player to normalized coords    |
| `set_health`        | Override player health               |
| `toggle_noclip`     | Toggle collision                     |
| `reload_scene`      | Reload the current scene             |
| `set_timescale`     | Change Engine.time_scale             |
| `toggle_visibility` | Show/hide specific nodes by path     |

The companion app/website renders these as simple labeled buttons or input forms — no in-game console UI needed. Ideal for demos and testing.

**Backed by:** `DebugActions.execute(action: String, params: Dictionary) -> Dictionary`

### `GET /config`

Returns current API configuration (useful for companion app self-configuration).

```json
{
  "port": 7700,
  "range_max": 100,
  "debug_enabled": false,
  "version": "0.1.0"
}
```

---

## Configuration & Settings

### In-Game Options

| Setting           | Location                     | Visibility       | Default  |
|-------------------|------------------------------|-------------------|----------|
| API Port          | Settings → Advanced (hidden) | Hidden by default | `7700`   |
| Debug Mode        | Settings → Advanced (hidden) | Hidden by default | `false`  |
| Coordinate Range  | Settings → Advanced (hidden) | Hidden by default | `100`    |

"Hidden" means these live behind an Advanced section that is collapsed or requires a deliberate toggle/gesture to reveal (e.g., click a version label N times, or a toggle in a config file).

### On Companion App/Website

The companion should mirror these settings — particularly the port override — so a user who changes the port in-game can also update the companion without confusion. The companion settings panel should also be tucked away (gear icon, long-press, etc.).

---

## Universal Game Functions (Decoupled Layer)

All data exposed by the API originates from a set of static/autoload functions. These are the **single source of truth** and are designed to be called from any context.

```
class_name GameQuery

static func get_player_location() -> Dictionary
static func get_player_info() -> Dictionary
static func get_game_state() -> Dictionary
static func get_map_bounds() -> Dictionary
```

```
class_name DebugActions

static func execute(action: String, params: Dictionary) -> Dictionary
static func is_enabled() -> bool
static func list_actions() -> Array[String]
```

### Why Decoupled?

This design enables **transport-agnostic access** to game state:

| Transport         | How It Uses Universal Functions                    |
|-------------------|----------------------------------------------------|
| Local HTTP API    | Serializes return values to JSON responses          |
| Database Sync     | Periodically writes location/state to a remote DB   |
| Cloud Relay       | Pushes state to a WebSocket or REST service          |
| In-Game UI        | Calls the same functions for HUD or debug overlays   |

**Database transport future scope:** If a player is logged in, the game periodically pushes `get_player_location()` and `get_game_state()` results to a remote database. The companion app can then query that database instead of the local API — enabling global access without LAN, useful for AFK monitoring or shared viewing.

---

## Companion App / Website Behavior

### Minimap View

- Loads a top-down image of the game map (pre-rendered or exported from the editor).
- Polls `GET /player/location` on a configurable interval (e.g., 200ms–1s).
- Renders a player marker at the normalized `(x, y)` position on the image.
- Image corners correspond exactly to `MapBoundMin` and `MapBoundMax`.

### State-Driven UI

- Polls `GET /state` to determine what view to show.
- `"main_menu"` → Show a waiting/idle screen or game info.
- `"gameplay"` → Show the minimap.
- `"paused"` → Overlay a pause indicator.
- `"settings"` → Optionally mirror or hide content.

### Debug Panel

- Hidden by default (accessed via gesture, hidden button, URL param, etc.).
- Only functional when `GET /debug/status` returns `enabled: true`.
- Renders available debug actions as buttons/forms.
- Sends `POST /debug/command` on interaction.
- Designed for demos and development — no in-game UI clutter.

### Connection Flow

1. User enters the game's local IP and port (or uses discovery/mDNS if implemented later).
2. Companion fetches `GET /config` to confirm connection and read settings.
3. Begins polling relevant endpoints.

---

## Open Questions & Future Considerations

- **Polling vs. WebSocket:** Initial implementation uses polling. WebSocket upgrade would reduce latency and bandwidth for high-frequency updates (player movement).
- **Authentication:** No auth for local-only use. If database/cloud transport is added, authentication becomes required.
- **Multi-player:** Current design assumes single player. Extending to multiplayer would change `/player/` endpoints to `/players/{id}/`.
- **mDNS / Auto-Discovery:** Could broadcast the API service on the local network so the companion app finds it automatically without manual IP entry.
- **Coordinate Range:** `100` is a starting point. Evaluate whether `1000` or `10000` gives meaningfully better marker precision on the companion minimap for large maps.
- **Rate Limiting:** Consider a simple rate limit on the API to prevent accidental flooding from aggressive poll intervals.
