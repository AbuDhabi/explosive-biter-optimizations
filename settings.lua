-- Startup toggles for optimization passes. Wired up in data-final-fixes.lua and control.lua.

data:extend({
  {
    type = "string-setting",
    name = "ebo-optimization-level",
    setting_type = "startup",
    default_value = "balanced",
    allowed_values = { "minimal", "balanced", "aggressive" },
    order = "a"
  },
  {
    type = "bool-setting",
    name = "ebo-reduce-death-explosions",
    setting_type = "startup",
    default_value = true,
    order = "b"
  },
  {
    type = "bool-setting",
    name = "ebo-reduce-fire-spread",
    setting_type = "startup",
    default_value = true,
    order = "c"
  },
  {
    type = "bool-setting",
    name = "ebo-reduce-particle-effects",
    setting_type = "startup",
    default_value = true,
    order = "d"
  },
  {
    type = "bool-setting",
    name = "ebo-downscale-textures",
    setting_type = "startup",
    default_value = true,
    order = "e"
  }
})
