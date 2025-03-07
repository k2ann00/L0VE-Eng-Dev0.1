local State = require "state"
local Console = require "modules.console"
local SceneManager = require "modules.scene_manager"
local Camera = require "modules.camera"

local Tilemap = {
    tilesets = {},
    maps = {},
    activeTileset = nil,
    activeMap = nil,
    tileSize = 32,
    gridSize = 32,
    selectedTile = nil,
    hoveredTile = nil,
    showGrid = true,
    showTilemapWindow = false,
    previewScale = 2.0,
    mapScale = 1.0,
    lastMouseDown = false,
    entities = {},
    
    -- Debug mode
    debug = true,
    debugText = {},
    maxDebugMessages = 20
}

function Tilemap:addDebug(message)
    if not self.debug then return end
    
    Console:log("[TILEMAP DEBUG] " .. message)
    table.insert(self.debugText, os.date("%H:%M:%S") .. ": " .. message)
    
    -- Keep only the last N messages
    while #self.debugText > self.maxDebugMessages do
        table.remove(self.debugText, 1)
    end
end

function Tilemap:init()
    self.debug = true  -- Debug modunu aktifleştir
    State.showWindows.tilemap = false
    State.windowSizes.tilemap = {width = 800, height = 700}
    self:addDebug("Tilemap module initialized")
    
    -- Debug ve hata izleme için ekstra
    love.window.setMode(love.graphics.getWidth(), love.graphics.getHeight(), {resizable = true})
end


function Tilemap:manualLoadTileset(imagePath, name, tileSize)
    self:addDebug("Manual tileset loading attempt: " .. imagePath)
    
    local image
    local success, errorMsg = pcall(function()
        image = love.graphics.newImage(imagePath)
    end)
    
    if not success or not image then
        self:addDebug("FAILED to load image: " .. tostring(errorMsg))
        return nil
    end
    
    self:addDebug("Successfully loaded image: " .. tostring(image))
    self:addDebug("Image dimensions: " .. image:getWidth() .. "x" .. image:getHeight())
    
    local tileset = {
        image = image,
        name = name or imagePath:match("([^/\\]+)$"):gsub("%.%w+$", ""),
        tileSize = tileSize or self.tileSize,
        path = imagePath
    }
    
    tileset.width = image:getWidth()
    tileset.height = image:getHeight()
    tileset.cols = math.floor(tileset.width / tileset.tileSize)
    tileset.rows = math.floor(tileset.height / tileset.tileSize)
    
    self:addDebug("Created tileset: " .. tileset.name)
    self:addDebug("Dimensions: " .. tileset.width .. "x" .. tileset.height)
    self:addDebug("Tiles: " .. tileset.cols .. "x" .. tileset.rows .. " at size " .. tileset.tileSize)
    
    self.tilesets[tileset.name] = tileset
    self.activeTileset = tileset
    
    return tileset
end

function Tilemap:loadAssetAsTileset(asset)
    if not asset then
        self:addDebug("loadAssetAsTileset: asset is nil")
        return nil
    end
    
    self:addDebug("Loading asset as tileset: " .. (asset.name or "unnamed"))
    
    if not asset.data then
        self:addDebug("ERROR: Asset has no data property")
        -- Asset içeriğini debug için göster
        for k, v in pairs(asset) do
            self:addDebug("Asset property: " .. k .. " = " .. tostring(v))
        end
        return nil
    end
    
    -- Asset kontrollerini güçlendir
    local success, imageCheck = pcall(function()
        return type(asset.data) == "userdata" and asset.data:typeOf("Image")
    end)
    
    if not success or not imageCheck then
        self:addDebug("ERROR: Asset data is not a valid Love2D image")
        return nil
    end
    
    -- Tileset oluştur
    local tileset = {
        image = asset.data,
        name = asset.name and asset.name:gsub("%.%w+$", "") or "Unnamed Tileset",
        tileSize = self.tileSize,
        path = asset.path or "unknown"
    }
    
    -- Boyutları kontrol et
    tileset.width = asset.data:getWidth()
    tileset.height = asset.data:getHeight()
    if tileset.width <= 0 or tileset.height <= 0 then
        self:addDebug("ERROR: Image has invalid dimensions: " .. 
            tileset.width .. "x" .. tileset.height)
        return nil
    end
    
    -- Grid hesapla
    tileset.cols = math.floor(tileset.width / tileset.tileSize)
    tileset.rows = math.floor(tileset.height / tileset.tileSize)
    if tileset.cols <= 0 or tileset.rows <= 0 then
        self:addDebug("ERROR: Invalid tile grid: " .. 
            tileset.cols .. "x" .. tileset.rows)
        return nil
    end
    
    self:addDebug(string.format("Tileset created: %s (%dx%d, %dx%d tiles at %dpx)", 
        tileset.name, tileset.width, tileset.height, 
        tileset.cols, tileset.rows, tileset.tileSize))
    
    -- Listeye ekle ve aktifleştir
    self.tilesets[tileset.name] = tileset
    self.activeTileset = tileset
    
    return tileset
end

function Tilemap:createMap(width, height, name)
    local map = {
        width = width,
        height = height,
        name = name,
        layers = {},
        tileSize = self.tileSize
    }
    
    self:addLayer(map, "Background")
    self.maps[name] = map
    self.activeMap = map
    
    self:addDebug("Created map: " .. name .. " (" .. width .. "x" .. height .. ")")
    
    -- Create entity
    if SceneManager and SceneManager.createEntity then
        local entity = SceneManager:createEntity(0, 0)
        entity.type = "tilemap"
        entity.name = "Tilemap: " .. name
        entity.mapName = name
        entity.width = width * self.tileSize
        entity.height = height * self.tileSize
        entity.gridSize = self.gridSize
        entity.showGrid = self.showGrid
        
        entity.components.tilemap = {
            width = width,
            height = height,
            tileSize = self.tileSize,
            layers = map.layers,
            tileset = self.activeTileset,
            name = name
        }
        
        table.insert(self.entities, entity)
        self:addDebug("Added map as entity: " .. entity.name)
    end
    
    return map
end

function Tilemap:addLayer(map, name)
    local layer = {
        name = name,
        tiles = {},
        visible = true
    }
    
    -- Initialize empty grid
    for y = 1, map.height do
        layer.tiles[y] = {}
        for x = 1, map.width do
            layer.tiles[y][x] = nil
        end
    end
    
    table.insert(map.layers, layer)
    self:addDebug("Added layer: " .. name .. " to map: " .. map.name)
    return layer
end

function Tilemap:setTile(map, layer, x, y, tilesetName, tileId)
    if not map or not map.layers[layer] then 
        self:addDebug("ERROR: Invalid map or layer")
        return 
    end
    
    local layerData = map.layers[layer]
    
    if x < 1 or x > map.width or y < 1 or y > map.height then
        self:addDebug(string.format("ERROR: Invalid tile position (%d,%d)", x, y))
        return
    end
    
    if not tilesetName or not tileId then
        self:addDebug("ERROR: Invalid tileset or tile ID")
        return
    end
    
    if not self.tilesets[tilesetName] then
        self:addDebug("ERROR: Tileset not found: " .. tilesetName)
        return
    end
    
    layerData.tiles[y][x] = {
        tilesetName = tilesetName,
        tileId = tileId
    }
    
    if self.debug then
        self:addDebug(string.format("Set tile at (%d,%d) to tile ID %d from tileset %s", 
            x, y, tileId, tilesetName))
    end
end

function Tilemap:getTileFromTileset(tileset, tileId)
    if not tileset then 
        self:addDebug("ERROR: Tileset is nil in getTileFromTileset")
        return nil 
    end
    
    local col = (tileId - 1) % tileset.cols
    local row = math.floor((tileId - 1) / tileset.cols)
    
    -- Validate bounds
    if col < 0 or col >= tileset.cols or row < 0 or row >= tileset.rows then
        self:addDebug(string.format("ERROR: Invalid tile coordinates (%d,%d) for tileset %s", 
            col, row, tileset.name))
        return nil
    end
    
    local quad = love.graphics.newQuad(
        col * tileset.tileSize, 
        row * tileset.tileSize, 
        tileset.tileSize, 
        tileset.tileSize, 
        tileset.width, 
        tileset.height
    )
    
    return {
        quad = quad,
        tileId = tileId,
        col = col,
        row = row
    }
end

function Tilemap:update(dt)

    

    if self.mouseClicked then
        self.selectedTile = hoveredTileId
       -- self:addDebug(string.format("SELECTED tile %d (col: %d, row: %d)", 
          --  hoveredTileId, col, row))
    end

    
     -- Mouse durumunu güncelle
     local wasMouseDown = self.lastMouseDown
     self.lastMouseDown = love.mouse.isDown(1)
     local mouseClicked = self.lastMouseDown and not wasMouseDown
     
     -- Tile yerleştirme
     if self.selectedTile and self.activeTileset and self.activeMap and 
        not imgui.GetWantCaptureMouse() and love.mouse.isDown(1) then
         
         local mouseX, mouseY = love.mouse.getPosition()
         local worldX, worldY
         
         -- Ekran/dünya koordinat dönüşümü
         if Camera then
             worldX = (mouseX - love.graphics.getWidth() / 2) / Camera.scaleX + Camera.x
             worldY = (mouseY - love.graphics.getHeight() / 2) / Camera.scaleY + Camera.y
         else
             worldX = mouseX
             worldY = mouseY
         end
         
         -- Nil değer kontrolü (string.format hatası buradan gelebilir)
         if worldX and worldY and self.gridSize and self.gridSize > 0 then
             -- Grid pozisyonunu hesapla
             local gridX = math.floor(worldX / self.gridSize) + 1
             local gridY = math.floor(worldY / self.gridSize) + 1
             
             -- Sınır kontrolü
             if gridX and gridY and
                gridX >= 1 and gridX <= self.activeMap.width and
                gridY >= 1 and gridY <= self.activeMap.height then
                 
                 -- Karo yerleştir
                 self:setTile(
                     self.activeMap, 
                     1, -- İlk katmana ekle
                     gridX, 
                     gridY, 
                     self.activeTileset.name, 
                     self.selectedTile
                 )
                 
                 -- Debug
                 if mouseClicked then
                     self:addDebug(string.format("Placed tile %d at (%d,%d)", 
                         self.selectedTile, gridX, gridY))
                 end
             end
         end
     end
    
    -- Remember mouse state for next frame
    self.lastMouseDown = love.mouse.isDown(1)
end

function Tilemap:drawDebugPanel()
    if not self.debug then return end
    
    -- Draw debug info in a separate panel
    imgui.Begin("Tilemap Debug Info")
    
    imgui.Text("Active Tileset: " .. (self.activeTileset and self.activeTileset.name or "None"))
    if self.activeTileset then
        imgui.Text(string.format("Tileset size: %dx%d", self.activeTileset.width, self.activeTileset.height))
        imgui.Text(string.format("Tile grid: %dx%d (size: %d)", 
            self.activeTileset.cols, self.activeTileset.rows, self.activeTileset.tileSize))
    end
    
    imgui.Text("Selected Tile ID: " .. (self.selectedTile or "None"))
    
    -- Active map info
    imgui.Text("Active Map: " .. (self.activeMap and self.activeMap.name or "None"))
    if self.activeMap then
        imgui.Text(string.format("Map size: %dx%d", self.activeMap.width, self.activeMap.height))
        imgui.Text(string.format("Layers: %d", #self.activeMap.layers))
    end
    
    -- Testing buttons
    if imgui.Button("Test Default Tileset") then
        self:manualLoadTileset("assets/tilesets/example.png", "Example Tileset", 32)
    end
    
    if imgui.Button("Load From Selected Asset") then
        if State.selectedAsset then
            self:addDebug("Attempting to load from selected asset: " .. (State.selectedAsset.name or "unnamed"))
            self:loadAssetAsTileset(State.selectedAsset)
        else
            self:addDebug("No asset currently selected")
        end
    end
    
    if State.assets and #State.assets > 0 then
        if imgui.CollapsingHeader("Available Assets") then
            for i, asset in ipairs(State.assets) do
                if asset.type == "image" then
                    if imgui.Button("Load ##" .. i .. asset.name) then
                        self:loadAssetAsTileset(asset)
                    end
                    imgui.SameLine()
                    imgui.Text(asset.name .. " (" .. asset.type .. ")")
                end
            end
        end
    end
    
    -- Debug log
    if imgui.CollapsingHeader("Debug Log") then
        for i, message in ipairs(self.debugText) do
            imgui.Text(message)
        end
    end
    
    imgui.End()
end

function Tilemap:drawTilemapWindow()
    -- drawTilemapWindow fonksiyonunun başında debug penceresi ekleyelim
    if self.debug then
        imgui.Begin("Tilemap Debug")
        
        imgui.Text("Tileset Info:")
        if self.activeTileset then
            imgui.Text(string.format("Name: %s", self.activeTileset.name))
            imgui.Text(string.format("Size: %dx%d", self.activeTileset.width, self.activeTileset.height))
            imgui.Text(string.format("Tile Grid: %dx%d at %dpx", 
                self.activeTileset.cols, self.activeTileset.rows, self.activeTileset.tileSize))
            
            -- Görüntü kontrolü
            if imgui.Button("Show Raw Image") then
                -- Yeni pencerede görüntüyü göster
                love.graphics.push("all")
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.draw(self.activeTileset.image, 100, 100)
                love.graphics.pop()
            end
        else
            imgui.Text("No active tileset")
        end
        
        imgui.Separator()
        
        -- Mouse bilgileri
        local mx, my = love.mouse.getPosition()
        imgui.Text(string.format("Mouse: %d,%d", mx, my))
        
        -- Debug log
        if imgui.CollapsingHeader("Debug Log") then
            for i, msg in ipairs(self.debugText) do
                imgui.Text(msg)
            end
        end
        
        if imgui.Button("Clear Debug") then
            self.debugText = {}
        end
        
        imgui.End()
    end

    if not State.showWindows.tilemap then return end
    
    -- Draw debug panel first
    self:drawDebugPanel()
    
    self.showTilemapWindow = true
    
    imgui.SetNextWindowSize(State.windowSizes.tilemap.width, State.windowSizes.tilemap.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Tilemap Editor", State.showWindows.tilemap) then
        if imgui.BeginMenuBar then
            if imgui.BeginMenuBar() then
                if imgui.BeginMenu("File") then
                    if imgui.MenuItem("New Map") then
                        self:createMap(20, 15, "New Map")
                    end
                    
                    if imgui.MenuItem("Show Debug Panel") then
                        self.debug = not self.debug
                        self:addDebug("Debug mode: " .. tostring(self.debug))
                    end
                    
                    imgui.EndMenu()
                end
                
                if imgui.BeginMenu("View") then
                    local showGridChanged = imgui.MenuItem("Show Grid", nil, self.showGrid)
                    if showGridChanged then
                        self.showGrid = not self.showGrid
                    end
                    
                    imgui.EndMenu()
                end
                
                imgui.EndMenuBar()
            end
        end
        
        -- Split view: left panel for tileset, right panel for map settings
        imgui.BeginChild("LeftPanel", imgui.GetWindowWidth() * 0.6, 0, true)
        
        -- Load tileset section
        imgui.Text("Tileset")
        imgui.Separator()
        
        -- Direct load from State.assets
        if imgui.Button("Load From Assets") then
            imgui.OpenPopup("DirectAssetLoadPopup")
        end
        
        -- Asset loading popup
        if imgui.BeginPopup("DirectAssetLoadPopup") then
            imgui.Text("Select an image:")
            imgui.Separator()
            
            -- Check how many assets are available
            local assetCount = 0
            if State.assets then 
                assetCount = #State.assets
                self:addDebug("Assets to choose from: " .. assetCount)
            else
                self:addDebug("State.assets is nil")
            end
            
            if assetCount > 0 then
                for i, asset in ipairs(State.assets) do
                    if asset.type == "image" then
                        local assetName = asset.name or ("Asset " .. i)
                        self:addDebug("Listing asset: " .. assetName)
                        
                        if imgui.Selectable(assetName) then
                            self:addDebug("Selected asset: " .. assetName)
                            self:loadAssetAsTileset(asset)
                            imgui.CloseCurrentPopup()
                        end
                    end
                end
            else
                imgui.Text("No image assets found")
            end
            
            imgui.EndPopup()
        end
        
        -- Tileset preview
        if self.activeTileset then
            imgui.Text("Current Tileset: " .. self.activeTileset.name)
            
            local newTileSize = imgui.SliderInt("Tile Size", self.activeTileset.tileSize, 8, 128)
            if newTileSize ~= self.activeTileset.tileSize then
                self.activeTileset.tileSize = newTileSize
                self.activeTileset.cols = math.floor(self.activeTileset.width / newTileSize)
                self.activeTileset.rows = math.floor(self.activeTileset.height / newTileSize)
                self:addDebug("Updated tile size to: " .. newTileSize)
            end
            
            local newPreviewScale = imgui.SliderFloat("Preview Scale", self.previewScale, 0.5, 4.0)
            if newPreviewScale ~= self.previewScale then
                self.previewScale = newPreviewScale
            end
            
            -- Tileset details
            imgui.Text(string.format("Tileset size: %dx%d pixels", 
                self.activeTileset.width, self.activeTileset.height))
            imgui.Text(string.format("Tile grid: %dx%d (%d tiles)", 
                self.activeTileset.cols, self.activeTileset.rows,
                self.activeTileset.cols * self.activeTileset.rows))
            
            -- Selected tile info
            if self.selectedTile then
                local tile = self:getTileFromTileset(self.activeTileset, self.selectedTile)
                if tile then
                    imgui.Text(string.format("Selected: Tile %d (Col: %d, Row: %d)", 
                        self.selectedTile, tile.col + 1, tile.row + 1))
                else
                    imgui.Text("Selected: Tile " .. self.selectedTile .. " (invalid)")
                end
            else
                imgui.Text("No tile selected")
            end
            
            -- Tileset preview
            local previewWidth = math.min(
                self.activeTileset.width * self.previewScale,
                imgui.GetWindowWidth() - 20
            )
            local previewHeight = math.min(
                self.activeTileset.height * self.previewScale,
                imgui.GetWindowHeight() - 200
            )
            
            imgui.BeginChild("TilesetPreview", previewWidth, previewHeight, true)
            
            -- Get cursor position for drawing
            local cx, cy = 0, 0
            if imgui.GetCursorScreenPos then
                cx, cy = imgui.GetCursorScreenPos()
            else
                -- Fallback olarak window pozisyonunu kullan
                local wx, wy = 0, 0
                if imgui.GetWindowPos then
                    wx, wy = imgui.GetWindowPos()
                end
                cx = wx + 10  -- Window içinde margin ekle
                cy = wy + 50  -- Window içinde margin ekle
            end
            
            -- ImGui ve Love arasındaki koordinat çevirisi için daha net olalım
            love.graphics.push()
            love.graphics.translate(cx, cy)
            -- Tileset çizimi
            love.graphics.setColor(1, 1, 1, 1)
            self.activeTileset.image:setFilter("nearest", "nearest")
            love.graphics.draw(
                self.activeTileset.image, 
                0, 0, 
                0, 
                self.previewScale, 
                self.previewScale
            )
            
            -- Draw grid
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.setLineWidth(1)
            
            -- Vertical lines
            for x = 0, self.activeTileset.cols do
                love.graphics.line(
                    cx + x * self.activeTileset.tileSize * self.previewScale,
                    cy,
                    cx + x * self.activeTileset.tileSize * self.previewScale,
                    cy + self.activeTileset.height * self.previewScale
                )
            end
            
            -- Horizontal lines
            for y = 0, self.activeTileset.rows do
                love.graphics.line(
                    cx,
                    cy + y * self.activeTileset.tileSize * self.previewScale,
                    cx + self.activeTileset.width * self.previewScale,
                    cy + y * self.activeTileset.tileSize * self.previewScale
                )
            end
            
            -- Handle mouse interaction
            local mouseX, mouseY = love.mouse.getPosition()
            local windowX, windowY = 0, 0
            if imgui.GetWindowPos then
                windowX, windowY = imgui.GetWindowPos()
            end

            local tilesetX = (mouseX - cx) / self.previewScale
            local tilesetY = (mouseY - cy) / self.previewScale

            -- Debug bilgileri
            self:addDebug(string.format("Mouse: %d,%d, Tileset offset: %d,%d", 
            mouseX, mouseY, cx, cy))
            self:addDebug(string.format("Relative: %d,%d", tilesetX, tilesetY))

            
            -- Check if mouse is over the tileset
            if tilesetX >= 0 and tilesetX < self.activeTileset.width and
               tilesetY >= 0 and tilesetY < self.activeTileset.height then
                
                -- Calculate tile coordinates
                local col = math.floor(tilesetX / self.activeTileset.tileSize)
                local row = math.floor(tilesetY / self.activeTileset.tileSize)
                
                 -- Geçerli sınırlar içinde mi kontrol et
                if col >= 0 and col < self.activeTileset.cols and
                row >= 0 and row < self.activeTileset.rows then
                
                    -- Hover bilgisi ve vurgu
                    local hoveredTileId = row * self.activeTileset.cols + col + 1
                    
                    -- Debug için hover bilgisini göster
                    self:addDebug(string.format("Hovering tile: %d (col: %d, row: %d)", 
                        hoveredTileId, col, row))
                end   
                    
                -- Highlight hovered tile
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.rectangle(
                    "fill",
                    cx + col * self.activeTileset.tileSize * self.previewScale,
                    cy + row * self.activeTileset.tileSize * self.previewScale,
                    self.activeTileset.tileSize * self.previewScale,
                    self.activeTileset.tileSize * self.previewScale
                )
                
                -- Calculate tile ID
                local hoveredTileId = row * self.activeTileset.cols + col + 1
                
                -- Select tile on click
                if love.mouse.isDown(1) and not self.lastMouseDown then
                    self.selectedTile = hoveredTileId
                    self:addDebug(string.format("Selected tile %d (col: %d, row: %d)", 
                        hoveredTileId, col, row))
                    self.lastMouseDown = true
                end
                
                -- Show hover info
                love.graphics.setColor(1, 1, 1, 1)
                love.graphics.print(
                    string.format("Tile: %d (%d,%d)", hoveredTileId, col, row),
                    cx + 5,
                    cy + self.activeTileset.height * self.previewScale - 20
                )
            end
            
            -- Highlight selected tile if any
            if self.selectedTile then
                local tile = self:getTileFromTileset(self.activeTileset, self.selectedTile)
                if tile then
                    love.graphics.setColor(0, 1, 0, 0.5)
                    love.graphics.rectangle(
                        "fill",
                        cx + tile.col * self.activeTileset.tileSize * self.previewScale,
                        cy + tile.row * self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale
                    )
                    
                    -- Add border to selected tile
                    love.graphics.setColor(0, 1, 0, 1)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle(
                        "line",
                        cx + tile.col * self.activeTileset.tileSize * self.previewScale,
                        cy + tile.row * self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale
                    )
                    
                    -- Show selection info
                    love.graphics.setColor(0, 0, 0, 0.7)
                    love.graphics.rectangle(
                        "fill",
                        cx + 5,
                        cy + 5,
                        200,
                        25
                    )
                    love.graphics.setColor(0, 1, 0, 1)
                    love.graphics.print(
                        string.format("Selected: Tile %d (%d,%d)", 
                            self.selectedTile, tile.col, tile.row),
                        cx + 10,
                        cy + 10
                    )
                end
            end
            
            love.graphics.pop()
            
            imgui.EndChild()
        else
            imgui.Text("No tileset loaded")
            
            -- Display direct asset loading options
            if State.assets and #State.assets > 0 then
                imgui.Text("Available image assets:")
                
                for i, asset in ipairs(State.assets) do
                    if asset.type == "image" then
                        if imgui.Button("Load " .. asset.name) then
                            self:loadAssetAsTileset(asset)
                        end
                    end
                end
            else
                imgui.Text("No image assets available. Import some first.")
            end
        end
        
        imgui.EndChild()
        
        -- Right panel: Map settings
        imgui.SameLine()
        imgui.BeginChild("RightPanel", 0, 0, true)
        
        imgui.Text("Map Settings")
        imgui.Separator()
        
        -- Create new map button
        if imgui.Button("New Map") then
            self:createMap(20, 15, "New Map")
        end
        
        -- Map selection if multiple maps exist
        if self.maps and next(self.maps) then
            local mapNames = {}
            local currentMapIndex = 1
            local i = 1
            
            for name, _ in pairs(self.maps) do
                mapNames[i] = name
                if self.activeMap and self.activeMap.name == name then
                    currentMapIndex = i
                end
                i = i + 1
            end
            
            local comboStr = table.concat(mapNames, "\0") .. "\0"
            local newIndex = imgui.Combo("##MapCombo", currentMapIndex - 1, comboStr)
            
            if type(newIndex) ~= "boolean" and newIndex ~= (currentMapIndex - 1) then
                self.activeMap = self.maps[mapNames[newIndex + 1]]
                self:addDebug("Selected map: " .. mapNames[newIndex + 1])
            end
        end
        
        -- Map properties if a map is active
        if self.activeMap then
            -- Current map info
            imgui.Text(string.format("Current map: %s (%dx%d)", 
                self.activeMap.name, self.activeMap.width, self.activeMap.height))
            
            -- Map dimensions
            imgui.PushItemWidth(80)
            
            local width = imgui.InputInt("Width##Map", self.activeMap.width)
            if width ~= self.activeMap.width and width > 0 then
                -- Store original dimensions
                local oldWidth = self.activeMap.width
                
                -- Update map width
                self.activeMap.width = width
                self:addDebug("Changed map width to: " .. width)
                
                -- Update entity if exists
                for _, entity in ipairs(self.entities) do
                    if entity.mapName == self.activeMap.name then
                        entity.width = width * self.activeMap.tileSize
                        if entity.components and entity.components.tilemap then
                            entity.components.tilemap.width = width
                        end
                    end
                end
                
                -- Resize all layers
                for _, layer in ipairs(self.activeMap.layers) do
                    -- For each row
                    for y = 1, self.activeMap.height do
                        -- Create row if it doesn't exist
                        if not layer.tiles[y] then
                            layer.tiles[y] = {}
                        end
                        
                        -- If expanding, initialize new cells
                        if width > oldWidth then
                            for x = oldWidth + 1, width do
                                layer.tiles[y][x] = nil
                            end
                        end
                    end
                end
            end
            
            imgui.SameLine()
            
            local height = imgui.InputInt("Height##Map", self.activeMap.height)
            if height ~= self.activeMap.height and height > 0 then
                -- Store original dimensions
                local oldHeight = self.activeMap.height
                
                -- Update map height
                self.activeMap.height = height
                self:addDebug("Changed map height to: " .. height)
                
                -- Update entity if exists
                for _, entity in ipairs(self.entities) do
                    if entity.mapName == self.activeMap.name then
                        entity.height = height * self.activeMap.tileSize
                        if entity.components and entity.components.tilemap then
                            entity.components.tilemap.height = height
                        end
                    end
                end
                
                -- Resize all layers
                for _, layer in ipairs(self.activeMap.layers) do
                    -- If expanding, create new rows
                    if height > oldHeight then
                        for y = oldHeight + 1, height do
                            layer.tiles[y] = {}
                            for x = 1, self.activeMap.width do
                                layer.tiles[y][x] = nil
                            end
                        end
                    -- If shrinking, remove rows
                    elseif height < oldHeight then
                        for y = height + 1, oldHeight do
                            layer.tiles[y] = nil
                        end
                    end
                end
            end
            
            imgui.PopItemWidth()
            
            -- Grid size slider
            local newGridSize = imgui.SliderInt("Grid Size", self.gridSize, 16, 64)
            if newGridSize ~= self.gridSize then
                self.gridSize = newGridSize
                self:addDebug("Changed grid size to: " .. newGridSize)
                
                -- Update entities
                for _, entity in ipairs(self.entities) do
                    if entity.type == "tilemap" then
                        entity.gridSize = self.gridSize
                    end
                end
            end
            
            -- Show grid checkbox
            local showGridChanged = imgui.Checkbox("Show Grid", self.showGrid)
            if showGridChanged ~= self.showGrid then
                self.showGrid = showGridChanged
                self:addDebug("Show grid: " .. tostring(self.showGrid))
                
                -- Update entities
                for _, entity in ipairs(self.entities) do
                    if entity.type == "tilemap" then
                        entity.showGrid = self.showGrid
                    end
                end
            end
            
            imgui.Separator()
            
            -- Layer management
            imgui.Text("Layers:")
            
            for i, layer in ipairs(self.activeMap.layers) do
                if imgui.CollapsingHeader(layer.name .. "##Layer" .. i) then
                    -- Layer name input
                    local layerName = imgui.InputText("Name##Layer" .. i, layer.name, 100)
                    if layerName ~= layer.name then
                        layer.name = layerName
                        self:addDebug("Renamed layer to: " .. layerName)
                    end
                    
                    -- Layer visibility toggle
                    local visible = imgui.Checkbox("Visible##Layer" .. i, layer.visible)
                    if visible ~= layer.visible then
                        layer.visible = visible
                        self:addDebug("Layer visibility: " .. tostring(visible))
                    end
                    
                    -- Clear layer button
                    if imgui.Button("Clear Layer##" .. i) then
                        for y = 1, self.activeMap.height do
                            for x = 1, self.activeMap.width do
                                layer.tiles[y][x] = nil
                            end
                        end
                        self:addDebug("Cleared layer: " .. layer.name)
                    end
                end
            end
            
            -- Add new layer button
            if imgui.Button("Add Layer") then
                self:addLayer(self.activeMap, "New Layer")
            end
        end
        
        imgui.EndChild()
        
        imgui.End()
    end
end

function Tilemap:drawMap(map, gridSize, showGrid)
    if not map then return end

    gridSize = gridSize or self.gridSize
    if showGrid == nil then showGrid = self.showGrid end

    -- Draw each layer
    for layerIndex, layer in ipairs(map.layers) do
    if layer.visible then
        for y = 1, map.height do
            for x = 1, map.width do
                local tile = layer.tiles[y][x]
                if tile then
                    local tileset = self.tilesets[tile.tilesetName]
                    if tileset then
                        local tileData = self:getTileFromTileset(tileset, tile.tileId)
                        if tileData then
                            love.graphics.setColor(1, 1, 1, 1)
                            love.graphics.draw(
                                tileset.image,
                                tileData.quad,
                                (x - 1) * gridSize,
                                (y - 1) * gridSize,
                                0,
                                gridSize / tileset.tileSize,
                                gridSize / tileset.tileSize
                            )
                        end
                    end
                end
            end
        end
    end
    end

    -- Draw grid
    if showGrid then
    love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
    love.graphics.setLineWidth(1)

    -- Horizontal lines
    for y = 0, map.height do
        love.graphics.line(
            0, 
            y * gridSize, 
            map.width * gridSize, 
            y * gridSize
        )
    end

    -- Vertical lines
    for x = 0, map.width do
        love.graphics.line(
            x * gridSize, 
            0, 
            x * gridSize, 
            map.height * gridSize
        )
    end

    love.graphics.setColor(1, 1, 1, 1)
    end
end

function Tilemap:drawEntity(entity)
    if not entity or not entity.mapName then return end

    local map = self.maps[entity.mapName]
    if not map then return end

    love.graphics.push()

    -- Convert coordinates to numbers
    local x = tonumber(entity.x) or 0
    local y = tonumber(entity.y) or 0
    local rotation = tonumber(entity.rotation) or 0
    local scaleX = tonumber(entity.scaleX) or 1
    local scaleY = tonumber(entity.scaleY) or 1

    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    love.graphics.scale(scaleX, scaleY)

    -- Check visibility
    if entity.visible == false then 
        love.graphics.pop()
    return 
    end

    -- Draw the map
    self:drawMap(map, entity.gridSize or self.gridSize, entity.showGrid)

    love.graphics.pop()
end

function Tilemap:drawInScene()
    -- Draw active map (editor view)
    if self.activeMap then
    self:drawMap(self.activeMap, self.gridSize, self.showGrid)
    end

    -- Draw all tilemap entities
    for _, entity in ipairs(SceneManager.entities or {}) do
        if entity.type == "tilemap" or (entity.components and entity.components.tilemap) then
            self:drawEntity(entity)
        end
    end

    -- Draw hover preview of selected tile
    if self.selectedTile and self.activeTileset and not imgui.GetWantCaptureMouse() then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY

        -- Convert screen coords to world coords
        if Camera then
            worldX = (mouseX - love.graphics.getWidth() / 2) / Camera.scaleX + Camera.x
            worldY = (mouseY - love.graphics.getHeight() / 2) / Camera.scaleY + Camera.y
        else
            worldX = mouseX
            worldY = mouseY
        end

        -- Calculate grid position
        local gridX = math.floor(worldX / self.gridSize)
        local gridY = math.floor(worldY / self.gridSize)

        -- Draw tile preview
        local tileData = self:getTileFromTileset(self.activeTileset, self.selectedTile)
        if tileData then
            love.graphics.setColor(1, 1, 1, 0.7) -- Semi-transparent
            love.graphics.draw(
                self.activeTileset.image,
                tileData.quad,
                gridX * self.gridSize,
                gridY * self.gridSize,
                0,
                self.gridSize / self.activeTileset.tileSize,
                self.gridSize / self.activeTileset.tileSize
            )
            
            -- Highlight grid cell
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.rectangle(
                "line",
                gridX * self.gridSize,
                gridY * self.gridSize,
                self.gridSize,
                self.gridSize
            )
            love.graphics.setColor(1, 1, 1, 1)
        end
    end
end


function Tilemap:draw()
    self:drawTilemapWindow()
end

return Tilemap