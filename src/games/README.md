# Game specific modules

VapeTweaker checks this exact path when it starts:

```text
src/games/<game.PlaceId>/
```

When the folder exists, every `.lua` file under these paths is loaded
automatically:

```text
src/games/<PlaceId>/modules/<category>/
src/games/<PlaceId>/patches/<category>/
```

Example:

```text
src/games/6872274481/
  manifest.lua
  modules/
    combat/
      BedWarsAura.lua
    world/
      BedWarsFastBreak.lua
```

No registry entry is required. The numeric folder name is the PlaceId.

A module file still uses the normal VapeTweaker format:

```lua
return function(ctx)
    local mod

    mod = ctx:module('world', {
        name = 'Example',
        tooltip = 'aaa',
        func = function(enabled)
            if enabled then
                -- implementation
            end
        end
    })
end
```

The loader obtains the repository tree in one GitHub API request and discovers
the files automatically. The local `modules/manifest.lua` and
`patches/manifest.lua` files are fallback indexes for environments where that
API request is unavailable.

Use the PlaceId folder's `manifest.lua` to exclude incompatible universal
files before they execute:

```lua
exclude = {
    modules = {
        'world/fastprompt.lua'
    },
    patches = {
        'render/crosshair.lua'
    }
}
```
