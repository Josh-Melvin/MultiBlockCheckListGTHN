--[[
  multicheck.lua - GTNH multiblock checklist (Stone through UXV) for OpenComputers
  Based on the GTNH wiki (2.9). Progress is saved to disk after every change.

  Usage:   multicheck [savefile]      (default save file: /home/multiblocks.cfg)

  Controls
    Up / Down, PgUp / PgDn, Home / End   move selection
    Left / Right, Tab                    switch tier
    Space / Enter                        toggle the selected multiblock
    A                                    mark whole tier done (or clear it if already all done)
    H                                    hide / show completed multiblocks
    + / -                                bigger / smaller text (changes screen resolution)
    F                                    fit text to the screen's shape (no black borders)
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
  { name = "LuV", title = "Ludicrous Voltage", items = {
    -- Fusion / power
    { "Fusion Reactor", "Mk I" },
    { "Compact Fusion Reactor" },
    { "Large Plasma Turbine" },
    { "XL Turbo Gas Turbine" },
    { "Large SC Steam Turbine" },
    { "Extreme Heat Exchanger" },
    { "Whakawhiti Wera XL", "heat exchanger" },
    -- Processing
    { "Circuit Assembly Line" },
    { "Industrial Arc Furnace" },
    { "Industrial Autoclave" },
    { "Utupu-Tanuri", "vacuum furnace / dehydrator" },
    { "Mega Chemical Reactor" },
    { "Mega Distillation Tower" },
    { "Mega Oil Cracker" },
    { "Neutron Activator" },
    { "Molecular Transformer" },
    { "IsaMill Grinding Machine" },
    { "Flotation Cell Regulator" },
    { "Sparge Tower" },
    -- Resources
    { "Ore Drilling Plant III" },
    { "Planetary Gas Siphon" },
    { "Ender Quarry", "Extra Utilities" },
    -- Water Line (grades 1-2)
    { "Water Purification Plant", "Water Line controller" },
    { "Clarifier Purification Unit", "grade 1" },
    { "Ozonation Purification Unit", "grade 2" },
  }},
  { name = "ZPM", title = "Zero Point Module", items = {
    { "Exothermic Hearth", "replaces Mega EBF" },
    { "Endothermic Fridge", "replaces Mega Vacuum Freezer" },
    { "Large Scale Auto-Assembler v1.01" },
    { "Hot Isostatic Pressurization Unit" },
    { "Spinmatron-2737", "centrifuge" },
    { "Elemental Duplicator", "replicator" },
    { "Energy Infuser" },
    { "Active Transformer" },
    { "Data Bank" },
    { "Large Naquadah Reactor" },
    { "XL Turbo Plasma Turbine" },
    { "Ore Drilling Plant IV" },
    { "Void Miner" },
    -- Beam Line
    { "Source Chamber", "Beam Line" },
    { "Linear Accelerator", "Beam Line" },
    { "Synchrotron", "Beam Line" },
    { "Target Chamber", "Beam Line" },
    -- Water Line (grades 3-4)
    { "Flocculation Purification Unit", "grade 3" },
    { "PH Neutralization Purification Unit", "grade 4" },
  }},
  { name = "UV", title = "Ultimate Voltage", items = {
    { "Component Assembly Line" },
    { "PCB Factory" },
    { "Nano Forge" },
    { "Mega Alloy Blast Smelter" },
    { "Neutronium Compressor" },
    { "Matter Fabrication CPU" },
    { "Industrial Apicultural Acclimatiser and Drone Domestication Station", "mega apiary" },
    { "Large Hadron Collider", "replaces Cyclotron" },
    { "Research Station" },
    { "Quantum Computer" },
    { "Network Switch With QoS" },
    { "Space Elevator" },
    { "Matter Manipulator Quantum Uplink" },
    -- Beam Line additions
    { "Beam Crafter" },
    { "Beam Mirror" },
    { "Beam Splitter" },
    { "Beam Stabilizer" },
    -- Water Line (grades 5-6)
    { "Extreme Temperature Fluctuation Purification Unit", "grade 5" },
    { "High Energy Laser Purification Unit", "grade 6" },
  }},
  { name = "UHV", title = "Ultra High Voltage", items = {
    { "Electric Implosion Compressor" },
    { "Integrated Ore Factory" },
    { "Naquadah Fuel Refinery" },
    { "Miniature Wormhole Generator" },
    { "Draconic Evolution Fusion Crafter" },
  }},
  { name = "UEV", title = "Ultra Excessive Voltage", items = {
    { "Dimensionally Transcendent Plasma Forge" },
    { "Quantum Force Transformer" },
    { "Exo-Foundry" },
    { "Nanochip Assembly Complex" },
    { "Residual Decontaminant Degasser Purification Unit", "grade 7" },
    { "Absolute Baryonic Perfection Purification Unit", "grade 8" },
  }},
  { name = "UIV", title = "Ultra Immense Voltage", items = {
    { "Forge of the Gods" },
    { "Transcendent Plasma Mixer" },
    { "Pseudostable Black Hole Containment Field" },
    { "Semi-Stable Antimatter Stabilization Sequencer" },
    { "Shielded Lagrangian Annihilation Matrix" },
    { "Dyson Swarm Ground Unit" },
    { "Draconic Reactor", "Draconic Evolution" },
    -- Bose-Einstein Condensate Line
    { "BEC Entanglement Apparatus", "BEC Line" },
    { "BEC Containment Field", "BEC Line" },
    { "BEC Maxwell Gate", "BEC Line" },
    { "BEC Teleportation Node", "BEC Line" },
    { "BEC Observation Array", "BEC Line" },
  }},
  { name = "UMV", title = "Ultra Magnificent Voltage", items = {
    { "Eye of Harmony" },
  }},
  { name = "UXV", title = "Ultra Extreme Voltage", items = {
    { "Stargate", "SGCraft" },
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
                  HV = 0xFFFF55, EV = 0xAA55FF, IV = 0x5599FF, LuV = 0xFF77FF,
                  ZPM = 0x55FFFF, UV = 0x77FF77, UHV = 0xFF5555, UEV = 0xAAFF33,
                  UIV = 0xFFAA00, UMV = 0xFF6699, UXV = 0xFFFFFF, Misc = 0x55FFAA }
local function tierColor(t) return COLOR and (TIERCOL[t.name] or C.fg) or C.fg end

local function setc(fg, bg)
  gpu.setBackground(bg or C.bg)
  gpu.setForeground(fg or C.fg)
end

---------------------------------------------------------------------------
-- State / persistence
---------------------------------------------------------------------------
local done = {}      -- also holds done.__settings = { textSize = n, fit = bool }
local status = ""

local function key(t, it) return t.name .. "|" .. it.name end

local function settings()
  if type(done.__settings) ~= "table" then done.__settings = {} end
  return done.__settings
end

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
local SW = 18          -- sidebar width (shrinks to 12 on narrow resolutions)
local MIN_W, MIN_H = 40, 12

local function layout()
  local W, H = gpu.getResolution()
  SW = (W < 60) and 12 or 18
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
  local title = " GTNH Multiblock Checklist"
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

local sideScroll = 0   -- first tier shown in the sidebar when they don't all fit

local function drawSidebar(top, bottom)
  local rows = bottom - top + 1
  if cur <= sideScroll then sideScroll = cur - 1 end
  if cur > sideScroll + rows then sideScroll = cur - rows end
  sideScroll = math.max(0, math.min(sideScroll, #TIERS - rows))

  setc(C.fg, C.side)
  gpu.fill(1, top, SW, rows, " ")
  for row = 0, rows - 1 do
    local i = sideScroll + row + 1
    local t = TIERS[i]
    if not t then break end
    local y = top + row
    local a, b = tierCount(t)
    local fmt = (SW < 18) and "%s%-5s%2d/%-2d" or "%s%-6s %3d/%-3d"
    local line = string.format(fmt, i == cur and ">" or " ", t.name, a, b)
    if i == cur then
      setc(C.selFg, C.sel)
    else
      setc((a == b and b > 0) and C.done or tierColor(t), C.side)
    end
    gpu.set(1, y, fit(line, SW))
  end
  setc(C.dim, C.bg)
  for y = top, bottom do gpu.set(SW + 1, y, "|") end
  if sideScroll > 0 then gpu.set(SW + 1, top, "^") end
  if sideScroll + rows < #TIERS then gpu.set(SW + 1, bottom, "v") end
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
  local help = " Up/Dn move  Lt/Rt tier  Space toggle  A all  H hide done  +/- text  F fit  Q quit"
  if W < 86 then help = " Arrows move/tier  Spc toggle  A all  H hide  +/- text  F fit  Q quit" end
  if W < 70 then help = " Spc toggle A all H hide +/- text F fit Q quit" end
  gpu.set(1, H, fit(help, W))
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
-- Text size: OpenComputers scales text to fill the screen, so a lower
-- resolution means bigger characters. Level 1 = smallest text (max res).
---------------------------------------------------------------------------
local SCALES = { 1, 0.8, 2/3, 0.5, 0.4, 1/3, 0.25, 0.2 }

-- width/height (in characters) that matches the physical screen's shape;
-- characters are about twice as tall as they are wide
local function screenRatio()
  local addr = gpu.getScreen and gpu.getScreen()
  if not addr then return nil end
  local ok, scr = pcall(component.proxy, addr)
  if not ok or not scr or not scr.getAspectRatio then return nil end
  local aw, ah = scr.getAspectRatio()
  if not aw or not ah or ah == 0 then return nil end
  return (aw * 2) / ah
end

local function sizeLevels()
  local mw, mh = gpu.maxResolution()
  local ratio = settings().fit and screenRatio() or nil
  local levels, seen = {}, {}
  for _, s in ipairs(SCALES) do
    local w, h = mw * s, mh * s
    if ratio then
      if w / h > ratio then w = h * ratio else h = w / ratio end
    end
    w = math.min(mw, math.max(MIN_W, math.floor(w)))
    h = math.min(mh, math.max(MIN_H, math.floor(h)))
    local id = w .. "x" .. h
    if not seen[id] then
      seen[id] = true
      levels[#levels + 1] = { w, h }
    end
  end
  return levels
end

-- the level closest to the current resolution
local function currentLevel(levels)
  local W = gpu.getResolution()
  local best, bestDiff = 1, math.huge
  for i, l in ipairs(levels) do
    local d = math.abs(l[1] - W)
    if d < bestDiff then best, bestDiff = i, d end
  end
  return best
end

local function applyTextSize(level)
  local levels = sizeLevels()
  level = math.max(1, math.min(#levels, level))
  local w, h = levels[level][1], levels[level][2]
  local cw, ch = gpu.getResolution()
  if cw ~= w or ch ~= h then gpu.setResolution(w, h) end
  settings().textSize = level
  status = string.format("Text size %d/%d (%dx%d)%s", level, #levels, w, h,
                         settings().fit and " fit" or "")
end

local function changeTextSize(delta)
  local levels = sizeLevels()
  local s = settings()
  local level = s.textSize or currentLevel(levels)
  local target = math.max(1, math.min(#levels, level + delta))
  applyTextSize(target)
  if target == level then
    status = status .. (delta > 0 and "  (largest)" or "  (smallest)")
  end
  saveState()
end

local function toggleFit()
  local s = settings()
  if not s.fit and not screenRatio() then
    status = "Can't read screen shape"
    return
  end
  s.fit = not s.fit
  applyTextSize(s.textSize or 1)
  saveState()
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
  elseif c == "+" or c == "=" or code == K.add then changeTextSize(1)
  elseif c == "-" or c == "_" or code == K.subtract then changeTextSize(-1)
  elseif c == "f" then toggleFit()
  elseif c == "q" then running = false
  else return false end
  return true
end

local function onTouch(x, y, button)
  local _, _, listX, _, top, bottom = layout()
  if y < top or y > bottom then return false end
  if x <= SW then
    local i = sideScroll + (y - top) + 1
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
local MW, MH = gpu.maxResolution()
if MW < MIN_W or MH < MIN_H then
  io.stderr:write(string.format("multicheck: screen too small (need at least %dx%d).\n", MIN_W, MIN_H))
  return
end

loadState()
local oldFg, oldBg = gpu.getForeground(), gpu.getBackground()
local oldW, oldH = gpu.getResolution()

-- restore the saved text size, or make sure the current resolution is usable
if settings().textSize then
  applyTextSize(settings().textSize)
elseif oldW < MIN_W or oldH < MIN_H then
  applyTextSize(1)
end
status = ""

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
pcall(gpu.setResolution, oldW, oldH)   -- give the shell its normal text size back
term.clear()
if not ok and not tostring(err):find("interrupted") then
  io.stderr:write("multicheck crashed: " .. tostring(err) .. "\n")
else
  print("Checklist saved to " .. SAVE_FILE)
end
