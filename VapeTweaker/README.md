# VapeTweaker

A separate extension layer that attaches to the currently loaded Vape UI and registers organized modules without editing Vape's compiled files.

## Current proof of attachment

`src/modules/combat/testieBestie.lua` creates a real **testieBestie** module in Vape's **Combat** category. Enabling it displays:

> Yuh everything works

## Structure

```text
VapeTweaker/
├── loader.lua
├── src/
│   ├── init.lua
│   ├── manifest.lua
│   ├── core/
│   │   ├── cleanup.lua
│   │   ├── logger.lua
│   │   └── runtime.lua
│   ├── adapters/
│   │   └── vape.lua
│   └── modules/
│       └── combat/
│           └── testieBestie.lua
└── examples/
    ├── run-local.lua
    └── run-remote.lua
```

## Local execution

Place the project at `VapeTweaker/` in the executor workspace and execute `examples/run-local.lua`.

The adapter first attaches to `shared.vape`. When Vape is not already loaded, it starts the configured Vape loader and waits for the real Combat UI category.

## Remote execution

Upload the project to a repository, replace `OWNER/REPOSITORY` in `examples/run-remote.lua`, and execute that file. For a private repository, do not embed a personal GitHub token in the loader; use an authenticated endpoint that returns the project files.

## Reload and unload

Executing the loader again unloads the previous VapeTweaker instance, removes its registered modules, and attaches a fresh instance.

Manual unload:

```lua
if getgenv().VapeTweaker then
	getgenv().VapeTweaker:Unload('manual')
end
```

VapeTweaker does not uninject Vape itself.
