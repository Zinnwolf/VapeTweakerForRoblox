# Game-specific VapeTweaker layers

VapeTweaker loads in this order:

1. Universal modules and patches
2. Universe-specific layer
3. Build-specific layer
4. PlaceId-specific layer

Target manifests are inspected before universal files are executed. This allows
a game to exclude incompatible universal files completely.

## Recommended layout

```text
src/
  games/
    manifest.lua
    xylex/
      shared/
        manifest.lua
        modules/
          world/
            manifest.lua
            example.lua
      123456789 - game/
        manifest.lua
        modules/
          combat/
            manifest.lua
            gamespecific.lua
```

`src/games/manifest.lua` maps Roblox IDs to friendly source folders:

```lua
return {
    universes = {
        ['987654321'] = 'xylex/shared'
    },
    places = {
        ['123456789'] = 'xylex/123456789 - game'
    }
}
```

A target `manifest.lua` can exclude universal files and load local roots:

```lua
return {
    exclude = {
        modules = {
            'world/fastprompt.lua',
            'render/proximitypromptesp.lua'
        },
        patches = {
            'render/crosshair.lua'
        }
    },

    -- Optional name-based removal after universal loading.
    -- This only removes modules created by VapeTweaker.
    remove = {
        'AnotherUniversalModule'
    },

    modules = true,
    patches = true
}
```

The local module manifests use the normal VapeTweaker format:

```lua
return {
    files = {
        'gamespecific.lua'
    }
}
```

A game-specific module may reuse the name of an excluded universal module:

```lua
return function(ctx)
    local mod

    mod = ctx:module('world', {
        name = 'FastPrompt',
        tooltip = 'Game-specific FastPrompt implementation.',
        func = function(enabled)
            if enabled then
                -- Game-specific implementation.
            end
        end
    })
end
```

## Direct PlaceId folders

A registry is optional. This also works:

```text
src/games/123456789/manifest.lua
src/games/123456789/modules/world/manifest.lua
src/games/123456789/modules/world/gamespecific.lua
```

## Existing universe hierarchy

The previous hierarchy remains supported:

```text
src/games/<GameId>/manifest.lua
src/games/<GameId>/modules/...
src/games/<GameId>/builds/<BuildId>/...
src/games/<GameId>/places/<PlaceId>/...
```

Its game, build, and place manifests can also use `exclude` and `remove`.
