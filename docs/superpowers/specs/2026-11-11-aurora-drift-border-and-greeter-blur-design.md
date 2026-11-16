# Aurora Drift border + greeter/lock blur

Date: 2026-11-11  
Status: approved design; border implementation in progress

## Goal

1. Focused-window border: fancy blue → green → purple ring with slow drift (no audio).
2. Gaussian blur on both Noctalia Greeter login wallpaper and lock-screen background.

## Why not community Spectrum

`border/spectrum` is audio-reactive. Without a strong spectrum feed it returns the native border, so it looks like “no colorful border.”

## Border: Aurora Drift

Custom preset under:

- Repo: `umbriel/shaders/community/border/aurora-drift/{effect.toml,shader.glsl}`
- Live: `~/.config/umbriel/shaders/community/border/aurora-drift/`

Config:

```toml
[include]
files = ["shaders/community/border/aurora-drift/effect.toml"]

[effects]
border = "aurora-drift"
```

Behavior:

- Hue path locked to blue → green → purple
- Slow angular drift via `umbriel_time` and TOML `speed = 0.35`
- Thin halo (`padding = 8`), no audio uniforms, `palette = false`
- Focused decorated windows only (Umbriel default)

## Background blur

### Lock screen

Raise Noctalia `lockscreen.blur_intensity` in `~/.local/state/noctalia/settings.toml` (from `0.5` toward `0.75`–`0.85`).

### Login greeter

Greeter has no live Gaussian API. Pre-blur wallpaper with ImageMagick (`magick`), e.g. `macos-sonoma-blur.jpg`, and pin it in `/var/lib/noctalia-greeter/greeter.toml` under `[appearance.wallpaper]` so Sync cannot overwrite with the sharp image. Desktop wallpaper stays sharp. Script: `scripts/blur-greeter-wallpaper.sh`.

## Verification

- `umbriel config validate`
- Focused window shows drifting blue/green/purple without music
- Lock screen blur stronger
- Greeter shows blurred wallpaper after logout / greetd restart
