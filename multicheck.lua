--[[
  multicheck.lua - GTNH multiblock checklist (Stone through IV) for OpenComputers
  Based on the GTNH wiki (2.9). Progress is saved to disk after every change.

  Usage:   multicheck [savefile]      (default save file: /home/multiblocks.cfg)

  Controls
    Up / Down, PgUp / PgDn, Home / End   move selection
    Left / Right, Tab                    switch tier
    Space / Enter                        toggle the selected multiblock
    A                                    mark whole tier done (or clear it if already all done)
    H                                    hide / show completed multiblocks
    Q                                    quit
    Mouse: left-click an item to toggle it, right-click to select it,
           click a tier in the sidebar to open it, scroll wheel to scroll.
]]

local component     = require("component")
local event         = require("event")
local keyboard      = require("keyboard")
local serialization = require("serialization")
local term          = require("term")
local unicode       = require("unicode")

if not component.isAvailable("gpu") then
  io.stderr:write("multicheck: a graphics card and screen are required.\n")
  return
end
local gpu = component.gpu

local args = {...}
local SAVE_FILE = args[1] or "/home/multiblocks.cfg"

---------------------------------------------------------------------------
-- Data: { name, note }  (note is optional, shown dimmed after the name)
---------------------------------------------------------------------------
local TIERS = {
  { name = "Stone", title = "Stone / Pre-Steam", items = {
    { "Coke Oven" },
    { "Windmill" },
    { "Smeltery", "Tinkers' Construct" },
    { "Water Tank", "Railcraft" },
    { "Vending Machine" },
  }},
  { name = "Steam", title = "Steam Age", items = {
    { "Bricked Blast Furnace" },
    { "Charcoal Pile Igniter" },
    { "Steam Grinder", "macerator" },
    { "Steam Squasher", "compressor" },
    { "Steam Presser", "forge hammer" },
    { "Steam Separator", "centrifuge" },
    { "Steam Purifier", "ore washer" },
    { "Steam Blender", "mixer" },
    { "Steam Fuser", "alloy smelter" },
    { "Steam Hearth", "furnace, replaces Steam Oven" },
    { "Water Pump" },
    { "Railcraft Boiler" },
    { "Railcraft Tank" },
  }},
  { name = "LV", title = "Low Voltage", items = {
    { "Electric Blast Furnace" },
    { "Electric Air Filter" },
    { "Multifarm", "Forestry" },
  }},
  { name = "MV", title = "Medium Voltage", items = {
    { "Multi Smelter" },
    { "Pyrolyse Oven" },
    { "Large Bronze Boiler" },
    { "Fluid Drilling Rig I" },
    { "ExxonMobil Chemical Plant" },
    { "Concrete Backfiller I" },
    { "Advanced Coke Oven" },
    { "Algae Farm" },
    { "Industrial Farm", "CropsNH" },
    { "Research Completer" },
    { "Alveary", "Forestry" },
  }},
  { name = "HV", title = "High Voltage", items = {
    { "Vacuum Freezer" },
    { "Implosion Compressor" },
    { "Distillation Tower" },
    { "Oil Cracking Unit" },
    { "Large Chemical Reactor" },
    { "Cleanroom" },
    { "Large Steam Turbine" },
    { "Large Steel Boiler" },
    { "Fluid Drilling Rig II" },
    { "Large Sifter" },
    { "LATEX", "cable coater" },
    { "TurboCan Pro", "canner" },
    { "Bacterial Vat" },
    { "Big Barrel Brewery" },
    { "Dissection Apparatus" },
    { "Microwave Grinder" },
    { "Tesla Tower" },
    { "Solar Factory" },
    { "TFFT", "fluid tank" },
    { "Mana Fountain" },
    { "Advanced Alchemical Furnace", "Thaumcraft" },
  }},
  { name = "EV", title = "Extreme Voltage", items = {
    { "Large Gas Turbine" },
    { "Large Combustion Engine" },
    { "Large Heat Exchanger" },
    { "Large Semifluid Burner" },
    { "Large Neutralization Engine" },
    { "Solid-Oxide Fuel Cell" },
    { "Large HP Steam Turbine" },
    { "Large Titanium Boiler" },
    { "Fluid Drilling Rig III" },
    { "Concrete Backfiller II" },
    { "Lapotronic Supercapacitor" },
    { "Ore Drilling Plant I" },
    { "Industrial Centrifuge" },
    { "Industrial Maceration Stack" },
    { "Ore Washing Plant" },
    { "Large Thermal Refinery" },
    { "Industrial Bending Machine" },
    { "Industrial Forming Press" },
    { "Industrial Precision Lathe" },
    { "Large Electric Compressor" },
    { "Large Fluid Extractor" },
    { "Industrial Coke Oven" },
    { "Industrial 3D Copying Machine" },
    { "Dissolution Tank" },
    { "Coolant Tower" },
    { "Extreme Entity Crusher" },
    { "Fountain of Alchemy" },
    { "Fluid Reactor", "IC2 nuclear" },
    { "Vacuum Reactor", "IC2 nuclear" },
  }},
  { name = "IV", title = "Insane Voltage", items = {
    -- Assembly / crafting
    { "Assembly Line" },
    { "Advanced Assembly Line" },
    { "Precise Auto-Assembler MT-3662" },
    { "Large Molecular Assembler" },
    -- GT++ processing
    { "Industrial Electrolyzer" },
    { "Industrial Mixing Machine" },
    { "Industrial Extrusion Machine" },
    { "Industrial Cutting Factory" },
    { "Industrial Wire Factory" },
    { "Industrial Chemical Bath" },
    { "Industrial Sledgehammer" },
    { "Magnetic Flux Exhibitor" },
    { "Mass Solidifier" },
    { "Amazon Warehousing Depot" },
    -- Smelting / cooling
    { "Volcanus", "advanced EBF" },
    { "Cryogenic Freezer", "advanced vacuum freezer" },
    { "Alloy Blast Smelter" },
    { "Zyngen", "alloy smelter" },
    { "Density^2", "implosion compressor" },
    -- Chemistry / fluids
    { "Dangote Distillus" },
    { "Digester" },
    { "Thermic Heating Device" },
    { "Hyper-Intensity Laser Engraver" },
    { "Boldarnator", "rock breaker" },
    { "YOTTank" },
    -- Power
    { "XL Turbo Steam Turbine" },
    { "Extreme Combustion Engine" },
    { "Universal Chemical Fuel Engine" },
    { "Rocketdyne F-1A Engine" },
    { "Thermal Boiler" },
    { "Solar Tower" },
    { "Deep Earth Heating Pump" },
    { "Large Tungstensteel Boiler" },
    -- Nuclear
    { "Liquid Fluoride Thorium Reactor" },
    { "Thorium High Temperature Reactor" },
    { "High Temperature Gas-Cooled Reactor" },
    { "Nuclear Salt Processing Plant" },
    { "Reactor Fuel Processing Plant" },
    { "Decay Warehouse" },
    -- Farming / resources
    { "Extreme Industrial Greenhouse" },
    { "Tree Growth Simulator" },
    { "Zhuhai Fishing Port" },
    { "Ore Drilling Plant II" },
    -- Utility / magic
    { "Drone Centre" },
    { "Large Essentia Smeltery" },
    { "Fountain of Conjuration" },
  }},
  { name = "Misc", title = "Other mods (no GT tier)", items = {
    { "Thaumatorium", "Thaumcraft" },
    { "Portal to Alfheim", "Botania" },
    { "Ritual of Binding", "Blood Magic" },
  }},
}

-- normalise item tables to { name = ..., note = ... }
for _, t in ipairs(TIERS) do
  for i, it in ipairs(t.items) do
    t.items[i] = { name = it[1], note = it[2] }
  end
end

---------------------------------------------------------------------------
-- Colours (falls back to inverse video on monochrome screens)
---------------------------------------------------------------------------
local COLOR = gpu.getDepth() > 1
local C
if COLOR then
  C = { bg = 0x000000, fg = 0xFFFFFF, dim = 0x888888, head = 0x1E3A5F, headFg = 0xFFFFFF,
        side = 0x1A1A1A, sel = 0x2D5DA8, selFg = 0xFFFFFF, done = 0x55FF55,
        status = 0x222222, warn = 0xFF5555 }
else
  C = { bg = 0x000000, fg = 0xFFFFFF, dim = 0xFFFFFF, head = 0xFFFFFF, headFg = 0x000000,
        side = 0x000000, sel = 0xFFFFFF, selFg = 0x000000, done = 0xFFFFFF,
        status = 0x000000, warn = 0xFFFFFF }
end
local TIERCOL = { Stone = 0xAAAAAA, Steam = 0xCC8844, LV = 0xDDDDDD, MV = 0xFF9933,
                  HV = 0xFFFF55, EV = 0xAA55FF, IV = 0x5599FF, Misc = 0x55FFAA }
local function tierColor(t) return COLOR and (TIERCOL[t.name] or C.fg) or C.fg end

local function setc(fg, bg)
  gpu.setBackground(bg or C.bg)
  gpu.setForeground(fg or C.fg)
end

---------------------------------------------------------------------------
-- State / persistence
---------------------------------------------------------------------------
local done = {}
local status = ""

local function key(t, it) return t.name .. "|" .. it.name end

local function loadState()
  local f = io.open(SAVE_FILE, "r")
  if not f then return end
  local s = f:read("*a")
  f:close()
  local ok, data = pcall(serialization.unserialize, s)
  if ok and type(data) == "table" then
    done = data
  else
    status = "Save file unreadable, starting fresh"
  end
end

local function saveState()
  local f, err = io.open(SAVE_FILE, "w")
  if not f then
    status = "Save failed: " .. tostring(err)
    return
  end
  f:write(serialization.serialize(done))
  f:close()
end

local function tierCount(t)
  local n = 0
  for _, it in ipairs(t.items) do
    if done[key(t, it)] then n = n + 1 end
  end
  return n, #t.items
end

---------------------------------------------------------------------------
-- View state
---------------------------------------------------------------------------
local cur, sel, scroll, hideDone = 1, 1, 0, false
local SW = 18   -- sidebar width

local function layout()
  local W, H = gpu.getResolution()
  local listX = SW + 2
  local listW = W - SW - 1
  local top, bottom = 3, H - 2
  return W, H, listX, listW, top, bottom
end

local function visible()
  local t, v = TIERS[cur], {}
  for _, it in ipairs(t.items) do
    if not (hideDone and done[key(t, it)]) then v[#v + 1] = it end
  end
  return v
end

local function clamp()
  local v = visible()
  local _, _, _, _, top, bottom = layout()
  local listH = math.max(1, bottom - top + 1)
  if sel > #v then sel = #v end
  if sel < 1 then sel = 1 end
  if sel <= scroll then scroll = sel - 1 end
  if sel > scroll + listH then scroll = sel - listH end
  local maxScroll = math.max(0, #v - listH)
  if scroll > maxScroll then scroll = maxScroll end
  if scroll < 0 then scroll = 0 end
  return v
end

-- truncate / pad a string to exactly w characters
local function fit(s, w)
  if w <= 0 then return "" end
  local len = unicode.len(s)
  if len > w then return unicode.sub(s, 1, math.max(0, w - 1)) .. "~" end
  return s .. string.rep(" ", w - len)
end

---------------------------------------------------------------------------
-- Drawing
---------------------------------------------------------------------------
local function drawHeader(W)
  local d, total = 0, 0
  for _, t in ipairs(TIERS) do
    local a, b = tierCount(t)
    d, total = d + a, total + b
  end
  local pct = total > 0 and math.floor(d * 100 / total) or 0

  setc(C.headFg, C.head)
  gpu.fill(1, 1, W, 1, " ")
  local title = " GTNH Multiblock Checklist (to IV)"
  local info = string.format(" %d/%d  %3d%% ", d, total, pct)
  local barW = math.min(24, W - unicode.len(title) - #info - 4)
  local right = info
  if barW >= 5 then
    local filled = math.floor(barW * d / math.max(1, total) + 0.5)
    right = "[" .. string.rep("=", filled) .. string.rep("-", barW - filled) .. "]" .. info
  end
  gpu.set(1, 1, fit(title, W))
  if unicode.len(right) < W - unicode.len(title) then
    gpu.set(W - unicode.len(right) + 1, 1, right)
  end

  setc(C.dim, C.bg)
  gpu.fill(1, 2, W, 1, " ")
end

local function drawSidebar(top, bottom)
  setc(C.fg, C.side)
  gpu.fill(1, top, SW, bottom - top + 1, " ")
  for i, t in ipairs(TIERS) do
    local y = top + i - 1
    if y > bottom then break end
    local a, b = tierCount(t)
    local line = string.format("%s%-6s %3d/%-3d", i == cur and ">" or " ", t.name, a, b)
    if i == cur then
      setc(C.selFg, C.sel)
    else
      setc((a == b and b > 0) and C.done or tierColor(t), C.side)
    end
    gpu.set(1, y, fit(line, SW))
  end
  setc(C.dim, C.bg)
  for y = top, bottom do gpu.set(SW + 1, y, "|") end
end

local function drawList(v, listX, listW, top, bottom)
  local t = TIERS[cur]
  local listH = bottom - top + 1
  setc(C.fg, C.bg)
  gpu.fill(listX, top, listW, listH, " ")

  if #v == 0 then
    setc(C.done, C.bg)
    gpu.set(listX + 1, top, fit(hideDone and "Everything in this tier is done! (H shows completed)"
                                          or "No multiblocks in this tier.", listW - 1))
    return
  end

  for row = 0, listH - 1 do
    local idx = scroll + row + 1
    local it = v[idx]
    if not it then break end
    local y = top + row
    local isDone = done[key(t, it)] and true or false
    local isSel = idx == sel
    local bg = isSel and C.sel or C.bg
    local main = (isDone and " [x] " or " [ ] ") .. it.name
    local fgMain = isSel and C.selFg or (isDone and C.done or C.fg)

    setc(fgMain, bg)
    gpu.fill(listX, y, listW, 1, " ")
    gpu.set(listX, y, fit(main, listW))

    local used = unicode.len(main)
    if it.note and used + 4 < listW then
      setc(isSel and C.selFg or C.dim, bg)
      gpu.set(listX + used, y, fit("  (" .. it.note .. ")", listW - used))
    end
  end

  -- scroll hints
  setc(C.dim, C.bg)
  if scroll > 0 then gpu.set(listX + listW - 1, top, "^") end
  if scroll + listH < #v then gpu.set(listX + listW - 1, bottom, "v") end
end

local function drawFooter(W, H)
  local t = TIERS[cur]
  local a, b = tierCount(t)
  setc(tierColor(t), C.status)
  gpu.fill(1, H - 1, W, 1, " ")
  local left = string.format(" %s - %d/%d complete%s", t.title, a, b, hideDone and "  [hiding done]" or "")
  gpu.set(1, H - 1, fit(left, W))
  if status ~= "" then
    setc(C.warn, C.status)
    local s = status .. " "
    if unicode.len(s) < W - unicode.len(left) then gpu.set(W - unicode.len(s) + 1, H - 1, s) end
  end

  setc(C.headFg, C.head)
  gpu.fill(1, H, W, 1, " ")
  gpu.set(1, H, fit(" Up/Dn move  Lt/Rt tier  Space toggle  A all  H hide done  Q quit", W))
end

local function draw()
  local W, H, listX, listW, top, bottom = layout()
  local v = clamp()
  drawHeader(W)
  drawSidebar(top, bottom)
  drawList(v, listX, listW, top, bottom)
  drawFooter(W, H)
end

---------------------------------------------------------------------------
-- Actions
---------------------------------------------------------------------------
local function toggle(it)
  local k = key(TIERS[cur], it)
  done[k] = (not done[k]) or nil
  saveState()
end

local function toggleTier()
  local t = TIERS[cur]
  local a, b = tierCount(t)
  local mark = a < b
  for _, it in ipairs(t.items) do done[key(t, it)] = mark or nil end
  saveState()
  status = mark and ("Marked all " .. t.name .. " done") or ("Cleared " .. t.name)
end

local function switchTier(delta)
  cur = (cur - 1 + delta) % #TIERS + 1
  sel, scroll = 1, 0
end

---------------------------------------------------------------------------
-- Input
---------------------------------------------------------------------------
local running = true
local K = keyboard.keys

local function onKey(char, code)
  local v = visible()
  local _, _, _, _, top, bottom = layout()
  local page = math.max(1, bottom - top)
  local c = (char and char > 0) and string.lower(string.char(char)) or ""
  status = ""

  if code == K.up then sel = sel - 1
  elseif code == K.down then sel = sel + 1
  elseif code == K.pageUp then sel = sel - page
  elseif code == K.pageDown then sel = sel + page
  elseif code == K.home then sel = 1
  elseif code == K["end"] then sel = #v
  elseif code == K.left then switchTier(-1)
  elseif code == K.right or code == K.tab then switchTier(1)
  elseif code == K.space or code == K.enter or code == K.numpadenter then
    if v[sel] then toggle(v[sel]) end
  elseif c == "a" then toggleTier()
  elseif c == "h" then hideDone = not hideDone; sel, scroll = 1, 0
  elseif c == "q" then running = false
  else return false end
  return true
end

local function onTouch(x, y, button)
  local _, _, listX, _, top, bottom = layout()
  if y < top or y > bottom then return false end
  if x <= SW then
    local i = y - top + 1
    if TIERS[i] then cur, sel, scroll = i, 1, 0; status = "" return true end
    return false
  elseif x >= listX then
    local v = visible()
    local idx = scroll + (y - top) + 1
    if v[idx] then
      sel = idx
      if button == 0 then toggle(v[idx]) end
      status = ""
      return true
    end
  end
  return false
end

local function onScroll(direction)
  local v = visible()
  local _, _, _, _, top, bottom = layout()
  local listH = bottom - top + 1
  scroll = math.max(0, math.min(math.max(0, #v - listH), scroll - direction * 3))
  if sel <= scroll then sel = scroll + 1 end
  if sel > scroll + listH then sel = scroll + listH end
  return true
end

---------------------------------------------------------------------------
-- Main
---------------------------------------------------------------------------
local W0, H0 = gpu.getResolution()
if W0 < 50 or H0 < 12 then
  io.stderr:write("multicheck: screen too small (need at least 50x12, tier 2 screen or better).\n")
  return
end

loadState()
local oldFg, oldBg = gpu.getForeground(), gpu.getBackground()

local ok, err = pcall(function()
  local redraw = true
  while running do
    if redraw then draw() end
    local e = { event.pull() }
    local name = e[1]
    if name == "key_down" then
      redraw = onKey(e[3], e[4])
    elseif name == "touch" then
      redraw = onTouch(e[3], e[4], e[5])
    elseif name == "scroll" then
      redraw = onScroll(e[5])
    elseif name == "screen_resized" then
      redraw = true
    else
      redraw = false
    end
  end
end)

gpu.setForeground(oldFg)
gpu.setBackground(oldBg)
term.clear()
if not ok and not tostring(err):find("interrupted") then
  io.stderr:write("multicheck crashed: " .. tostring(err) .. "\n")
else
  print("Checklist saved to " .. SAVE_FILE)
end
