-- Allow half-res loading of Explosive Biters sprite sheets (vanilla biters set this; EB does not).

if not settings.startup["ebo-downscale-textures"].value then
  return
end

local EB_PREFIX = "__Explosive_biters__"
local patched = 0
local visited = {}

local function uses_eb_graphics(sprite)
  if type(sprite.filename) == "string" and sprite.filename:find(EB_PREFIX, 1, true) then
    return true
  end
  if type(sprite.filenames) == "table" then
    for _, filename in ipairs(sprite.filenames) do
      if type(filename) == "string" and filename:find(EB_PREFIX, 1, true) then
        return true
      end
    end
  end
  return false
end

local function patch_sprite(sprite, depth)
  if type(sprite) ~= "table" or depth > 24 then
    return
  end
  if visited[sprite] then
    return
  end
  visited[sprite] = true

  if uses_eb_graphics(sprite) then
    sprite.allow_forced_downscale = true
    patched = patched + 1
  end

  for _, value in pairs(sprite) do
    if type(value) == "table" then
      patch_sprite(value, depth + 1)
    end
  end
end

for _, prototypes in pairs(data.raw) do
  for _, prototype in pairs(prototypes) do
    if type(prototype) == "table" then
      visited = {}
      patch_sprite(prototype, 0)
    end
  end
end

log("[explosive-biter-optimizations] Marked " .. patched .. " Explosive Biters sprites for forced downscale.")
