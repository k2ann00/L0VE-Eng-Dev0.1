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
    lastMouseDown = false,  -- Mouse'un son durumunu izlemek için
    entities = {} -- Tilemap entity'lerini saklamak için
}

function Tilemap:init()
    State.showWindows.tilemap = false
    State.windowSizes.tilemap = {width = 700, height = 700}
    Console:log("Tilemap module initialized")
end

function Tilemap:loadTileset(asset, name, tileSize)
    -- Asset direk verilmiş olabilir veya path olarak gelmiş olabilir
    local tileset
    
    if type(asset) == "string" then
        -- Path verilmiş, image yükle
        tileset = {
            image = love.graphics.newImage(asset),
            name = name or asset:match("([^/\\]+)$"):gsub("%.%w+$", ""),
            tileSize = tileSize or self.tileSize,
            path = asset
        }
    else
        -- Asset objesi verilmiş
        tileset = {
            image = asset.data,
            name = name or asset.name:gsub("%.%w+$", ""),
            tileSize = tileSize or self.tileSize,
            path = asset.path
        }
    end
    
    tileset.width = tileset.image:getWidth()
    tileset.height = tileset.image:getHeight()
    tileset.cols = math.floor(tileset.width / tileset.tileSize)
    tileset.rows = math.floor(tileset.height / tileset.tileSize)
    
    self.tilesets[tileset.name] = tileset
    
    if not self.activeTileset then
        self.activeTileset = tileset
    end
    
    Console:log("Tileset loaded: " .. tileset.name)
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
    
    -- Varsayılan katman oluştur
    self:addLayer(map, "Background")
    
    self.maps[name] = map
    
    if not self.activeMap then
        self.activeMap = map
    end
    
    Console:log("Map created: " .. name)
    
    -- Haritayı otomatik olarak entity olarak ekle
    if SceneManager and SceneManager.createEntity then
        local entity = SceneManager:createEntity(0, 0)
        entity.type = "tilemap"
        entity.name = "Tilemap: " .. name
        entity.mapName = name
        entity.width = width * self.tileSize
        entity.height = height * self.tileSize
        entity.gridSize = self.gridSize
        entity.showGrid = self.showGrid
        
        -- Tilemap component'i ekle
        entity.components.tilemap = {
            width = width,
            height = height,
            tileSize = self.tileSize,
            layers = map.layers,
            tileset = self.activeTileset,
            name = name
        }
        
        -- Tilemap entity'lerini takip etmek için listeye ekle
        table.insert(self.entities, entity)
        
        Console:log("Map added as entity: " .. name)
    else
        Console:log("Warning: SceneManager not found, could not add map as entity")
    end
    
    return map
end

function Tilemap:addLayer(map, name)
    local layer = {
        name = name,
        tiles = {},
        visible = true
    }
    
    -- Boş grid oluştur
    for y = 1, map.height do
        layer.tiles[y] = {}
        for x = 1, map.width do
            layer.tiles[y][x] = nil -- nil = boş karo
        end
    end
    
    table.insert(map.layers, layer)
    return layer
end

function Tilemap:setTile(map, layer, x, y, tilesetName, tileId)
    if not map or not map.layers[layer] then 
        Console:log("Error: Invalid map or layer")
        return 
    end
    
    local layerData = map.layers[layer]
    
    if x < 1 or x > map.width or y < 1 or y > map.height then
        Console:log(string.format("Error: Invalid tile position (%d,%d)", x, y))
        return
    end
    
    if not tilesetName or not tileId then
        Console:log("Error: Invalid tileset or tile ID")
        return
    end
    
    -- Tileset'in var olduğundan emin ol
    if not self.tilesets[tilesetName] then
        Console:log("Error: Tileset not found: " .. tilesetName)
        return
    end
    
    layerData.tiles[y][x] = {
        tilesetName = tilesetName,
        tileId = tileId
    }
end

function Tilemap:getTileFromTileset(tileset, tileId)
    if not tileset then return nil end
    
    local col = (tileId - 1) % tileset.cols
    local row = math.floor((tileId - 1) / tileset.cols)
    
    return {
        quad = love.graphics.newQuad(
            col * tileset.tileSize, 
            row * tileset.tileSize, 
            tileset.tileSize, 
            tileset.tileSize, 
            tileset.width, 
            tileset.height
        ),
        tileId = tileId,
        col = col,
        row = row
    }
end

function Tilemap:getTileIdFromPosition(tileset, x, y)
    if not tileset then return nil end
    
    local col = math.floor(x / tileset.tileSize)
    local row = math.floor(y / tileset.tileSize)
    
    if col < 0 or col >= tileset.cols or row < 0 or row >= tileset.rows then
        return nil
    end
    
    return row * tileset.cols + col + 1
end

function Tilemap:screenToWorld(screenX, screenY)
    if Camera and Camera.screenToWorld then
        return Camera:screenToWorld(screenX, screenY)
    else
        local worldX = (screenX - love.graphics.getWidth() / 2) / Camera.scaleX + Camera.x
        local worldY = (screenY - love.graphics.getHeight() / 2) / Camera.scaleY + Camera.y
        return worldX, worldY
    end
end

function Tilemap:update(dt)
    -- Sahne üzerine karo yerleştirme
    if self.selectedTile and self.activeTileset and self.activeMap and 
       not imgui.GetWantCaptureMouse() and love.mouse.isDown(1) then
        
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = self:screenToWorld(mouseX, mouseY)
        
        -- Grid pozisyonunu hesapla
        local gridX = math.floor(worldX / self.gridSize) + 1
        local gridY = math.floor(worldY / self.gridSize) + 1
        
        -- Geçerli grid sınırları içinde olduğundan emin ol
        if gridX >= 1 and gridX <= self.activeMap.width and
           gridY >= 1 and gridY <= self.activeMap.height then
            
            -- Karo yerleştir
            self:setTile(
                self.activeMap, 
                1, -- Aktif katman (şimdilik sadece ilk katman)
                gridX, 
                gridY, 
                self.activeTileset.name, 
                self.selectedTile
            )
        end
    end
end

function Tilemap:drawTilemapWindow()
    if not State.showWindows.tilemap then return end
    
    self.showTilemapWindow = true
    
    imgui.SetNextWindowSize(State.windowSizes.tilemap.width, State.windowSizes.tilemap.height, imgui.Cond_FirstUseEver)
    if imgui.Begin("Tilemap Editor", State.showWindows.tilemap) then
        if imgui.BeginMenuBar then
            if imgui.BeginMenuBar() then
                if imgui.BeginMenu("File") then
                    if imgui.MenuItem("New Map") then
                        -- Yeni harita oluşturma işlevi
                        local width = 20
                        local height = 15
                        self:createMap(width, height, "New Map")
                    end
                    
                    if imgui.MenuItem("Load Tileset") then
                        -- Tileset yükleme işlevi burada
                        Console:log("Please select an image asset from Asset Manager")
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
        
        -- Sol panel: Tileset seçimi ve önizleme
        imgui.BeginChild("LeftPanel", imgui.GetWindowWidth() * 0.6, 0, true)
        
        -- Tileset seçimi
        if self.tilesets and next(self.tilesets) then
            imgui.Text("Active Tileset:")
            
            local tilesetNames = {}
            local currentTilesetIndex = 1
            local i = 1
            
            for name, _ in pairs(self.tilesets) do
                tilesetNames[i] = name
                if self.activeTileset and self.activeTileset.name == name then
                    currentTilesetIndex = i
                end
                i = i + 1
            end
            
            -- ImGui Combo fonksiyonu
            local comboStr = table.concat(tilesetNames, "\0") .. "\0"
            local newIndex = imgui.Combo("##TilesetCombo", currentTilesetIndex - 1, comboStr)
            
            -- newIndex bir boolean değeri olabilir, bunu indekse çevirmeliyiz
            if type(newIndex) ~= "boolean" and newIndex ~= (currentTilesetIndex - 1) then
                self.activeTileset = self.tilesets[tilesetNames[newIndex + 1]]
            end
        else
            if imgui.Button("Load Tileset") then
                -- Örnek: Bir asset seçilmişse tileset olarak yükle
                if State.selectedAsset and State.selectedAsset.type == "image" then
                    self:loadTileset(State.selectedAsset)
                else
                    Console:log("Please select an image asset first!")
                end
            end
        end
        
        -- Tileset önizleme
        if self.activeTileset then
            imgui.Separator()
            imgui.Text("Tileset Preview:")
            
            -- Dinamik tile boyutu ayarı
            local newTileSize = imgui.SliderInt("Tile Size", self.activeTileset.tileSize, 8, 128)
            if newTileSize ~= self.activeTileset.tileSize then
                -- Tileset'in tile boyutunu güncelle
                self.activeTileset.tileSize = newTileSize
                self.activeTileset.cols = math.floor(self.activeTileset.width / self.activeTileset.tileSize)
                self.activeTileset.rows = math.floor(self.activeTileset.height / self.activeTileset.tileSize)
                Console:log("Updated tileset tile size to: " .. newTileSize)
            end
            
            -- Önizleme boyutu ayarı
            local newPreviewScale = imgui.SliderFloat("Preview Scale", self.previewScale, 0.5, 4.0)
            if newPreviewScale ~= self.previewScale then
                self.previewScale = newPreviewScale
            end
            
            -- Tileset bilgileri
            imgui.Text(string.format("Size: %dx%d, Tiles: %dx%d", 
                self.activeTileset.width, 
                self.activeTileset.height,
                self.activeTileset.cols,
                self.activeTileset.rows
            ))
            
            -- Seçilen karo bilgisi
            if self.selectedTile then
                local tile = self:getTileFromTileset(self.activeTileset, self.selectedTile)
                if tile then
                    imgui.Text(string.format("Selected Tile: %d (Column: %d, Row: %d)", 
                        self.selectedTile, tile.col + 1, tile.row + 1))
                else
                    imgui.Text("Selected Tile: " .. self.selectedTile)
                end
            else
                imgui.Text("No tile selected")
            end
            
            -- Tileset Grid önizleme alanı
            local imageWidth = self.activeTileset.width * self.previewScale
            local imageHeight = self.activeTileset.height * self.previewScale
            
            local availWidth = imgui.GetWindowWidth() - 20
            local availHeight = imgui.GetWindowHeight() - 180
            
            local previewWidth = math.min(imageWidth, availWidth)
            local previewHeight = math.min(imageHeight, availHeight)
            
            imgui.BeginChild("TilesetPreview", previewWidth, previewHeight, true)
            
            -- ImGui penceresinin pozisyonunu al
            local wx, wy = 0, 0
            local cx, cy = 0, 0
            
            if imgui.GetWindowPos then
                wx, wy = imgui.GetWindowPos()
            end
            
            if imgui.GetCursorScreenPos then
                cx, cy = imgui.GetCursorScreenPos()
            end
            
            local mouseX, mouseY = love.mouse.getPosition()
            
            -- Sprite sheet'i çiz
            love.graphics.push("all")
            
            -- Sprite sheet'i çiz
            love.graphics.setColor(1, 1, 1, 1)
            self.activeTileset.image:setFilter("nearest", "nearest")
            love.graphics.draw(
                self.activeTileset.image, 
                cx, 
                cy, 
                0, 
                self.previewScale, 
                self.previewScale
            )
            
            -- Grid çizgileri
            love.graphics.setColor(1, 1, 0, 0.5)
            love.graphics.setLineWidth(1)
            
            -- Dikey çizgiler
            for x = 0, self.activeTileset.cols do
                love.graphics.line(
                    cx + x * self.activeTileset.tileSize * self.previewScale,
                    cy,
                    cx + x * self.activeTileset.tileSize * self.previewScale,
                    cy + self.activeTileset.height * self.previewScale
                )
            end
            
            -- Yatay çizgiler
            for y = 0, self.activeTileset.rows do
                love.graphics.line(
                    cx,
                    cy + y * self.activeTileset.tileSize * self.previewScale,
                    cx + self.activeTileset.width * self.previewScale,
                    cy + y * self.activeTileset.tileSize * self.previewScale
                )
            end
            
            -- Fare pozisyonunu hesapla ve seçilen tile'ı vurgula
            local tilesetX = (mouseX - cx) / self.previewScale
            local tilesetY = (mouseY - cy) / self.previewScale
            
            -- Fare tileset üzerinde mi kontrol et
            if tilesetX >= 0 and tilesetX < self.activeTileset.width and
               tilesetY >= 0 and tilesetY < self.activeTileset.height then
                
                -- Üzerinde gezinilen karoyu hesapla
                local col = math.floor(tilesetX / self.activeTileset.tileSize)
                local row = math.floor(tilesetY / self.activeTileset.tileSize)
                
                -- Gezinilen karoyu vurgula
                love.graphics.setColor(1, 1, 0, 0.3)
                love.graphics.rectangle(
                    "fill",
                    cx + col * self.activeTileset.tileSize * self.previewScale,
                    cy + row * self.activeTileset.tileSize * self.previewScale,
                    self.activeTileset.tileSize * self.previewScale,
                    self.activeTileset.tileSize * self.previewScale
                )
                
                -- Tile ID'sini hesapla
                local hoveredTileId = row * self.activeTileset.cols + col + 1
                
                -- Fare tıklaması ile karo seç
                if love.mouse.isDown(1) and not self.lastMouseDown then
                    self.selectedTile = hoveredTileId
                    Console:log("Selected tile: " .. self.selectedTile)
                    self.lastMouseDown = true
                end
            end
            
            -- Seçili tile'ı vurgula
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
                    
                    -- Seçili tile'ın kenarını daha belirgin göster
                    love.graphics.setColor(0, 1, 0, 1)
                    love.graphics.setLineWidth(2)
                    love.graphics.rectangle(
                        "line",
                        cx + tile.col * self.activeTileset.tileSize * self.previewScale,
                        cy + tile.row * self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale,
                        self.activeTileset.tileSize * self.previewScale
                    )
                end
            end
            
            love.graphics.pop()
            
            -- Mouse durumunu güncelle
            if not love.mouse.isDown(1) then
                self.lastMouseDown = false
            end
            
            imgui.EndChild()
        end
        
        imgui.EndChild()
        
        -- Sağ panel: Harita ayarları
        imgui.SameLine()
        imgui.BeginChild("RightPanel", 0, 0, true)
        
        imgui.Text("Map Settings:")
        
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
            end
        else
            if imgui.Button("New Map") then
                self:createMap(20, 15, "New Map")
            end
        end
        
        if self.activeMap then
            imgui.Text(string.format("Size: %dx%d", self.activeMap.width, self.activeMap.height))
            
            -- Map boyutları
            local newWidth = imgui.InputInt("Width##Map", self.activeMap.width)
            if newWidth ~= self.activeMap.width and newWidth > 0 then
                -- TODO: Harita boyutunu değiştir
                Console:log("Map width resizing not implemented yet")
            end
            
            local newHeight = imgui.InputInt("Height##Map", self.activeMap.height)
            if newHeight ~= self.activeMap.height and newHeight > 0 then
                -- TODO: Harita boyutunu değiştir
                Console:log("Map height resizing not implemented yet")
            end
            
            -- Grid boyutu
            local newGridSize = imgui.SliderInt("Grid Size##GridSize", self.gridSize, 16, 64)
            if newGridSize ~= self.gridSize then
                self.gridSize = newGridSize
                
                -- Tüm tilemap entity'lerinin grid boyutunu güncelle
                for _, entity in ipairs(self.entities) do
                    if entity.type == "tilemap" then
                        entity.gridSize = self.gridSize
                    end
                end
            end
            
            -- Grid gösterme seçeneği
            local showGridChanged = imgui.Checkbox("Show Grid", self.showGrid)
            if showGridChanged ~= self.showGrid then
                self.showGrid = showGridChanged
                
                -- Tüm tilemap entity'lerinin grid görünürlüğünü güncelle
                for _, entity in ipairs(self.entities) do
                    if entity.type == "tilemap" then
                        entity.showGrid = self.showGrid
                    end
                end
            end
            
            imgui.Separator()
            
            -- Harita katmanları
            imgui.Text("Layers:")
            
            for i, layer in ipairs(self.activeMap.layers) do
                if imgui.CollapsingHeader(layer.name .. "##Layer" .. i) then
                    -- Katman adı
                    local layerName = imgui.InputText("Name##Layer" .. i, layer.name, 100)
                    if layerName ~= layer.name then
                        layer.name = layerName
                    end
                    
                    -- Katman görünürlüğü
                    local visible = imgui.Checkbox("Visible##Layer" .. i, layer.visible)
                    if visible ~= layer.visible then
                        layer.visible = visible
                    end
                    
                    -- Katmanı temizle
                    if imgui.Button("Clear Layer##" .. i) then
                        for y = 1, self.activeMap.height do
                            for x = 1, self.activeMap.width do
                                layer.tiles[y][x] = nil
                            end
                        end
                        Console:log("Cleared layer: " .. layer.name)
                    end
                end
            end
            
            imgui.Separator()
            
            -- Yeni katman ekle
            if imgui.Button("Add Layer") then
                self:addLayer(self.activeMap, "New Layer")
                Console:log("Added new layer to map: " .. self.activeMap.name)
            end
        end
        
        imgui.EndChild()
        
        imgui.End()
    end
end

function Tilemap:drawMap(map, gridSize, showGrid)
    if not map then return end
    
    -- Varsayılan değerleri kullan eğer parametre verilmemişse
    gridSize = gridSize or self.gridSize
    if showGrid == nil then showGrid = self.showGrid end
    
    -- Her katmanı çiz
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
                                love.graphics.setColor(1, 1, 1, 1) -- Tam opaklık ile çiz
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
    
    -- Grid çizgileri
    if showGrid then
        love.graphics.setColor(0.5, 0.5, 0.5, 0.5)
        love.graphics.setLineWidth(1)
        
        -- Yatay çizgiler
        for y = 0, map.height do
            love.graphics.line(
                0, 
                y * gridSize, 
                map.width * gridSize, 
                y * gridSize
            )
        end
        
        -- Dikey çizgiler
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
    
    -- Koordinatları sayısal değerlere dönüştür
    local x = tonumber(entity.x) or 0
    local y = tonumber(entity.y) or 0
    local rotation = tonumber(entity.rotation) or 0
    local scaleX = tonumber(entity.scaleX) or 1
    local scaleY = tonumber(entity.scaleY) or 1
    
    love.graphics.translate(x, y)
    love.graphics.rotate(rotation)
    love.graphics.scale(scaleX, scaleY)
    
    -- Görünürlük kontrolü
    if entity.visible == false then 
        love.graphics.pop()
        return 
    end
    
    -- Haritayı çiz
    self:drawMap(map, entity.gridSize or self.gridSize, entity.showGrid)
    
    love.graphics.pop()
end

function Tilemap:drawInScene()
    -- Aktif haritayı çiz (editör görünümü)
    if self.activeMap then
        self:drawMap(self.activeMap, self.gridSize, self.showGrid)
    end
    
    -- Tüm tilemap entity'lerini çiz
    for _, entity in ipairs(SceneManager.entities or {}) do
        if entity.type == "tilemap" then
            self:drawEntity(entity)
        end
    end
    
    -- Fare pozisyonunda seçilen karoyu göster (yerleştirme önizlemesi)
    if self.selectedTile and self.activeTileset and not imgui.GetWantCaptureMouse() then
        local mouseX, mouseY = love.mouse.getPosition()
        local worldX, worldY = self:screenToWorld(mouseX, mouseY)
        
        -- Grid pozisyonunu hesapla
        local gridX = math.floor(worldX / self.gridSize)
        local gridY = math.floor(worldY / self.gridSize)
        
        -- Seçilen karoyu çiz
        local tileData = self:getTileFromTileset(self.activeTileset, self.selectedTile)
        if tileData then
            love.graphics.setColor(1, 1, 1, 0.7) -- Yarı saydam
            love.graphics.draw(
                self.activeTileset.image,
                tileData.quad,
                gridX * self.gridSize,
                gridY * self.gridSize,
                0,
                self.gridSize / self.activeTileset.tileSize,
                self.gridSize / self.activeTileset.tileSize
            )
            
            -- Grid vurgusu
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