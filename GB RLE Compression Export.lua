local sprite = app.activeSprite
-- Globals to be considered as constants
local FULL = 1024
local SCRN = 360
local TALL = 640
local WIDE = 576
local TILE = 1
local MAP = 0
local spriteFullPath
local spriteFileName


-- Check constrains
if sprite == nil then
  app.alert("No Sprite...")
  return
end
if sprite.colorMode ~= ColorMode.INDEXED then
  app.alert("Sprite needs to be indexed")
  return
end

if (sprite.width % 8) ~= 0 then
  app.alert("Sprite width needs to be a multiple of 8")
  return
end

if (sprite.height % 8) ~= 0 then
  app.alert("Sprite height needs to be a multiple of 8")
  return
end

--Grab the title of our aseprite file
if sprite then
    spriteFullPath = sprite.filename
    spriteFilePath = spriteFullPath:match("(.+)%..+$")
    spriteFileName = spriteFullPath:match("([^/\\]+)$"):match("(.+)%..+$")
end

-- Helper function to read file size
local function get_file_size(file_path)
    local file = io.open(file_path, "rb")
    if not file then
        return nil
    end
    local size = file:seek("end")
    file:close()
    return size
end

-- Helper function to pad binary file
local function pad_binary_file(file_path, target_size)
    local file = io.open(file_path, "ab")
    if not file then
        return false
    end
    local current_size = get_file_size(file_path)
    for _ = 1, target_size - current_size do
        file:write(string.char(0))
    end
    file:close()
    return true
end

-- Calculate compressed size
local function calc_comp_size(origBinFile, origSize)
    local file = io.open(origBinFile, "rb")
    if not file then
        return nil
    end

    local numRuns = 0
    local runLength = 0
    local prevByte = file:read(1)

    for _ = 1, origSize do
        local currentByte = file:read(1)
        if not currentByte or currentByte ~= prevByte then
            numRuns = numRuns + 1
            prevByte = currentByte
        elseif runLength >= 255 then
            numRuns = numRuns + 1
            runLength = 0
        else
            runLength = runLength + 1
        end
    end

    file:close()
    return (numRuns * 2) + 2
end

-- Perform BSRLE compression
local function BSRLE_Compression(origBinFile, incFile, origSize)
    local file = io.open(origBinFile, "rb")
    if not file then
        return false
    end

    local runsPerLine = 0
    local runLength = 1
    local prevByte = file:read(1)
    incFile:write(".DW ")

    for _ = 1, origSize do
        local currentByte = file:read(1)
        if not currentByte or currentByte ~= prevByte then
            if runsPerLine >= 16 then
                incFile:write("\n.DW ")
                runsPerLine = 0
            end
            incFile:write(string.format("$%02X%s ", runLength, prevByte:byte()))
            runsPerLine = runsPerLine + 1
            runLength = 1
            prevByte = currentByte
        elseif runLength >= 255 then
            incFile:write(string.format("$%02X%s ", runLength, prevByte:byte()))
            runsPerLine = runsPerLine + 1
            runLength = 1
        else
            runLength = runLength + 1
        end
    end

    incFile:write("\n;Terminator word is $0000 since we can't have a run length of length 0.\n")
    incFile:write(".DW $0000\n")
    file:close()
    return true
end

-- Handle uncompressed data
local function no_compression(origBinFile, incFile, origSize)
    local file = io.open(origBinFile, "rb")
    if not file then
        return false
    end

    incFile:write("\n;Size of uncompressed tile data:\n")
    incFile:write(string.format(".DW $%04X\n", origSize))
    incFile:write(";Raw tile data \n.DB ")

    local bytesPerLine = 0
    for _ = 1, origSize do
        local currentByte = file:read(1)
        if bytesPerLine >= 16 then
            incFile:write("\n.DB ")
            bytesPerLine = 0
        end
        incFile:write(string.format("$%02X ", currentByte:byte()))
        bytesPerLine = bytesPerLine + 1
    end

    file:close()
    return true
end

local function getTileData(img, x, y)
    local res = ""

    for  cy = 0, 7 do
        local hi = 0
        local lo = 0

        for cx = 0, 7 do
            px = img:getPixel(cx+x, cy+y)
            

            if (px & 1) ~= 0 then
                lo = lo | (1 << 7-cx)
            end
            if (px & 2) ~= 0 then
                hi = hi | (1 << 7-cx)
            end
        end
        res = res .. string.char(lo, hi)
        if cy < 7 then
            res = res
        end
        
    end

    return res
end

local spriteLookup = {}
local lastLookupId = 0

local function exportFrame(useLookup, frm)
    if frm == nil then
        frm = 1
    end

    local img = Image(sprite.spec)
    img:drawSprite(sprite, frm)

    local result = {}

    for x = 0, sprite.width-1, 8 do
        local column = {}
        for y = 0, sprite.height-1, 8 do
            local data = getTileData(img, x, y)
            local id = 0
            if useLookup then
                id = spriteLookup[data]
                if id == nil then
                    id = lastLookupId + 1
                    lastLookupId = id

                    spriteLookup[data] = id
                else
                    data = nil
                end 
            else
                id = lastLookupId + 1
                lastLookupId = id
            end
            table.insert(column, id)
            if data ~= nil then
                io.write(data)
            end
        end
        table.insert(result, column)
    end

    return result
end

function dump(o)
   if type(o) == 'table' then
      local s = '{ '
      for k,v in pairs(o) do
         if type(k) ~= 'number' then k = '"'..k..'"' end
         s = s .. '['..k..'] = ' .. dump(v) .. ','
      end
      return s .. '} '
   else
      return tostring(o)
   end
end

--Menu that pops up in Aseprite
local dlg = Dialog()

dlg:file{ id="exportFile",
          label="File",
          title="Gameboy-Assembler Export",
          open=false,
          save=true,
          filename= spriteFilePath .. "Tiles.bin",
          filetypes={"bin"}}
dlg:file{ id="mapFile",
          label="Tile-Map-File",
          title="Gameboy-Assembler Export",
          open=false,
          save=true,
          filename= spriteFilePath .. "Map.bin",
          filetypes={"bin"}}

dlg:check{ id="onlyCurrentFrame",
           text="Export only current frame",
           selected=true }
dlg:check{ id="removeDuplicates",
           text="Remove duplicate tiles",
           selected=true}
dlg:check{ id="exportMap",
           text="Export map data",
           selected=true}

dlg:button{ id="ok", text="OK" }
dlg:button{ id="cancel", text="Cancel" }
dlg:show()
local data = dlg.data
if data.ok then
    --Make the tile file
    local f = io.open(data.exportFile, "w")
    io.output(f)

    local mapData = {}

    if data.onlyCurrentFrame then
        table.insert(mapData, exportFrame(data.removeDuplicates, app.activeFrame))
    else
        for i = 1,#sprite.frames do
            io.write(string.format(";Frame %d\n", i))
            table.insert(mapData, exportFrame(data.removeDuplicates, i))
        end
    end

    io.close(f)

    if data.exportMap then
        local mf = io.open(data.mapFile, "w")


        for frameNo, frameMap in ipairs(mapData) do 
            if #mapData > 1 then
                --mf:write(string.format(";Frame %d\n", frameNo))
            end

            for y = 1, #frameMap[1] do
                --mf:write(".DB ")
                for x = 1, #frameMap do
                    if x > 1 then
                        --mf:write(", ")
                    end

                    mf:write(string.char(frameMap[x][y]))
                end
            end
        end
        mf:close()
    end

    --Take our binary tile data and try to compress them
    local tileData = data.exportFile
    local fileName, fileType = tileData:match("(.+)%.(.+)")
    local incFile
    incFile = io.open(fileName .. ".inc", "w")
    incFile:write(";Header byte follows this format:\n")
    incFile:write(";7:     1 = TILE, 0 = MAP\n")
    incFile:write(";6:     1 = Uncompressed\n")
    incFile:write(";5 & 4: 00 = SCRN, 01 = TALL\n")
    incFile:write(";       10 = WIDE, 11 = FULL\n")
    incFile:write(";0-3: Unused but set to 1\n")

    --Check if compression is efficient
    local binFileSize = get_file_size(tileData)
    local compFileSize = calc_comp_size(tileData, binFileSize)
    if not compFileSize then
        print("Error calculating compressed size.")
        incFile:close()
        return
    end
    if compFileSize > binFileSize then
        incFile:write(".DB %01001111")
        no_compression(tileData, incFile, binFileSize)
        print("File compression not efficient. Raw data with appropriate header copied instead.")
    else
        incFile:write(".DB %10001111")
        BSRLE_Compression(tileData, incFile, binFileSize)
        print("File compressed from " .. binFileSize .. " bytes to " .. compFileSize .. " bytes.")
    end

    incFile:close()
    
    if data.mapFile ~= nil and data.exportMap then
        --Take our binary map data and try to compress them
        
        local mapDataFile = data.mapFile
        local mapName, fileType = mapDataFile:match("(.+)%.(.+)")
        local incMapFile
        incMapFile = io.open(mapName .. ".inc", "w")
        incMapFile:write(";Header byte follows this format:\n")
        incMapFile:write(";7:     1 = TILE, 0 = MAP\n")
        incMapFile:write(";6:     1 = Uncompressed\n")
        incMapFile:write(";5 & 4: 00 = SCRN, 01 = TALL\n")
        incMapFile:write(";       10 = WIDE, 11 = FULL\n")
        incMapFile:write(";0-3: Unused but set to 1\n")

        --Check if compression is efficient
        local binMapSize = get_file_size(mapDataFile)
        local compMapSize = calc_comp_size(mapDataFile, binMapSize)
        if not compMapSize then
            print("Error calculating compressed size.")
            incMapFile:close()
            return
        end
        if compMapSize > binMapSize then
            incMapFile:write(".DB %01001111")
            no_compression(mapDataFile, incMapFile, binMapSize)
            print("File compression not efficient. Raw data with appropriate header copied instead.")
        else
            incMapFile:write(".DB %10001111")
            BSRLE_Compression(mapDataFile, incMapFile, binMapSize)
            print("File compressed from " .. binMapSize .. " bytes to " .. compMapSize .. " bytes.")
        end

        incMapFile:close()

    end


    
end
