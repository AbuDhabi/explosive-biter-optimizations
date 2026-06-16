-- Runtime optimizations for Explosive Biters, if prototype tweaks alone are not enough.
-- Most UPS wins should live in data-final-fixes.lua; use this file only when play-time behavior must change.

-- TODO: hook Explosive Biters events or throttle expensive effects when needed.

script.on_init(function()
  storage.ebo_version = "0.1.0"
end)

script.on_configuration_changed(function()
  storage.ebo_version = "0.1.0"
end)
