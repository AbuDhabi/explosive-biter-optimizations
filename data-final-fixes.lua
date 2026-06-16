-- Patches applied after Explosive Biters finishes loading (hard dependency in info.json).

local reduce_death_explosions = settings.startup["ebo-reduce-death-explosions"].value
if not reduce_death_explosions then
  return
end

local level = settings.startup["ebo-optimization-level"].value
if level == "minimal" then
  log("[explosive-biter-optimizations] Optimization level is minimal; leaving Explosive Biters explosions unchanged.")
  return
end

local reduce_fire = settings.startup["ebo-reduce-fire-spread"].value
local reduce_particles = settings.startup["ebo-reduce-particle-effects"].value

local damage_scaler = settings.startup["eb-DamageScaler"]
local DAMAGE_S = damage_scaler and damage_scaler.value or 1

-- Explosive Biters uses small-atomic-explosion for nests, leviathan-tier units, mother worms,
-- and bosses. Keep the nuke look and crater from the original, but replace the hundreds of
-- atomic shockwave projectiles with a pair of lightweight area-damage hits that approximate
-- atomic-bomb-ground-zero-projectile and atomic-bomb-wave from base game.
local BALANCED_RADIUS = 14
local OUTER_DAMAGE = 400
local INNER_RADIUS = 4
local INNER_DAMAGE = 150

local function scaled_huge_explosion_values()
  local radius = BALANCED_RADIUS
  local outer_damage = OUTER_DAMAGE * DAMAGE_S
  local inner_radius = INNER_RADIUS
  local inner_damage = INNER_DAMAGE * DAMAGE_S
  local edge_modifier = 0.1

  if level == "aggressive" then
    radius = 12
    outer_damage = outer_damage * 0.95
    inner_radius = 3
    inner_damage = inner_damage * 0.95
  end

  return outer_damage, radius, inner_radius, inner_damage, edge_modifier
end

local explosion = data.raw.explosion["small-atomic-explosion"]
if not explosion then
  log("[explosive-biter-optimizations] small-atomic-explosion not found; is Explosive_biters loaded?")
  return
end

local outer_damage, radius, inner_radius, inner_damage, edge_modifier = scaled_huge_explosion_values()
local nuke_reference = data.raw.explosion["nuke-explosion"]

if nuke_reference then
  explosion.animations = table.deepcopy(nuke_reference.animations)
  if nuke_reference.sound then
    explosion.sound = table.deepcopy(nuke_reference.sound)
  end
end

explosion.light = {intensity = 1, size = 50, color = {r = 1.0, g = 1.0, b = 1.0}}

local target_effects = {
  {
    type = "nested-result",
    action = {
      type = "area",
      radius = radius,
      ignore_collision_condition = true,
      action_delivery = {
        type = "instant",
        target_effects = {
          {
            type = "damage",
            damage = {amount = outer_damage, type = "explosion"},
            lower_distance_threshold = 0,
            upper_distance_threshold = radius,
            lower_damage_modifier = 1,
            upper_damage_modifier = edge_modifier
          }
        }
      }
    }
  },
  {
    type = "nested-result",
    action = {
      type = "area",
      radius = inner_radius,
      ignore_collision_condition = true,
      action_delivery = {
        type = "instant",
        target_effects = {
          {
            type = "damage",
            vaporize = true,
            damage = {amount = inner_damage, type = "explosion"}
          }
        }
      }
    }
  },
  {
    type = "create-entity",
    entity_name = "big-scorchmark",
    check_buildability = true
  }
}

if not reduce_particles then
  table.insert(target_effects, {
    type = "create-particle",
    repeat_count = 30,
    particle_name = "explosion-remnants-particle",
    initial_height = 0.5,
    speed_from_center = 0.08,
    speed_from_center_deviation = 0.15,
    initial_vertical_speed = 0.08,
    initial_vertical_speed_deviation = 0.15,
    offset_deviation = {{-0.4, -0.4}, {0.4, 0.4}}
  })
end

if not reduce_fire and data.raw.fire["explosive-biter-flame"] then
  table.insert(target_effects, {
    type = "create-fire",
    entity_name = "explosive-biter-flame",
    initial_ground_flame_count = radius
  })
end

explosion.created_effect = {
  type = "direct",
  action_delivery = {
    type = "instant",
    target_effects = target_effects
  }
}

log("[explosive-biter-optimizations] Replaced small-atomic-explosion with lightweight nuke-style blast (outer="
  .. outer_damage .. " / " .. radius .. ", inner=" .. inner_damage .. " / " .. inner_radius .. ", level=" .. level .. ").")
