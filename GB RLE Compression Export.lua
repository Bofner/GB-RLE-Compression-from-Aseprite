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
    local numRuns = 0
    local runLength = 0
    local prevByte = string.byte(origBinFile, 1)

    for i = 1, origSize do
        local currentByte = string.byte(origBinFile, i)
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

    return (numRuns * 2) + 2
end

-- Perform BSRLE compression
local function BSRLE_Compression(origBinFile, incFile, origSize)
    local runsPerLine = 0
    local runLength = 1
    local prevByte = string.byte(origBinFile, 1)
    incFile:write(".DW ")

    for i = 1, origSize do
        local currentByte = string.byte(origBinFile, i)
        if not currentByte or currentByte ~= prevByte then
            if runsPerLine >= 16 then
                incFile:write("\n.DW ")
                runsPerLine = 0
            end
            incFile:write(string.format("$%02X", runLength))
            incFile:write(string.format("%02X ", prevByte))
            runsPerLine = runsPerLine + 1
            runLength = 1
            prevByte = currentByte
        elseif runLength >= 255 then
            incFile:write(string.format("$%02X", runLength))
            incFile:write(string.format("%02X ", prevByte))
            runsPerLine = runsPerLine + 1
            runLength = 1
        else
            runLength = runLength + 1
        end
    end

    incFile:write("\n;Terminator word is $0000 since we can't have a run length of length 0.\n")
    incFile:write(".DW $0000\n")
    return true
end

-- Handle uncompressed data
local function no_compression(origBinary, incFile, origSize)
    incFile:write("\n;Size of uncompressed tile data:\n")
    incFile:write(string.format(".DW $%04X\n", origSize))
    incFile:write(";Raw tile data \n.DB ")

    local bytesPerLine = 0
    for i = 1, origSize do
        local currentByte = string.byte(origBinary, i)
        if bytesPerLine >= 16 then
            incFile:write("\n.DB ")
            bytesPerLine = 0
        end
        incFile:write(string.format("$%02X ", currentByte))
        bytesPerLine = bytesPerLine + 1
    end

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

local function exportFrame(useLookup, frm, binaryValueNotPointer)
    if frm == nil then
        frm = 1
    end

    local img = Image(sprite.spec)
    img:drawSprite(sprite, frm)

    local result = {}


    for y = 0, sprite.height-1, 8 do
        local row = {}
        for x = 0, sprite.width-1, 8 do
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
            table.insert(row, id)
            if data ~= nil then
                if binaryValueNotPointer.aBinaryValue ~= nil then
                    binaryValueNotPointer.aBinaryValue = binaryValueNotPointer.aBinaryValue .. data
                else
                    binaryValueNotPointer.aBinaryValue = data
                end

            end
        end
        table.insert(result, row)
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
          filename= spriteFilePath .. "Tiles.inc",
          filetypes={"inc"}}
dlg:file{ id="mapFile",
          label="Tile-Map-File",
          title="Gameboy-Assembler Export",
          open=false,
          save=true,
          filename= spriteFilePath .. "Map.inc",
          filetypes={"inc"}}

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
local notPointer = {aBinaryValue}
local tileBinary
local mapBinary
if data.ok then

    --Write our binary tile data and set up the map
    local mapData = {}
    if data.onlyCurrentFrame then
        table.insert(mapData, exportFrame(data.removeDuplicates, app.activeFrame, notPointer))
    else
        for i = 1,#sprite.frames do
            table.insert(mapData, exportFrame(data.removeDuplicates, i, tileBinary))
        end
    end
    --Load our binary tile data
    tileBinary = notPointer.aBinaryValue
    if tileBinary == nil then
        return
    end


    --Write our binary map data
    if data.exportMap then
        for frameNo, frameMap in ipairs(mapData) do 
            for x = 1, #frameMap do   
                for y = 1, #frameMap[1] do       
                    if mapBinary ~= nil then
                        --Concatenate the map data
                        mapBinary = mapBinary .. string.char(frameMap[x][y] - 1)
                    else
                        --The start of the binary  
                        mapBinary = string.char(frameMap[x][y] - 1)
                    end
                end
            end
        end
    end


    --Take our binary tile data and try to compress them
    local incFile = io.open(data.exportFile, "w")
    incFile:write(";Header byte follows this format:\n")
    incFile:write(";7:     1 = TILE, 0 = MAP\n")
    incFile:write(";6:     1 = Uncompressed\n")
    incFile:write(";5 & 4: 00 = SCRN, 01 = TALL\n")
    incFile:write(";       10 = WIDE, 11 = FULL\n")
    incFile:write(";0-3: Unused but set to 1\n")

    --Check if compression is efficient
    --local binFileSize = get_file_size(tileData)
    local compFileSize = calc_comp_size(tileBinary, #tileBinary)
    if not compFileSize then
        print("Error calculating compressed size.")
        incFile:close()
        return
    end
    if compFileSize > #tileBinary then
        incFile:write(".DB %11001111")
        no_compression(tileBinary, incFile, #tileBinary)
        print("File compression not efficient. Raw data with appropriate header copied instead.")
    else
        incFile:write(".DB %10001111")
        incFile:write(";Compressed tile data in the form $RunLength + $TileID written as a word ($RLID).")
        BSRLE_Compression(tileBinary, incFile, #tileBinary)
        print("File compressed from " .. #tileBinary .. " bytes to " .. compFileSize .. " bytes.")
    end

    incFile:close()
    
    if data.mapFile ~= nil and data.exportMap then
        --Check if compression is efficient
        local compMapSize = calc_comp_size(mapBinary, #mapBinary)
        local header
        if not compMapSize then
            print("Error calculating compressed size.")
            incMapFile:close()
            return
        end
        --Setup our header
        if #mapBinary == SCRN then
            header = "%00001111"
        elseif #mapBinary == TALL then
            header = "%00011111"
        elseif #mapBinary == WIDE then
            header = "%00101111"
        elseif #mapBinary == FULL then
            header = "%00111111"
        else
            app.alert("Canvas is an incompatible size for map data!")
            return
        end
        --Take our binary map data and try to compress them
        local incMapFile = io.open(data.mapFile, "w")
        incMapFile:write(";Header byte follows this format:\n")
        incMapFile:write(";7:     1 = TILE, 0 = MAP\n")
        incMapFile:write(";6:     1 = Uncompressed\n")
        incMapFile:write(";5 & 4: 00 = SCRN, 01 = TALL\n")
        incMapFile:write(";       10 = WIDE, 11 = FULL\n")
        incMapFile:write(";0-3: Unused but set to 1\n")

        if compMapSize > #mapBinary then
            incMapFile:write(".DB %01001111")
            no_compression(mapBinary, incMapFile, #mapBinary)
            print("File compression not efficient. Raw data with appropriate header copied instead.")
        else

            incMapFile:write(".DB " .. header)
            incMapFile:write("\n;Compressed tile data in the form $RunLength + $TileID written as a word ($RLID).\n")
            BSRLE_Compression(mapBinary, incMapFile, #mapBinary)
            print("File compressed from " .. #mapBinary .. " bytes to " .. compMapSize .. " bytes.")
        end

        incMapFile:close()

    end


    
end
