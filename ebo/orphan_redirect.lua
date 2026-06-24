-- Orphaned explosive biters: release from dead nests and let the engine adopt the nearest
-- living spawner. Avoids mass go_to_location storms that keep hundreds of units active.

if not settings.startup["ebo-redirect-orphaned-biters"].value then
  return
end

-- Vanilla re-binds wanderers to a spawner within 5 chunks (160 tiles).
local ADOPT_RADIUS = 160
local SETTLE_RADIUS = 48
local SPAWN_DEATH_SCAN_RADIUS = 256
local SPAWNER_SCAN_RADII = { 64, 128, 256, 512, 1024, 2048 }
local QUEUE_BATCH = 20
local FAR_REDIRECT_COOLDOWN = 60 * 30

local EB_UNIT_NAMES = {
  "small-explosive-biter",
  "medium-explosive-biter",
  "big-explosive-biter",
  "behemoth-explosive-biter",
  "explosive-leviathan-biter",
  "small-explosive-spitter",
  "medium-explosive-spitter",
  "big-explosive-spitter",
  "behemoth-explosive-spitter",
  "leviathan-explosive-spitter",
  "mother-explosive-spitter",
}

local eb_unit_names = {}
for _, name in ipairs(EB_UNIT_NAMES) do
  eb_unit_names[name] = true
end

local function is_eb_unit(name)
  return eb_unit_names[name] == true
end

local function distance_squared(a, b)
  local dx = a.x - b.x
  local dy = a.y - b.y
  return dx * dx + dy * dy
end

local function spawner_is_valid(unit)
  local commandable = unit.commandable
  if not commandable then
    return false
  end
  local spawner = commandable.spawner
  return spawner and spawner.valid
end

local function is_settled(unit_number)
  return storage.ebo_settled and storage.ebo_settled[unit_number]
end

local function mark_settled(unit_number)
  storage.ebo_settled = storage.ebo_settled or {}
  storage.ebo_settled[unit_number] = true
end

local function clear_settled(unit_number)
  if storage.ebo_settled then
    storage.ebo_settled[unit_number] = nil
  end
end

local function nearest_entity(unit, candidates)
  local position = unit.position
  local px, py = position.x, position.y
  local nearest
  local nearest_dist

  for _, entity in ipairs(candidates) do
    if entity.valid then
      local dx = entity.position.x - px
      local dy = entity.position.y - py
      local dist = dx * dx + dy * dy
      if not nearest_dist or dist < nearest_dist then
        nearest = entity
        nearest_dist = dist
      end
    end
  end

  return nearest
end

local function find_nearest_spawner(unit)
  local surface = unit.surface
  local force = unit.force
  local position = unit.position

  for _, radius in ipairs(SPAWNER_SCAN_RADII) do
    local explosive_spawners = surface.find_entities_filtered({
      name = "explosive-biter-spawner",
      force = force,
      position = position,
      radius = radius,
    })
    local spawner = nearest_entity(unit, explosive_spawners)
    if spawner then
      return spawner
    end

    local vanilla_spawners = surface.find_entities_filtered({
      type = "unit-spawner",
      force = force,
      position = position,
      radius = radius,
    })
    spawner = nearest_entity(unit, vanilla_spawners)
    if spawner then
      return spawner
    end
  end

  return nil
end

local function release_and_autonomous(unit)
  local commandable = unit.commandable
  if not commandable then
    return
  end
  commandable.release_from_spawner()
  commandable.set_autonomous()
end

local function settle_near_spawner(unit, spawner)
  release_and_autonomous(unit)
  mark_settled(unit.unit_number)
end

local function wander_orphan(unit)
  local commandable = unit.commandable
  if not commandable then
    return
  end
  commandable.release_from_spawner()
  commandable.set_command({ type = defines.command.wander })
end

local function redirect_orphan(unit)
  if not unit.valid or not is_eb_unit(unit.name) then
    return false
  end

  if spawner_is_valid(unit) then
    clear_settled(unit.unit_number)
    return false
  end

  if is_settled(unit.unit_number) then
    return false
  end

  local commandable = unit.commandable
  if not commandable then
    return false
  end

  local spawner = find_nearest_spawner(unit)
  if not spawner then
    wander_orphan(unit)
    mark_settled(unit.unit_number)
    return true
  end

  local dist_sq = distance_squared(unit.position, spawner.position)
  local settle_radius_sq = SETTLE_RADIUS * SETTLE_RADIUS
  local adopt_radius_sq = ADOPT_RADIUS * ADOPT_RADIUS

  if dist_sq <= settle_radius_sq then
    settle_near_spawner(unit, spawner)
    return true
  end

  if dist_sq <= adopt_radius_sq then
  -- Close enough for vanilla adoption once released; do not pathfind.
    release_and_autonomous(unit)
    return true
  end

  storage.ebo_far_redirect = storage.ebo_far_redirect or {}
  local last_tick = storage.ebo_far_redirect[unit.unit_number]
  if last_tick and game.tick - last_tick < FAR_REDIRECT_COOLDOWN then
    return false
  end

  commandable.release_from_spawner()
  commandable.set_command({
    type = defines.command.go_to_location,
    destination_entity = spawner,
    distraction = defines.distraction.none,
    radius = 20,
    pathfind_flags = {
      use_cache = true,
      allow_paths_through_own_entities = true,
      prefer_straight_paths = true,
    },
  })

  storage.ebo_far_redirect[unit.unit_number] = game.tick
  return true
end

local function enqueue_orphan(unit_number)
  storage.ebo_redirect_queue = storage.ebo_redirect_queue or {}
  storage.ebo_redirect_queue[#storage.ebo_redirect_queue + 1] = unit_number
end

local function redirect_units_bound_to_spawner(dead_spawner)
  local surface = dead_spawner.surface
  local force = dead_spawner.force
  if not surface or not force then
    return
  end

  local units = surface.find_entities_filtered({
    type = "unit",
    force = force,
    position = dead_spawner.position,
    radius = SPAWN_DEATH_SCAN_RADIUS,
  })

  for _, unit in ipairs(units) do
    if is_eb_unit(unit.name) and not spawner_is_valid(unit) and not is_settled(unit.unit_number) then
      local commandable = unit.commandable
      if commandable and commandable.spawner == dead_spawner then
        enqueue_orphan(unit.unit_number)
      end
    end
  end
end

script.on_event(defines.events.on_entity_died, function(event)
  local entity = event.entity
  if not entity or entity.name ~= "explosive-biter-spawner" then
    return
  end
  redirect_units_bound_to_spawner(entity)
end)

script.on_event(defines.events.on_ai_command_completed, function(event)
  if event.was_distracted then
    return
  end

  local unit = game.get_entity_by_unit_number(event.unit_number)
  if not unit or not unit.valid or not is_eb_unit(unit.name) then
    return
  end

  if spawner_is_valid(unit) then
    clear_settled(unit.unit_number)
    return
  end

  if is_settled(unit.unit_number) then
    return
  end

  local spawner = find_nearest_spawner(unit)
  if not spawner then
    wander_orphan(unit)
    mark_settled(unit.unit_number)
    return
  end

  local dist_sq = distance_squared(unit.position, spawner.position)
  if dist_sq <= ADOPT_RADIUS * ADOPT_RADIUS then
    settle_near_spawner(unit, spawner)
    return
  end

  -- Path failed or finished while still far away: wander so we do not re-queue pathfinding.
  if event.result == defines.behavior_result.fail then
    release_and_autonomous(unit)
  end
end)

script.on_nth_tick(6, function()
  local queue = storage.ebo_redirect_queue
  if not queue or #queue == 0 then
    return
  end

  local processed = 0
  while processed < QUEUE_BATCH and #queue > 0 do
    local unit_number = table.remove(queue, 1)
    local unit = game.get_entity_by_unit_number(unit_number)
    if unit and unit.valid then
      redirect_orphan(unit)
    end
    processed = processed + 1
  end
end)

script.on_init(function()
  storage.ebo_redirect_queue = storage.ebo_redirect_queue or {}
  storage.ebo_settled = storage.ebo_settled or {}
  storage.ebo_far_redirect = storage.ebo_far_redirect or {}
end)

script.on_configuration_changed(function()
  storage.ebo_redirect_queue = storage.ebo_redirect_queue or {}
  storage.ebo_settled = storage.ebo_settled or {}
  storage.ebo_far_redirect = storage.ebo_far_redirect or {}
end)
