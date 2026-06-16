-- Prototype patches applied after Explosive Biters finishes loading.
-- data-final-fixes runs late enough to override EB death effects, explosions, and fire.

local reduce_explosions = settings.startup["ebo-reduce-death-explosions"].value
local reduce_fire = settings.startup["ebo-reduce-fire-spread"].value
local reduce_particles = settings.startup["ebo-reduce-particle-effects"].value
local level = settings.startup["ebo-optimization-level"].value

local function scale_by_level(balanced, aggressive)
  if level == "minimal" then
    return 1
  elseif level == "aggressive" then
    return aggressive
  end
  return balanced
end

-- TODO: patch Explosive Biters explosion, fire, and entity prototypes here.
-- Example targets (names from Explosive_biters):
--   explosive biter / spitter / worm death explosions
--   fire prototypes spawned on death
--   particle-heavy attack and projectile effects
--
-- if reduce_explosions then
--   local explosion = data.raw["explosion"]["some-eb-explosion"]
--   if explosion then
--     explosion.damage = explosion.damage and { amount = explosion.damage.amount * scale_by_level(0.75, 0.5) }
--   end
-- end

if reduce_explosions or reduce_fire or reduce_particles then
  log("[explosive-biter-optimizations] Loaded (level=" .. level .. "). Prototype patches not yet implemented.")
end
