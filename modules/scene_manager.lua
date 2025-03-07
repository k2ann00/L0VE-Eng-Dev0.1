local State = require "state"
local Console = require "modules.console"
local Camera = require "modules.camera"
local imgui = require "imgui"

local SceneManager = {}

function SceneManager:init()
    self.scenes = {}
    self.entities = {}
    self.selectedEntity = nil
    self.gridSize = 32
    self.showGrid = true
    self.lastMouseX = 0
    self.lastMouseY = 0
    self.handleSize = 4
    
    -- Create a default scene
    self:createNewScene("Default Scene")
end

function SceneManager:createNewScene(name)
    local scene = {
        name = name,
        entities = {},
        background = {r = 0.1, g = 0.1, b = 0.1}
    }
    
    table.insert(self.scenes, scene)
    State.currentScene = scene
    Console:log("Created new scene: " .. name)
    return scene
end

function SceneManager:createEntity(x, y)
    local entity = {
        name = "Entity " .. (#self.entities + 1),
        x = x or 0,
        y = y or 0,
        width = 32,
        height = 32,
        rotation = 0,
        sprite = nil,
        animation = nil,
        isPlayer = false,
        playerSpeed = 0,
        components = {}
    }
    
    table.insert(self.entities, entity)
    State.selectedEntity = entity
    Console:log("Created entity: " .. entity.name)
    return entity
end

function SceneManager:deleteEntity(entity)
    for i, e in ipairs(self.entities) do
        if e == entity then
            table.remove(self.entities, i)
            if State.selectedEntity == entity then
                State.selectedEntity = nil
            end
            Console:log("Deleted entity: " .. entity.name)
            print("Deleted entity: " .. entity.name)
            return true
        end
    end
    return false
end

function SceneManager:drawGrid()
    if not self.showGrid then return end
    
    love.graphics.setColor(0.3, 0.3, 0.3, 0.5)
    
    local w, h = love.graphics.getDimensions()
    local startX = math.floor(-Camera.x / self.gridSize) * self.gridSize
    local startY = math.floor(-Camera.y / self.gridSize) * self.gridSize
    local endX = startX + w / Camera.scaleX + self.gridSize * 2
    local endY = startY + h / Camera.scaleY + self.gridSize * 2
    
    for x = startX, endX, self.gridSize do
        love.graphics.line(x, startY, x, endY)
    end
    
    for y = startY, endY, self.gridSize do
        love.graphics.line(startX, y, endX, y)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function SceneManager:drawEntities()
    for _, entity in ipairs(self.entities) do
        -- Sadece tilemap componentine sahip entity'ler için placeholder çizme
        local hasTilemap = entity.type == "tilemap" or (entity.components and entity.components.tilemap)
        
        -- Sprite veya Animator component'i varsa
        if entity.components then
            if entity.components.animator and entity.components.animator.currentAnimation then
                -- Animasyon çiz (playing olsun veya olmasın)
                local animator = entity.components.animator
                local anim = animator.currentAnimation
                
                if anim and anim.frames and #anim.frames > 0 then
                    local frame = anim.frames[animator.currentFrame]
                    if frame and frame.quad then
                        love.graphics.setColor(1, 1, 1, 1)
                        anim.source.data:setFilter("nearest", "nearest")
                        love.graphics.draw(
                            anim.source.data,
                            frame.quad,
                            entity.x + entity.width/2,
                            entity.y + entity.height/2,
                            entity.rotation or 0,
                            entity.width / anim.frameWidth,
                            entity.height / anim.frameHeight,
                            anim.frameWidth/2,
                            anim.frameHeight/2
                        )
                    end
                end
            elseif entity.components.sprite and entity.components.sprite.image then
                -- Normal sprite çiz
                local sprite = entity.components.sprite
                local color = sprite.color or {1, 1, 1, 1}
                
                love.graphics.setColor(color[1], color[2], color[3], color[4])
                
                local img = sprite.image.data
                local w, h = img:getDimensions()
                img:setFilter("nearest", "nearest")
                
                -- Hesapla scale ve flip değerleri
                local scaleX = entity.width / w
                local scaleY = entity.height / h
                
                -- Flip kontrolü
                if sprite.flip_h then scaleX = -scaleX end
                if sprite.flip_v then scaleY = -scaleY end
                
                love.graphics.draw(
                    img,
                    entity.x + entity.width/2,
                    entity.y + entity.height/2,
                    entity.rotation or 0,
                    scaleX,
                    scaleY,
                    w/2, h/2
                )
            else
                -- Placeholder çiz (SADECE tilemap component'i YOKSA)
                if not hasTilemap then
                    love.graphics.setColor(0.5, 0.5, 0.5, 1)
                    love.graphics.rectangle("fill", entity.x, entity.y, entity.width, entity.height)
                    love.graphics.setColor(0.8, 0.8, 0.8, 1)
                    love.graphics.rectangle("line", entity.x, entity.y, entity.width, entity.height)
                    love.graphics.setColor(1, 1, 1, 1)
                    love.graphics.print(entity.name or "Entity", entity.x + 2, entity.y + 2)
                end
            end
            
            -- Seçili entity'nin etrafına çizgi çiz
            if entity == State.selectedEntity then
                self:drawSelectionOutline(entity)

                if love.keyboard.isDown("delete") then
                    self:deleteEntity(State.selectedEntity)
                end
            end
        end
    end
    love.graphics.setColor(1, 1, 1, 1)  -- Rengi resetle
end

-- Seçili entity'nin etrafına çizgi çizme fonksiyonu
function SceneManager:drawSelectionOutline(entity)
    -- Seçim çizgisinin rengi ve kalınlığı
    love.graphics.setColor(0, 1, 1, 1)  -- Turkuaz renk
    love.graphics.setLineWidth(2)
    
    -- Entity'nin dönüşünü hesaba katarak çizgi çiz
    if entity.rotation and entity.rotation ~= 0 then
        -- Dönüşlü çizim için merkez noktayı hesapla
        local centerX = entity.x + entity.width/2
        local centerY = entity.y + entity.height/2
        
        -- Dönüşü uygula
        love.graphics.push()
        love.graphics.translate(centerX, centerY)
        love.graphics.rotate(entity.rotation)
        
        -- Dikdörtgen çiz (merkez etrafında)
            love.graphics.rectangle("line", -entity.width/2, -entity.height/2, entity.width, entity.height)

        -- Köşe tutamaçları çiz
        local handleSize = 1
        -- Sol üst
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ üst
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sol alt
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ alt
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        
        -- Orta tutamaçlar
        -- Üst
        love.graphics.rectangle("fill", -handleSize/2, -entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Alt
        love.graphics.rectangle("fill", -handleSize/2, entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sol
        love.graphics.rectangle("fill", -entity.width/2 - handleSize/2, -handleSize/2, handleSize, handleSize)
        -- Sağ
        love.graphics.rectangle("fill", entity.width/2 - handleSize/2, -handleSize/2, handleSize, handleSize)
        
        love.graphics.pop()
    else
        -- Dönüşsüz normal çizim
        love.graphics.rectangle("line", entity.x, entity.y, entity.width, entity.height)
        
        -- Köşe tutamaçları çiz
        local handleSize = 8
        -- Sol üst
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Sağ üst
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Sol alt
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        -- Sağ alt
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        
        -- Orta tutamaçlar
        -- Üst
        love.graphics.rectangle("fill", entity.x + entity.width/2 - handleSize/2, entity.y - handleSize/2, handleSize, handleSize)
        -- Alt
        love.graphics.rectangle("fill", entity.x + entity.width/2 - handleSize/2, entity.y + entity.height - handleSize/2, handleSize, handleSize)
        -- Sol
        love.graphics.rectangle("fill", entity.x - handleSize/2, entity.y + entity.height/2 - handleSize/2, handleSize, handleSize)
        -- Sağ
        love.graphics.rectangle("fill", entity.x + entity.width - handleSize/2, entity.y + entity.height/2 - handleSize/2, handleSize, handleSize)
    end
    
    -- Çizgi kalınlığını resetle
    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
end

function SceneManager:handleInput()
    local mouseX, mouseY = love.mouse.getPosition()
    local worldX, worldY = self:screenToWorld(mouseX, mouseY)
    
    -- Eğer bir asset sürükleniyorsa ve ImGui mouse'u kapsamıyorsa
    if not imgui.GetWantCaptureMouse() and State.draggedAsset and State.dragStarted then
        -- Mouse bırakıldığında yeni entity oluştur
        if not love.mouse.isDown(1) then
            -- Sadece sahne üzerinde fare bırakılırsa entity oluştur
            if worldX >= 0 and worldX <= love.graphics.getWidth() and 
               worldY >= 0 and worldY <= love.graphics.getHeight() then
                self:handleDraggedAsset(State.draggedAsset, worldX, worldY)
            end
            
            -- Sürükleme durumunu sıfırla
            State.draggedAsset = nil
            State.dragStarted = false
        end
    end
    
    -- Mouse tıklaması
    if love.mouse.isDown(1) and not imgui.GetWantCaptureMouse() then
        -- Mouse delta hesapla
        local dx = (mouseX - self.lastMouseX) / Camera.scaleX
        local dy = (mouseY - self.lastMouseY) / Camera.scaleY
        
        -- Eğer bir tutamaç sürüklüyorsak
        if self.isDragging and self.draggedHandle and State.selectedEntity then
            local entity = State.selectedEntity
            
            -- Tutamaç tipine göre transform değiştir
            if self.draggedHandle == "topLeft" then
                entity.x = entity.x + dx
                entity.y = entity.y + dy
                entity.width = entity.width - dx
                entity.height = entity.height - dy
            elseif self.draggedHandle == "topRight" then
                entity.y = entity.y + dy
                entity.width = entity.width + dx
                entity.height = entity.height - dy
            elseif self.draggedHandle == "bottomLeft" then
                entity.x = entity.x + dx
                entity.width = entity.width - dx
                entity.height = entity.height + dy
            elseif self.draggedHandle == "bottomRight" then
                entity.width = entity.width + dx
                entity.height = entity.height + dy
            elseif self.draggedHandle == "top" then
                entity.y = entity.y + dy
                entity.height = entity.height - dy
            elseif self.draggedHandle == "bottom" then
                entity.height = entity.height + dy
            elseif self.draggedHandle == "left" then
                entity.x = entity.x + dx
                entity.width = entity.width - dx
            elseif self.draggedHandle == "right" then
                entity.width = entity.width + dx
            elseif self.draggedHandle == "move" then
                entity.x = entity.x + dx
                entity.y = entity.y + dy
            end
            
            -- Minimum boyut kontrolü
            if entity.width < 10 then entity.width = 10 end
            if entity.height < 10 then entity.height = 10 end
        elseif not self.isDragging then
            -- Tutamaç kontrolü
            if State.selectedEntity then
                local handle = self:checkHandles(worldX, worldY, State.selectedEntity)
                if handle then
                    self.isDragging = true
                    self.draggedHandle = handle
                else
                    -- Entity içine tıklama kontrolü
                    local clickedEntity = self:getEntityAtPosition(worldX, worldY)
                    if clickedEntity then
                        State.selectedEntity = clickedEntity
                        self.isDragging = true
                        self.draggedHandle = "move"
                    else
                        -- Boş alana tıklama
                        if love.keyboard.isDown("lctrl") then
                            self:createEntity(worldX, worldY)
                        else
                            State.selectedEntity = nil
                        end
                    end
                end
            else
                -- Entity seçimi
                local clickedEntity = self:getEntityAtPosition(worldX, worldY)
                if clickedEntity then
                    State.selectedEntity = clickedEntity
                    self.isDragging = true
                    self.draggedHandle = "move"
                else
                    -- Yeni entity oluştur
                    if love.keyboard.isDown("lctrl") then
                        self:createEntity(worldX, worldY)
                    end
                end
            end
        end
    else
        -- Mouse bırakıldığında
        self.isDragging = false
        self.draggedHandle = nil
    end
    
    -- Son mouse pozisyonunu güncelle
    self.lastMouseX = mouseX
    self.lastMouseY = mouseY
end

function SceneManager:getEntityAtPosition(x, y)
    for i = #self.entities, 1, -1 do  -- Üstteki entity'leri önce kontrol et
        local entity = self.entities[i]
        if x >= entity.x and x <= entity.x + entity.width and
           y >= entity.y and y <= entity.y + entity.height then
            return entity
        end
    end
    return nil
end

function SceneManager:checkHandles(x, y, entity)
    local handleSize = self.handleSize / Camera.scaleX  -- Kamera ölçeğine göre ayarla
    
    -- Köşe tutamaçları
    -- Sol üst
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "topLeft"
    end
    
    -- Sağ üst
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "topRight"
    end
    
    -- Sol alt
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottomLeft"
    end
    
    -- Sağ alt
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottomRight"
    end
    
    -- Kenar tutamaçları
    -- Üst
    if x >= entity.x + entity.width/2 - handleSize/2 and x <= entity.x + entity.width/2 + handleSize/2 and
       y >= entity.y - handleSize/2 and y <= entity.y + handleSize/2 then
        return "top"
    end
    
    -- Alt
    if x >= entity.x + entity.width/2 - handleSize/2 and x <= entity.x + entity.width/2 + handleSize/2 and
       y >= entity.y + entity.height - handleSize/2 and y <= entity.y + entity.height + handleSize/2 then
        return "bottom"
    end
    
    -- Sol
    if x >= entity.x - handleSize/2 and x <= entity.x + handleSize/2 and
       y >= entity.y + entity.height/2 - handleSize/2 and y <= entity.y + entity.height/2 + handleSize/2 then
        return "left"
    end
    
    -- Sağ
    if x >= entity.x + entity.width - handleSize/2 and x <= entity.x + entity.width + handleSize/2 and
       y >= entity.y + entity.height/2 - handleSize/2 and y <= entity.y + entity.height/2 + handleSize/2 then
        return "right"
    end
    
    return nil
end

function SceneManager:screenToWorld(x, y)
    -- Convert screen coordinates to world coordinates
    local scaleX = Camera.scaleX
    local scaleY = Camera.scaleY
    local offsetX = Camera.x
    local offsetY = Camera.y
    local worldX = (x - love.graphics.getWidth() / 2) / scaleX + offsetX
    local worldY = (y - love.graphics.getHeight() / 2) / scaleY + offsetY
    return worldX, worldY
end

function SceneManager:selectEntityAt(mouseX, mouseY)
    -- Select entity based on mouse click position
    local worldX, worldY = self:screenToWorld(mouseX, mouseY)
    
    -- Check for entity collision with mouse click
    for _, entity in ipairs(self.entities) do
        if worldX >= entity.x and worldX <= entity.x + entity.width and
           worldY >= entity.y and worldY <= entity.y + entity.height then
            State.selectedEntity = entity
            Console:log("Selected entity: " .. entity.name)
            return
        end
    end
end

function SceneManager:drawSceneEditor()
    -- Draw grid and entities in the scene editor window
    self:drawGrid()
    self:drawEntities()
end

function SceneManager:update(dt)
    -- Entity'lerin animasyonlarını güncelle
    for _, entity in ipairs(self.entities) do
        if entity.components and entity.components.animator then
            local animator = entity.components.animator
            if animator.playing and animator.currentAnimation then
                --animator.timer = animator.timer + dt
                
                local currentFrame = animator.currentAnimation.frames[animator.currentFrame]
                if currentFrame and animator.timer >= currentFrame.duration then
                    animator.timer = animator.timer - currentFrame.duration
                    animator.currentFrame = animator.currentFrame + 1
                    
                    -- Animasyon bittiğinde başa dön
                    if animator.currentFrame > #animator.currentAnimation.frames then
                        animator.currentFrame = 1
                    end
                end
            end
        end
    end
end

function SceneManager:handleDraggedAsset(asset, worldX, worldY)
    -- Eğer sürüklenen asset bir görsel ise
    if asset and asset.type == "image" then
        -- Yeni bir entity oluştur
        local newEntity = self:createEntity(worldX, worldY)
        
        -- Entity'e sprite component ekle
        newEntity.components.sprite = {
            image = asset,
            color = {1, 1, 1, 1}
        }
        
        -- Entitynin boyutunu resmin orijinal boyutuna ayarla
        local img = asset.data
        local w, h = img:getDimensions()
        newEntity.width = w
        newEntity.height = h
        
        Console:log("Created entity with dragged image: " .. asset.name)
    end
end


return SceneManager
