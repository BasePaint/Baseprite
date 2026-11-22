--      ___         ___          ___          ___          ___          ___               ___          ___     
--     /\  \       /\  \        /\  \        /\  \        /\  \        /\  \        ___  /\  \        /\  \    
--    /::\  \     /::\  \      /::\  \      /::\  \      /::\  \      /::\  \      /\  \ \:\  \      /::\  \   
--   /:/\:\  \   /:/\:\  \    /:/\ \  \    /:/\:\  \    /:/\:\  \    /:/\:\  \     \:\  \ \:\  \    /:/\:\  \  
--  /::\~\:\__\ /::\~\:\  \  _\:\~\ \  \  /::\~\:\  \  /::\~\:\  \  /::\~\:\  \    /::\__\/::\  \  /::\~\:\  \ 
-- /:/\:\ \:|__/:/\:\ \:\__\/\ \:\ \ \__\/:/\:\ \:\__\/:/\:\ \:\__\/:/\:\ \:\__\__/:/\/__/:/\:\__\/:/\:\ \:\__\
-- \:\~\:\/:/  |/__\:\/:/  /\:\ \:\ \/__/\:\~\:\ \/__/\/__\:\/:/  /\/_|::\/:/  /\/:/  / /:/  \/__/\:\~\:\ \/__/
--  \:\ \::/  /     \::/  /  \:\ \:\__\   \:\ \:\__\       \::/  /    |:|::/  /\::/__/ /:/  /      \:\ \:\__\  
--   \:\/:/  /      /:/  /    \:\/:/  /    \:\ \/__/        \/__/     |:|\/__/  \:\__\ \/__/        \:\ \/__/  
--    \::/__/      /:/  /      \::/  /      \:\__\                    |:|  |     \/__/               \:\__\    
--     ~~          \/__/        \/__/        \/__/                     \|__|                          \/__/    

-- Baseprite by Creamy! 🐸💙🖌️ v2.5

-- fetch palette from "basepaint.xyz/api/theme/day#"
local function fetchBasepaintPalette(day)
  local src = debug.getinfo(1, "S").source
  local scriptPath = src:match("@(.*[\\/])") -- credits to numo.eth on this line fix
  local tmpPath = scriptPath .. "basepaint_theme_data.json"
  local url = "https://basepaint.xyz/api/theme/" .. day
  local curl = 'curl -s "' .. url .. '" -o "' .. tmpPath .. '"'
  os.execute(curl)

  local f = io.open(tmpPath, "r")
  if not f then
    app.alert("Download failed.")
    return nil
  end

  local contents = f:read("*a")
  f:close()

  local hexes = {}
  for hex in contents:gmatch('"#(%x%x%x%x%x%x)"') do
    table.insert(hexes, "#" .. hex:upper())
  end
  if #hexes == 0 then
    app.alert("No valid hex codes found.")
    return nil
  end

  local colorList = {}
  for _, hex in ipairs(hexes) do
    local r = tonumber(hex:sub(2,3), 16)
    local g = tonumber(hex:sub(4,5), 16)
    local b = tonumber(hex:sub(6,7), 16)
    table.insert(colorList, { color = Color{ r=r, g=g, b=b, a=255 } })
  end

  return colorList
end

-- calculate current Basepaint canvas date
local function getCurrentBasepaintDay()
  local baseStart = os.time{year=2023, month=8, day=8, hour=16, min=41, sec=5} -- Birthday!
  local nowUTC = os.time(os.date("!*t"))
  local secondsPerDay = 60 * 60 * 24
  local diff = nowUTC - baseStart
  return math.floor(diff / secondsPerDay)
end

local function getScriptFolder()
  local src = debug.getinfo(1, "S").source
  return src:match("@(.*[\\/])") or "./"
end

local function shell_quote(s)
  s = tostring(s or "")
  s = s:gsub('"', '\\\"')
  return '"' .. s .. '"'
end

local function file_nonempty(path)
  local f = io.open(path, "rb")
  if not f then return false end
  local bytes = f:read("*a")
  f:close()
  return bytes ~= nil and #bytes > 64
end

local function loadImage(path)
  local ok, img = pcall(function()
    return Image{ fromFile = path }
  end)
  if not ok or not img then
    return nil, "Failed to load PNG into Aseprite Image:\n" .. tostring(path)
  end
  return img, nil
end

local function ensureSprite(img)
  local spr = app.activeSprite
  if spr then return spr end
  spr = Sprite(img.width, img.height, ColorMode.RGB)
  app.activeSprite = spr
  return spr
end

local function insertAsNewLayer(day, img)
  local spr = ensureSprite(img)
  local frame = spr.frames[1]
  local layer = spr:newLayer()
  layer.name = "Day " .. tostring(day)
  local cel = spr:newCel(layer, frame)
  cel.image = img
  -- Locked, so it isn't painted on by accident and isn't streamed as the painter's draft.
  layer.isEditable = false
  app.activeSprite = spr
  app.activeLayer = layer
  app.activeCel = cel
  pcall(function() app.command.SelectAll() end)
end

local function exec_ok(a, b, c)
  if type(a) == "boolean" then return a end
  if type(c) == "number" then return c == 0 end
  if type(a) == "number" then return a == 0 end
  return false
end

local function downloadCanvasPNG(day, outPath)
  local url = "https://basepaint.xyz/api/art/image?day=" .. day .. "&scale=1"
  local cmd = 'curl -L -s ' .. shell_quote(url) .. ' -o ' .. shell_quote(outPath)
  local r1, r2, r3 = os.execute(cmd)
  if file_nonempty(outPath) then
    return true, nil
  end
  if not exec_ok(r1, r2, r3) then
    return false, "curl command failed AND output file wasn't created."
  end
  return false, "Download produced an invalid/empty file."
end

local function parseDayInput(raw)
  if not raw then return nil end
  local s = tostring(raw)
  s = s:lower()
  s = s:gsub("%s+", "")
  s = s:gsub("day", "")
  s = s:gsub("#", "")
  local digits = s:match("(%d+)")
  if not digits then return nil end
  return tonumber(digits)
end


-- parse Frame # Input Field
local function parseFrameInput(input, sprite)
  local str = tostring(input):lower():gsub("frame", ""):gsub("%s+", "")
  local index = tonumber(str) or 1

  if index > #sprite.frames then
    app.alert("Frame " .. index .. " not found. Using last available frame: " .. #sprite.frames)
    return #sprite.frames
  elseif index < 1 then
    app.alert("Frame number must be 1 or higher. Defaulting to Frame 1.")
    return 1
  end

  return index
end

-- minimal rtf-to-plain extractor
  local function rtfToPlain(rtf)
    local out = {}
    local i, n = 1, #rtf
    while i <= n do
      local c = rtf:sub(i,i)
      if c == "\\" then
        local nxt = rtf:sub(i+1,i+1)
        if nxt == "'" then
          -- hex escape \'hh
          local hh = rtf:sub(i+2,i+3)
          local byte = tonumber(hh, 16)
          if byte then table.insert(out, string.char(byte)); i = i + 4 else i = i + 2 end
        elseif nxt == "{" or nxt == "}" or nxt == "\\" then
          -- escaped literal
          table.insert(out, nxt); i = i + 2
        else
          -- control word: \word[#][-#][space?]
          local j = i + 1
          while j<=n and rtf:sub(j,j):match("%a") do j = j + 1 end
          while j<=n and rtf:sub(j,j):match("[-%d]") do j = j + 1 end
          if rtf:sub(j,j) == " " then j = j + 1 end
          i = j
        end
      elseif c == "{" or c == "}" then
        -- group braces (don’t output)
        i = i + 1
      else
        table.insert(out, c); i = i + 1
      end
    end
    local txt = table.concat(out)
    -- normalize curly quotes to straight quotes for our pattern matcher
    txt = txt:gsub("“", '"'):gsub("”", '"')
    return txt
  end

-- function to magically convert pixel data into number salad
local function createColorIndices(sprite, cel, palette)
    local colorToIndex = {}
    local img = cel.image    
  
    -- build a map of colors from the provided palette
    for i, colorInfo in ipairs(palette) do
      local colorValue = app.pixelColor.rgba(
        colorInfo.color.red,
        colorInfo.color.green,
        colorInfo.color.blue,
        colorInfo.color.alpha
      )
      colorToIndex[colorValue] = i - 1 -- 0-based index
    end
  
    local pixelData = {}
    for pixel in img:pixels() do
      local colorValue = pixel()
      if app.pixelColor.rgbaA(colorValue) > 0 then
        local gx = pixel.x + cel.position.x
        local gy = pixel.y + cel.position.y

        -- include ONLY pixels visible on the canvas, in palette colors
        if gx >= 0 and gx < sprite.width and gy >= 0 and gy < sprite.height then
          local index = colorToIndex[colorValue]
          if index ~= nil then  -- only include pixels matching palette colors
            table.insert(pixelData, { x = gx, y = gy, color = index })
          end
        end
      end
    end
  
    return pixelData
  end
  
  -- sniff sprite for colors on open
  local function getUniqueColors()
    local sprite = app.activeSprite
    if not sprite then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- default basepaint blue if no sprite
    local cel = sprite.cels[1]
    if not cel then return {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} end -- default basepaint blue if no cel
  
    local colorToIndex = {}
    local colorList = {}
    local nextIndex = 0
    local img = cel.image
  
    for pixel in img:pixels() do
      local colorValue = pixel()
      if app.pixelColor.rgbaA(colorValue) > 0 then
        if not colorToIndex[colorValue] then
          colorToIndex[colorValue] = nextIndex
          table.insert(colorList, {
            color = Color{
              r = app.pixelColor.rgbaR(colorValue),
              g = app.pixelColor.rgbaG(colorValue),
              b = app.pixelColor.rgbaB(colorValue),
              a = app.pixelColor.rgbaA(colorValue)
            }
          })
          nextIndex = nextIndex + 1
        end
      end
    end
  
    return #colorList > 0 and colorList or {{ color = Color{ r = 0, g = 0, b = 255, a = 255 } }} -- default basepaint blue if empty
  end
  
-- function to grab pixels on export
  local function generateJSON(palette, selectedLayerIndex, frameIndex)
    local sprite = app.activeSprite
    if not sprite then
      app.alert("No sprite is active!")
      return nil
    end
  
    local layer = sprite.layers[selectedLayerIndex]
    if not layer then
      app.alert("Selected layer not found!")
      return nil
    end
  
    local cel = layer:cel(sprite.frames[frameIndex]) -- first frame
    if not cel then
      app.alert("No pixel data found in selected layer/frame!")
      return nil
    end
  
    local pixelData = createColorIndices(sprite, cel, palette)
    local json_lines = {}
  
    for i, pixel in ipairs(pixelData) do
      table.insert(json_lines, string.format(
        '{"point":{"x":%d,"y":%d},"color":%d}%s',
        pixel.x, pixel.y, pixel.color,
        i < #pixelData and "," or ""
      ))
    end
  
    return "[\n" .. table.concat(json_lines, "\n") .. "\n]"
  end

-- function to import pixels from JSON text
  local function importBasepaintJSON(json_text, palette, frameIndex, layerName)
    if not json_text or json_text == "" then
      app.alert("No JSON provided.")
      return 0
    end

    local sprite = app.activeSprite
    if not sprite then
      app.alert("Open a sprite first (set size, color mode, etc.).")
      return 0
    end

    -- parse points: [{"point":{"x":..,"y":..},"color":N}, ...]
    local points = {}
    for x, y, col in json_text:gmatch(
      [["point"%s*:%s*{%s*"x"%s*:%s*(%-?%d+)%s*,%s*"y"%s*:%s*(%-?%d+)%s*}%s*,%s*"color"%s*:%s*(%d+)]]
    ) do
      table.insert(points, { x=tonumber(x), y=tonumber(y), colorIndex=tonumber(col) })
    end

    if #points == 0 then
      app.alert("Couldn't find any pixels in that file.")
      return 0
    end

    local minX, minY = math.huge, math.huge
    local maxX, maxY = -math.huge, -math.huge
    for _, p in ipairs(points) do
      if p.x < minX then minX = p.x end
      if p.y < minY then minY = p.y end
      if p.x > maxX then maxX = p.x end
      if p.y > maxY then maxY = p.y end
    end
    -- convert coords to width/height
    local bboxW = (maxX - minX + 1)
    local bboxH = (maxY - minY + 1)

    local img
    pcall(function() img = Image(bboxW, bboxH, sprite.colorMode) end)
    if not img then
      local spec = ImageSpec()
      spec:assign(sprite.spec)
      spec.width = bboxW
      spec.height = bboxH
      img = Image(spec)
    end
    img:clear()

    -- plot pixels, translating by -minX,-minY
    local painted, skipped = 0, 0
    for _, p in ipairs(points) do
      local palIdx = p.colorIndex or 0
      local entry = nil
      if palette[palIdx + 1] then
        entry = palette[palIdx + 1]
      elseif palette[palIdx] then
        entry = palette[palIdx]
      end
      if entry and entry.color then
        local lx = p.x - minX
        local ly = p.y - minY
        if lx >= 0 and lx < bboxW and ly >= 0 and ly < bboxH then
          local c = entry.color
          local px = app.pixelColor.rgba(c.red, c.green, c.blue, c.alpha)
          img:drawPixel(lx, ly, px)
          painted = painted + 1
        else
          skipped = skipped + 1
        end
      else
        skipped = skipped + 1
      end
    end

    -- add new layer & cel placed at (minX,minY) / can be off-canvas
    local layer = sprite:newLayer()
      if layerName and layerName ~= "" then
        layer.name = layerName
      else
        layer.name = "Basepasted Layer"
      end
    local frame = sprite.frames[frameIndex or 1]
    sprite:newCel(layer, frame, img, Point(minX, minY))

    -- make it immediately editable
    app.activeLayer = layer
    if frame then app.activeFrame = frame end
    app.refresh()

    if skipped > 0 then
      app.alert("Imported "..painted.." pixels ("..skipped.." skipped due to missing color or bounds)!")
    else
      app.alert("Imported "..painted.." pixels!")
    end
    return painted
  end

-- pixel tally function
  local function countVisiblePixels(layer, frame)
    local cel = layer:cel(frame)
    if not cel then return 0 end
    local img = cel.image
    local pos = cel.position
    local sprite = app.activeSprite
    local count = 0

    for px in img:pixels() do
      local x = px.x + pos.x
      local y = px.y + pos.y
      if x >= 0 and x < sprite.width and y >= 0 and y < sprite.height then
        if app.pixelColor.rgbaA(px()) > 0 then
          count = count + 1
        end
      end
    end

    return count
  end
  
-- save to file
  local function saveToFileWithPrompt(json_string)
    local dlg = Dialog{ title = "Save Pixel Data As" }
    dlg:file{
      id = "filepath",
      label = "File:",
      save = true,
      filename = "output.txt"
    }
    dlg:button{
      text = "Save",
      onclick = function()
        local filepath = dlg.data.filepath
        if filepath and filepath ~= "" then
          local file = io.open(filepath, "w")
          if file then
            file:write(json_string)
            file:close()
            os.execute("open \"" .. filepath .. "\"")
            app.alert("Saved and opened: " .. filepath)
          else
            app.alert("Failed to save file!")
          end
        else
          app.alert("No file path provided.")
        end
      end
    }
    dlg:button{ text = "Cancel" }
    dlg:show()
  end
  
-- copy to clipboard
  local function copyToClipboard(json_string)
    if not json_string then return end
  
    local osName = os.getenv("OS") or "unknown"
    if osName:lower():find("windows") then
      os.execute("echo|set /p=\"" .. json_string:gsub('"', '""') .. "\"|clip")
    elseif package.config:sub(1,1) == "/" then
      local success = os.execute("printf %s \"" .. json_string:gsub('"', '\\"') .. "\" | pbcopy 2>/dev/null")
      if not success then
        success = os.execute("printf %s \"" .. json_string:gsub('"', '\\"') .. "\" | xclip -selection clipboard 2>/dev/null")
      end
      if success then
        app.alert("Copied to clipboard!")
      else
        app.alert("Clipboard copy failed. Ensure 'pbcopy' (macOS) or 'xclip' (Linux) is installed.")
      end
    else
      app.alert("Unsupported OS for clipboard copy.")
      return
    end
  end

-- refresh layers
  local function getLayerNames()
    local names = {}
    local sprite = app.activeSprite
    if not sprite then return names end
    for _, layer in ipairs(sprite.layers) do
      if layer.name and layer.name ~= "" then
        table.insert(names, layer.name)
      end
    end
    return names
  end
  
  local dlg = nil
  local palette = getUniqueColors() -- initialize with sprite colors
  local selectedLayerIndex = 2 -- default to Layer 2
  local currentDayInput = "Day #" -- set default day input text here
  local selectedSwatch = 1
  -- Live streaming to BasePaint: your cursor, and with your key from basepaint.xyz/aseprite, your unsaved pixels (the
  -- layer and frame picked below, in today's palette) as a draft other painters can watch. It starts by itself whenever
  -- Baseprite opens, unless you stopped it; that choice and the key are saved in baseprite_settings.txt next to this
  -- script.
  local CURSOR_MOVE = 1
  local CURSOR_LEAVE = 2
  local LAYER = 6
  local LAYER_PIXELS = 9
  local CANVAS_SIZE = 256
  -- BasePaint day 1 began at this Unix time; a day is 24 hours.
  local BASEPAINT_STARTED_AT = 1691599315
  -- A change this big goes as the whole layer instead, like the website does.
  local MAX_CHANGED_PIXELS = 2000
  local SETTINGS_PATH = getScriptFolder() .. "baseprite_settings.txt"

  local function loadSettings()
    local settings = {}
    local f = io.open(SETTINGS_PATH, "r")
    if not f then return settings end
    for line in f:lines() do
      local name, value = line:match("^%s*([%w_]+)%s*=%s*(.-)%s*$")
      if name then settings[name] = value end
    end
    f:close()
    return settings
  end

  local function saveSettings(settings)
    local f = io.open(SETTINGS_PATH, "w")
    if not f then return end
    for _, name in ipairs({ "stream", "key", "server", "site" }) do
      if settings[name] and settings[name] ~= "" then f:write(name, "=", settings[name], "\n") end
    end
    f:close()
  end

  -- The script is re-run when its dialog is reopened; keep one shared stream.
  local oldStream = rawget(_G, "__basepriteCursorStream")
  if type(oldStream) == "table" and oldStream.socket then
    -- Left running by an older Baseprite in this Aseprite session.
    if oldStream.timer then pcall(function() oldStream.timer:stop() end) end
    pcall(function() oldStream.socket:close() end)
    oldStream.socket = nil
  end
  local stream = rawget(_G, "__basepriteStream")
  if type(stream) ~= "table" then
    stream = { status = "Streaming is off" }
    rawset(_G, "__basepriteStream", stream)
  end
  stream.settings = loadSettings()
  local function serverUrl()
    local url = stream.settings.server or "ws://aseprite.basepaint.xyz/baseprite"
    return stream.settings.key and (url .. "?key=" .. stream.settings.key) or url
  end
  local function siteUrl() return stream.settings.site or "https://basepaint.xyz" end

  local function currentBasepaintDay()
    return math.floor((os.time() - BASEPAINT_STARTED_AT) / 86400) + 1
  end

  local function setStreamStatus(status)
    if stream.status == status then return end
    stream.status = status
    local dialog = stream.dialog
    if not dialog then return end
    pcall(function()
      dialog:modify{ id = "streamToggle", text = stream.socket and "Stop Streaming" or "Start Streaming" }
      dialog:modify{ id = "streamStatus", text = status }
    end)
  end

  local function sendFrame(frame)
    if not stream.socket or not stream.isOpen then return false end
    return pcall(function() stream.socket:sendBinary(frame) end)
  end

  local function currentCursorFrame()
    local editor = app.editor
    local sprite = editor and editor.sprite
    local point = editor and editor.spritePos
    if not sprite or not point or sprite.width <= 0 or sprite.height <= 0 or
       point.x < 0 or point.y < 0 or
       point.x >= sprite.width or point.y >= sprite.height then
      return string.char(CURSOR_LEAVE)
    end

    local x = math.floor((1000 * point.x) / sprite.width)
    local y = math.floor((1000 * point.y) / sprite.height)
    return string.char(
      CURSOR_MOVE,
      math.floor(x / 256), x % 256,
      math.floor(y / 256), y % 256
    )
  end

  -- Today's palette as rgb -> palette index + 1, the value a draft pixel carries (0 is empty).
  local function todaysColors(day)
    if stream.colorsDay == day then return stream.colors end
    -- One try a day, set before trying: Aseprite asks before running curl, and a refusal throws, so retrying every
    -- tick would keep asking.
    stream.colorsDay = day
    stream.colors = nil
    local path = getScriptFolder() .. "basepaint_theme_data.json"
    pcall(function()
      os.execute('curl -s "' .. siteUrl() .. '/api/theme/' .. day .. '" -o "' .. path .. '"')
      local f = io.open(path, "r")
      local body = f and f:read("*a") or ""
      if f then f:close() end
      local palette = body:match('"palette"%s*:%s*%[(.-)%]')
      if not palette then return end
      local colors = {}
      local i = 0
      for hex in palette:gmatch('"#(%x%x%x%x%x%x)"') do
        i = i + 1
        colors[tonumber(hex, 16)] = i
      end
      stream.colors = colors
    end)
    if not stream.colors then setStreamStatus("Couldn't load today's palette. Stop and start streaming to retry.") end
    return stream.colors
  end

  -- The streamed layer: the one picked in the layer menu while the dialog is open, else the last one picked.
  -- The draft as y * 256 + x -> value, or nil when there's nothing to stream from (no 256x256 sprite, no palette).
  local function readDraft(day)
    local sprite = app.activeSprite
    if not sprite or sprite.width ~= CANVAS_SIZE or sprite.height ~= CANVAS_SIZE then
      if not stream.badKey then setStreamStatus("Streaming your cursor. Drafts stream from a 256x256 sprite.") end
      return nil
    end
    local colors = todaysColors(day)
    if not colors then return nil end
    if not stream.badKey then setStreamStatus("Streaming your cursor and drafts") end
    local draft = {}
    -- The painter's visible, unlocked layers in the current frame. A layer that fills the whole canvas with no
    -- transparent pixel is a background (a pasted or grabbed canvas) and stays out, as do hidden, locked and
    -- reference layers. Grab Canvas adds its layer locked.
    local img = Image(sprite.spec)
    local frame = app.activeFrame or sprite.frames[1]
    local function isBackground(cel)
      local b = cel.bounds
      if b.x > 0 or b.y > 0 or b.x + b.width < CANVAS_SIZE or b.y + b.height < CANVAS_SIZE then return false end
      local clear = cel.image.colorMode == ColorMode.INDEXED and sprite.transparentColor or nil
      for px in cel.image:pixels() do
        local x, y = px.x + b.x, px.y + b.y
        if x >= 0 and x < CANVAS_SIZE and y >= 0 and y < CANVAS_SIZE then
          local value = px()
          if (clear and value == clear) or (not clear and app.pixelColor.rgbaA(value) == 0) then return false end
        end
      end
      return true
    end
    local function drawLayers(layers)
      for _, layer in ipairs(layers) do
        if layer.isVisible and layer.isEditable and not layer.isReference then
          if layer.isGroup then
            drawLayers(layer.layers)
          else
            local cel = layer:cel(frame)
            if cel and not isBackground(cel) then img:drawImage(cel.image, cel.position) end
          end
        end
      end
    end
    drawLayers(sprite.layers)
    local pos = { x = 0, y = 0 }
    local isIndexed = img.colorMode == ColorMode.INDEXED
    local spritePalette = isIndexed and sprite.palettes[1]
    for px in img:pixels() do
      local x = px.x + pos.x
      local y = px.y + pos.y
      if x >= 0 and x < CANVAS_SIZE and y >= 0 and y < CANVAS_SIZE then
        local value = px()
        local r, g, b, a
        if isIndexed then
          if value ~= sprite.transparentColor and value < #spritePalette then
            local c = spritePalette:getColor(value)
            r, g, b, a = c.red, c.green, c.blue, c.alpha
          end
        else
          r, g, b, a = app.pixelColor.rgbaR(value), app.pixelColor.rgbaG(value),
            app.pixelColor.rgbaB(value), app.pixelColor.rgbaA(value)
        end
        local index = a == 255 and colors[r * 65536 + g * 256 + b]
        if index then draft[y * CANVAS_SIZE + x] = index end
      end
    end
    return draft
  end

  local function dayHeader(type, day)
    return string.char(type, math.floor(day / 256), day % 256)
  end

  -- The whole draft as zlib data the server inflates: two "stored" (uncompressed) deflate blocks, no zlib library
  -- needed. It is about 64 KB, sent only when the stream starts and after big changes.
  local function packDraft(draft)
    local bytes = {}
    for i = 1, CANVAS_SIZE * CANVAS_SIZE do bytes[i] = 0 end
    for index, value in pairs(draft) do bytes[index + 1] = value end
    local chunks = {}
    for i = 1, #bytes, 4096 do chunks[#chunks + 1] = string.char(table.unpack(bytes, i, i + 4095)) end
    local grid = table.concat(chunks)

    local a, b = 1, 0
    for i = 1, #bytes do
      a = (a + bytes[i]) % 65521
      b = (b + a) % 65521
    end
    local function block(isLast, data)
      local n = #data
      return string.char(isLast and 1 or 0, n % 256, math.floor(n / 256),
        (65535 - n) % 256, math.floor((65535 - n) / 256)) .. data
    end
    return "\120\1" .. block(false, grid:sub(1, 65535)) .. block(true, grid:sub(65536)) ..
      string.char(math.floor(b / 256), b % 256, math.floor(a / 256), a % 256)
  end

  local function countOf(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
  end

  -- Sends what changed since the last call: changed pixels, or the whole draft.
  -- Reading the draft only happens after the sprite changes (or a different sprite or frame shows), so an idle
  -- Aseprite costs nothing and painting costs at most four reads a second.
  local function onSpriteChange() stream.dirty = true end
  local function watchSprite(sprite)
    if stream.watchedSprite == sprite then return end
    local old = stream.watchedSprite
    if old then pcall(function() old.events:off(onSpriteChange) end) end
    stream.watchedSprite = sprite
    if sprite then pcall(function() sprite.events:on("change", onSpriteChange) end) end
    stream.dirty = true
  end

  local function streamDraft()
    local day = currentBasepaintDay()
    watchSprite(app.activeSprite)
    local frameNumber = app.activeFrame and app.activeFrame.frameNumber
    if not stream.dirty and stream.readDay == day and stream.readFrame == frameNumber then return end
    stream.dirty = false
    stream.readDay = day
    stream.readFrame = frameNumber
    local draft = readDraft(day)
    if not draft then
      stream.dirty = true
      return
    end
    local sent = stream.sentDay == day and stream.sent or nil

    local changes = nil
    if sent then
      changes = {}
      for index, value in pairs(draft) do
        if sent[index] ~= value then changes[#changes + 1] = index; changes[#changes + 1] = value end
      end
      for index in pairs(sent) do
        if not draft[index] then changes[#changes + 1] = index; changes[#changes + 1] = 0 end
      end
      if #changes == 0 then return end
    end

    local ok
    if next(draft) == nil then
      -- Nothing to show: take down a draft only if this stream put one up.
      if not stream.hasSentLayer or sendFrame(dayHeader(LAYER, day)) then
        stream.hasSentLayer = false
        -- The first pixels after this go whole, replacing anything the server still holds for this painter.
        stream.sent = nil
      else
        stream.dirty = true
      end
      return
    elseif changes and #changes <= MAX_CHANGED_PIXELS * 2 then
      local parts = { dayHeader(LAYER_PIXELS, day) }
      for i = 1, #changes, 2 do
        local index = changes[i]
        parts[#parts + 1] = string.char(index % CANVAS_SIZE, math.floor(index / CANVAS_SIZE), changes[i + 1])
      end
      ok = sendFrame(table.concat(parts))
      if ok then stream.hasSentLayer = true end
    else
      ok = sendFrame(dayHeader(LAYER, day) .. packDraft(draft))
      if ok then stream.hasSentLayer = true end
    end
    if ok then
      stream.sent = draft
      stream.sentDay = day
    else
      stream.dirty = true
    end
  end

  local function onTick()
    local frame = currentCursorFrame()
    if frame ~= stream.lastFrame and sendFrame(frame) then stream.lastFrame = frame end
    -- Pixels four times a second; the cursor twenty.
    stream.tick = ((stream.tick or 0) + 1) % 5
    if stream.settings.key and stream.tick == 0 then
      local ok, err = pcall(streamDraft)
      if not ok then setStreamStatus("Draft stream error: " .. tostring(err)) end
    end
  end

  local function stopTimer()
    if stream.timer then
      stream.timer:stop()
      stream.timer = nil
    end
  end

  local function resetConnection()
    stream.isOpen = false
    stream.lastFrame = nil
    -- The server may have missed what we sent; the next draft goes whole.
    stream.sent = nil
    stream.dirty = true
    stopTimer()
  end

  local function handleMessage(socket, messageType, data, err)
    if stream.socket ~= socket then return end

    if messageType == WebSocketMessageType.OPEN then
      resetConnection()
      stream.badKey = false
      stream.isOpen = true
      setStreamStatus(stream.settings.key and "Streaming your cursor and drafts" or
        "Streaming your cursor. Set Key to share drafts.")
      onTick()
      stream.timer = Timer{ interval = 1.0 / 20.0, ontick = onTick }
      stream.timer:start()
    elseif messageType == WebSocketMessageType.TEXT and tostring(data):find("bad_key", 1, true) then
      -- The server didn't accept the key (expired or mistyped): the cursor still shows, drafts don't.
      stream.badKey = true
      setStreamStatus("Key not accepted. Copy a new one from " .. siteUrl() .. "/aseprite and Set Key.")
    elseif messageType == WebSocketMessageType.CLOSE then
      resetConnection()
      if stream.socket then setStreamStatus("Reconnecting...") end
    elseif err then
      setStreamStatus("Stream error: " .. tostring(err))
    end
  end

  local function stopStream()
    stream.colorsDay = nil
    -- Stopping takes your draft down too, so nobody watches a stale one.
    if stream.hasSentLayer then sendFrame(dayHeader(LAYER, stream.sentDay or currentBasepaintDay())) end
    stream.hasSentLayer = false
    sendFrame(string.char(CURSOR_LEAVE))
    local socket = stream.socket
    stream.socket = nil
    resetConnection()
    if socket then pcall(function() socket:close() end) end
    setStreamStatus("Streaming is off")
  end

  local function startStream()
    if stream.socket then return end
    if not WebSocket or not WebSocketMessageType then
      setStreamStatus("This Aseprite version can't stream. Update Aseprite.")
      return
    end

    local socket
    local ok, createError = pcall(function()
      socket = WebSocket{
        url = serverUrl(),
        deflate = false,
        minreconnectwait = 1,
        maxreconnectwait = 5,
        onreceive = function(...)
          handleMessage(socket, ...)
        end,
      }
    end)
    if not ok or not socket then
      setStreamStatus("Could not stream: " .. tostring(createError))
      return
    end

    stream.socket = socket
    setStreamStatus("Connecting to BasePaint...")
    local connected, connectError = pcall(function() socket:connect() end)
    if not connected then
      stopStream()
      setStreamStatus("Could not connect: " .. tostring(connectError))
    end
  end

  local function setStreaming(on)
    stream.settings.stream = on and "on" or "off"
    saveSettings(stream.settings)
    if on then startStream() else stopStream() end
  end

  -- The key from basepaint.xyz/aseprite; streaming reconnects with it.
  local function askForKey()
    local keyDlg = Dialog("Baseprite Key")
    keyDlg
      :label{ text = "Copy your key from " .. siteUrl() .. "/aseprite and paste it here." }
      :newrow()
      :entry{ id = "key", text = "", focus = true }
      :button{
        text = "Save",
        onclick = function()
          local key = (keyDlg.data.key or ""):match("^%s*([%w%-_%.]+)%s*$")
          keyDlg:close()
          if not key then
            setStreamStatus("That doesn't look like a key. Copy it again from " .. siteUrl() .. "/aseprite.")
            return
          end
          stream.settings.key = key
          if stream.socket then stopStream() end
          setStreaming(true)
        end
      }
      :button{ text = "Cancel", onclick = function() keyDlg:close() end }
      :show()
  end

  local function pickColor(index)
    app.useTool{
      tool = "eyedropper",
      color = palette[index].color,
      button = MouseButton.LEFT,
      callback = function(color)
        palette[index].color = color
        createDialog()
      end
    }
  end

-- Help Text
  local BASEPRITE_HELP_LINES = {
    "Day # - Enter a Basepaint day number here! (can be: 100, Day #100, or even try random!)",
    "Load Palette - Loads the Basepaint palette from the input Day #.",
    "Enter Hex - Manually set the palette using space-separated hex codes.",
    "Grab Canvas - Downloads the canvas for the input Day # as a new layer.",
    "Palette - View the active color palette! Click on a swatch to select the color.",
    "Layer Menu - The layers dropdown menu, select which layer will be saved/copied.",
    "Frame Input - Enter the Frame # you're targeting for export.",
    "Refresh Layers List - Click this whenever you add new layers, to refresh the layer menu.",
    "Count Pixels - Counts the amount of pixels for the selected layer & frame!",
    "(You can enter 'all' in the frames input, then click Count Pixels to count for all frames!)",
    "Import Pixels - Import pixel code from plain text (.txt) or .rtf (.doc not supported).",
    "Save to File - Save a .txt file containing the pixel data. Be sure to set a filename & location.",
    "(Once saved, the plugin will attempt to automatically open the file in a plain text editor)",
    "Copy to Clipboard - Copies the pixel data to your clipboard, ready to paste into Basepaint!",
    "Start/Stop Streaming - Shows your cursor live on Basepaint. Baseprite remembers your choice next time it opens.",
    "Set Key - Paste your key from basepaint.xyz/aseprite, once. Then others see your drafts live:",
    "(your visible, unlocked layers on a 256x256 sprite, in today's palette. A layer that fills the whole canvas counts as background and stays out. Stopping takes your draft down.)",
  }

  local function showBasepriteHelp()
    local helpDlg = Dialog{ title="Baseprite Help", resizeable=true }

    helpDlg:newrow{ always=true }

    for _, line in ipairs(BASEPRITE_HELP_LINES) do
      helpDlg:label{ text=line }
    end

    helpDlg:show{ wait=false, autoscrollbars=true }
  end
  
-- plugin window
  local function createDialog()
    if dlg then dlg:close() end

    local dialog
    dialog = Dialog{
      title = "Baseprite by Creamy",
      onclose = function()
        if dlg == dialog then dlg = nil end
        if stream.dialog == dialog then stream.dialog = nil end
      end,
    }
    dlg = dialog
    stream.dialog = dialog
  
    -- day input
    dlg:entry{
      id = "dayInput",
      text = currentDayInput
    }

    -- load palette button
    dlg:button{
      text = "Load Palette",
      onclick = function()
        local rawDay = dlg.data and dlg.data.dayInput or "1"
        local maxDay = getCurrentBasepaintDay() + 1
        local day

        if tostring(rawDay):lower():find("random") then
          math.randomseed(os.time())
          day = tostring(math.random(1, maxDay))
          currentDayInput = day
          app.alert("Random palette: Day " .. day)
        else
          local numeric = tonumber(rawDay:match("%d+")) or -1
          if numeric < 1 or numeric > maxDay then
            app.alert("Invalid day! Please enter a number between 1 and " .. maxDay .. ", or type 'random'.")
            return
          end
          day = tostring(numeric)
          currentDayInput = rawDay
        end

        local fetched = fetchBasepaintPalette(day)
        if fetched then
          palette = fetched

          local sprite = app.activeSprite
          if sprite then
            local newPal = Palette(#fetched)
            for i, c in ipairs(fetched) do
              newPal:setColor(i-1, c.color)
            end
            sprite:setPalette(newPal)
          end

          createDialog()
        end
      end
    }

    -- palette hex
    dlg:button{
      text = "Enter Hex",
      onclick = function()
        local hexDlg = Dialog("Import Hex Colors")
        hexDlg
          :entry{ id="hexes", text="", focus=true }
          :button{
            text = "Import",
            onclick = function()
              local input = hexDlg.data.hexes or ""
              local hexList = {}
              for hex in input:gmatch("#?%x%x%x%x%x%x") do
                hex = hex:gsub("#", "")
                local r = tonumber(hex:sub(1,2), 16)
                local g = tonumber(hex:sub(3,4), 16)
                local b = tonumber(hex:sub(5,6), 16)
                table.insert(hexList, { color = Color{ r=r, g=g, b=b, a=255 } })
              end

              if #hexList == 0 then
                app.alert("No valid hex codes found.")
                return
              end

              -- update global palette
              palette = hexList

              -- apply to active sprite
              local sprite = app.activeSprite
              if sprite then
                local newPal = Palette(#hexList)
                for i, c in ipairs(hexList) do
                  newPal:setColor(i-1, c.color)
                end
                sprite:setPalette(newPal)
                app.refresh()
              end

              hexDlg:close()
              createDialog()
            end
          }
          :button{ text="Cancel", onclick=function() hexDlg:close() end }
          :show()
      end
    }


    dlg:newrow()
    dlg:button{
      text = "Grab Canvas",
      onclick = function()
        local rawDay = dlg.data and dlg.data.dayInput or ""
        local day = parseDayInput(rawDay)
        local maxDay = getCurrentBasepaintDay() + 1

        if not day then
          app.alert("Please enter a Day #.")
          return
        end

        if day < 1 or day > maxDay then
          app.alert("Day must be between 1 and " .. maxDay)
          return
        end

        currentDayInput = tostring(day)

        local scriptFolder = getScriptFolder()
        local outPath = scriptFolder .. "basepaint_canvas.png"

        local ok, err = downloadCanvasPNG(day, outPath)
        if not ok then
          app.alert("Grab Canvas failed.\n" .. tostring(err))
          return
        end

        local img, imgErr = loadImage(outPath)
        if not img then
          app.alert(imgErr or "Failed to load image.")
          return
        end

        insertAsNewLayer(day, img)
        app.refresh()
      end
    }

    dlg:newrow()
    dlg:separator()
    dlg:button{
      id = "streamToggle",
      text = stream.socket and "Stop Streaming" or "Start Streaming",
      onclick = function() setStreaming(not stream.socket) end,
    }
    dlg:button{
      text = "Set Key",
      onclick = askForKey,
    }
    dlg:newrow()
    dlg:label{
      id = "streamStatus",
      text = stream.status,
    }

    dlg:newrow()
    dlg:separator()

    -- single-row palette grid
    do
      local rowColors = {}
      for i, c in ipairs(palette) do
        rowColors[i] = c.color
      end

      dlg:shades{
        id = "paletteRow",
        label = "",
        colors = rowColors,
        mode = "pick",
        onclick = function(ev)
          -- find which swatch was clicked by comparing against the row colors
          local function same(c1, c2)
            return c1.red == c2.red and c1.green == c2.green and
                  c1.blue == c2.blue and c1.alpha == c2.alpha
          end

          local idx = nil
          for i, c in ipairs(rowColors) do
            if same(c, ev.color) then
              idx = i
              break
            end
          end
          if not idx or idx > #palette then
            return -- ignore clicks on anything unexpected
          end

          selectedSwatch = idx
          if ev.button == MouseButton.RIGHT then
            app.bgColor = palette[idx].color   -- right-click = BG color
          else
            app.fgColor = palette[idx].color   -- left-click = FG color
          end
        end
      }
    end

    dlg:newrow()
    dlg:separator()
  
    local layerNames = getLayerNames()

    -- layer menu
    dlg:combobox{
        id = "layer",
        options = layerNames,
        option = layerNames[1]
      }

    -- frame input
    dlg:entry{
      id = "frame",
      text = "Frame 1"
    }      
  
    dlg:newrow()

    -- refresh button
    dlg:button{
        text = "Refresh Layers List",
        onclick = function()
          createDialog() -- re-renders with updated layer list
        end
      }
      
    dlg:newrow()
    dlg:separator()

    -- pixel tally button
    dlg:button{
      text = "Count Pixels",
      onclick = function()

        -- reveal status line onclick
        dlg:modify{ id = "result", visible = true, text = "Counting..." }

        local sprite = app.activeSprite
        if not sprite then
          app.alert("No active sprite!")
          return
        end

        local data = dlg.data or {}
        local selectedLayerName = data.layer
        local frameText = data.frame or "1"

        -- find the selected layer by name
        local selectedLayer = nil
        for _, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedLayer = layer
            break
          end
        end
        if not selectedLayer then
          dlg:modify{ id="result", text="Error: Layer not found!" }
          return
        end

        -- allow "all" as an input option for frames
        local trimmed = tostring(frameText):lower():gsub("frame",""):gsub("%s+","")
        local total = 0
        if trimmed == "all" then
          for _, frame in ipairs(sprite.frames) do
            total = total + countVisiblePixels(selectedLayer, frame)
          end
          dlg:modify{ id="result", text = (tostring(total) .. " Pixels (all frames)") }
        else
          local frameIndex = parseFrameInput(frameText, sprite)
          local frame = sprite.frames[frameIndex]
          total = countVisiblePixels(selectedLayer, frame)
          dlg:modify{ id="result", text = (tostring(total) .. " Pixels") }
        end
      end
    }

    -- status line
    dlg:newrow()
    dlg:label{
      id = "result",
      text = "(pixel count here)",
      visible = false,
    }

    dlg:newrow()
    dlg:separator()

    -- import basepaint code && add it to a new layer
    dlg:button{
      text = "Import Pixels",
      onclick = function()
        local sprite = app.activeSprite
        local frameInput  = (dlg.data and dlg.data.frame) or "1"
        local frameIndex  = sprite and parseFrameInput(frameInput, sprite) or 1

        local fd = Dialog{ title = "Import Basepaint Code" }
        fd:label{ text = "Save your Basepaint code to a .txt or .rtf file," }
        fd:newrow()
        fd:label{ text = "then select it here (.doc not supported)" }
        fd:separator()
        fd:file{ id="path", open=true, label="" }

        fd:button{
          text = "Import",
          onclick = function()
            local path = fd.data and fd.data.path
            if not path or path == "" then
              app.alert("No file selected.")
              return
            end
            local f = io.open(path, "r")
            if not f then
              app.alert("Couldn't read file.")
              return
            end
            local txt = f:read("*a") or ""
            f:close()
            if txt == "" then
              app.alert("File is empty.")
              return
            end

            -- If it's RTF (by extension or header), strip markup
            local lowerPath = (path or ""):lower()
            if lowerPath:match("%.rtf$") or txt:sub(1,5) == "{\\rtf" then
              txt = rtfToPlain(txt)
            end

            local fname = path:match("([^/\\]+)$") or "Imported"
            local count = importBasepaintJSON(txt, palette, frameIndex, fname)
            fd:close()
            if count > 0 then createDialog() end
          end
        }
        fd:button{ text="Cancel", onclick=function() fd:close() end }
        fd:show()
      end
    }
  
    dlg:newrow()
    dlg:separator()
  
    -- save button
    dlg:button{
      text = "Save to File",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local frameInput = dlg.data and dlg.data.frame or "1"
        local sprite = app.activeSprite
        local selectedLayerIndex = 1
        local frameIndex = parseFrameInput(frameInput, sprite)

        -- get selected layer index
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedLayerIndex = i
            break
          end
        end

        local json_string = generateJSON(palette, selectedLayerIndex, frameIndex)
        
        if json_string then
          saveToFileWithPrompt(json_string)
        end
      end
    }
  
    -- copy button
    dlg:button{
      text = "Copy to Clipboard",
      onclick = function()
        local selectedLayerName = dlg.data and dlg.data.layer
        local frameInput = dlg.data and dlg.data.frame or "1"
        local sprite = app.activeSprite
        local selectedLayerIndex = 1
        local frameIndex = parseFrameInput(frameInput, sprite)

        -- get selected layer index
        for i, layer in ipairs(sprite.layers) do
          if layer.name == selectedLayerName then
            selectedLayerIndex = i
            break
          end
        end

        local json_string = generateJSON(palette, selectedLayerIndex, frameIndex)
        
        if json_string then
          copyToClipboard(json_string)
        end
      end
    }

    dlg:newrow()
    dlg:separator()
      
    dlg:button{
      text="Help?",
      onclick=function()
        showBasepriteHelp()
      end
    }
  
    dlg:show{ wait = false }
  end
  
  createDialog()
  if stream.settings.stream ~= "off" then startStream() end
