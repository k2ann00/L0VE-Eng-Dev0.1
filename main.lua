--[[ -- TODO: animasyon hızını düzenle
local world

local function loadModules()
    -- Load state first as it's required by all modules
    local State = require "state"
    
    
    -- Load modules
    local AssetManager = require "modules.asset_manager"
    local Console = require "modules.console"
    local Camera = require "modules.camera"
    local Animator = require "modules.animator"
    local SceneManager = require "modules.scene_manager"
    local Hierarchy = require "modules.hierarchy"
    local Inspector = require "modules.inspector"
    
    
    -- Initialize modules
    AssetManager:init()
    Console:init()
    Camera:init()
    Animator:init()
    SceneManager:init()
    Hierarchy:init()
    Inspector:init()
    
    -- Log initialization
    Console:log("Engine initialized")
    State.world = love.physics.newWorld(0, 9.81*64, true) --create a world for the bodies to exist in with horizontal gravity of 0 and vertical gravity of 9.81
    world = State.world
    return {
        state = State,
        assetManager = AssetManager,
        console = Console,
        camera = Camera,
        animator = Animator,
        sceneManager = SceneManager,
        hierarchy = Hierarchy,
        inspector = Inspector
    }
end

function love.load()
    -- Initialize ImGui
    imgui = require "imgui"
    
    -- Load modules
    engine = loadModules()
    
    
    -- Engine title
    love.window.setTitle("LÖVE2D Game Engine Editor")
    love.window.maximize = true
    love.graphics.setDefaultFilter("nearest", "nearest")
end

function love.update(dt)
    imgui.NewFrame()

    world:update(dt)
    engine.camera:update(dt)
    engine.animator:update(dt)
    engine.sceneManager:update(dt)

    engine.console:update()
    
    -- Draw ImGui windows
    engine.assetManager:draw()
    engine.console:draw()
    engine.camera:draw()
    engine.hierarchy:draw()
    engine.inspector:draw()
    engine.sceneManager:drawSceneEditor()
    
    engine.sceneManager:handleInput()
end

function love.draw()
    -- Draw scene
    engine.camera:set()
    
    -- Draw grid and entities
    engine.sceneManager:drawGrid()
    engine.sceneManager:drawEntities()

    engine.animator:draw()
    
    engine.camera:unset()
    
    -- Render ImGui
    imgui.Render()
end

function love.keypressed(key, scancode, isrepeat)
    imgui.KeyPressed(key)
    
    -- Global shortcuts
    if key == "escape" then
        love.event.quit()
    end
end

function love.keyreleased(key, scancode)
    imgui.KeyReleased(key)
end

function love.mousemoved(x, y, dx, dy)
    imgui.MouseMoved(x, y)
    
    -- Camera pan with middle mouse button
    if love.mouse.isDown(3) then  -- Middle mouse button
        engine.camera:move(
            -dx / engine.camera.scaleX,  -- scaleX kullan
            -dy / engine.camera.scaleY   -- scaleY kullan
        )
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    
    -- Zoom camera with mouse wheel
    if not imgui.GetWantCaptureMouse() then
        if y > 0 then
            engine.camera:zoom(1.1)
        elseif y < 0 then
            engine.camera:zoom(0.9)
        end
    end
end

function love.textinput(text)
    imgui.TextInput(text)
end



function love.quick()
	imgui.ShutdownDock()
end
 ]]

 -- TODO: animasyon hızını düzenle
local world

local function loadModules()
    -- Load state first as it's required by all modules
    local State = require "state"
    
    
    -- Load modules
    local AssetManager = require "modules.asset_manager"
    local Console = require "modules.console"
    local Camera = require "modules.camera"
    local Animator = require "modules.animator"
    local SceneManager = require "modules.scene_manager"
    local Hierarchy = require "modules.hierarchy"
    local Inspector = require "modules.inspector"
    local Tilemap = require "modules.tilemap"  -- Tilemap modülünü ekledik
    
    
    -- Initialize modules
    AssetManager:init()
    Console:init()
    Camera:init()
    Animator:init()
    SceneManager:init()
    Hierarchy:init()
    Inspector:init()
    Tilemap:init()  -- Tilemap modülünü başlat
    
    -- Log initialization
    Console:log("Engine initialized")
    State.world = love.physics.newWorld(0, 9.81*64, true) --create a world for the bodies to exist in with horizontal gravity of 0 and vertical gravity of 9.81
    world = State.world
    return {
        state = State,
        assetManager = AssetManager,
        console = Console,
        camera = Camera,
        animator = Animator,
        sceneManager = SceneManager,
        hierarchy = Hierarchy,
        inspector = Inspector,
        tilemap = Tilemap  -- Tilemap modülünü engine'e ekledik
    }
end

function love.load()
    -- Initialize ImGui
    imgui = require "imgui"
    
    -- Load modules
    engine = loadModules()
    
    
    -- Engine title
    love.window.setTitle("LÖVE2D Game Engine Editor")
    love.window.maximize = true
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Örnek bir tileset yükle ve harita oluştur (test için)
    if love.filesystem.getInfo("assets/tilesets/example.png") then
        engine.tilemap:loadTileset("assets/tilesets/example.png", "Example Tileset", 32)
        engine.tilemap:createMap(20, 15, "New Map")
        engine.console:log("Example tileset and map loaded")
    end
end

function love.update(dt)
    imgui.NewFrame()

    world:update(dt)
    engine.camera:update(dt)
    engine.animator:update(dt)
    engine.sceneManager:update(dt)
    engine.tilemap:update(dt)  -- Tilemap güncellemesini ekledik

    engine.console:update()
    
    -- Draw ImGui windows
    engine.assetManager:draw()
    engine.console:draw()
    engine.camera:draw()
    engine.hierarchy:draw()
    engine.inspector:draw()
    engine.sceneManager:drawSceneEditor()
    engine.tilemap:draw()  -- Tilemap penceresini ekledik
    
    engine.sceneManager:handleInput()
end

function love.draw()
    -- Draw scene
    engine.camera:set()
    
    -- Draw grid and entities
    engine.sceneManager:drawGrid()
    engine.sceneManager:drawEntities()
    
    -- Tilemap'i çiz
    engine.tilemap:drawInScene()
    
    engine.animator:draw()
    
    engine.camera:unset()
    
    -- Render ImGui
    imgui.Render()
end

function love.keypressed(key, scancode, isrepeat)
    imgui.KeyPressed(key)


    -- Global shortcuts
    if key == "escape" then
        love.event.quit()
    end
end

function love.keyreleased(key, scancode)
    imgui.KeyReleased(key)
end

function love.mousemoved(x, y, dx, dy)
    imgui.MouseMoved(x, y)
    
    -- Camera pan with middle mouse button
    if love.mouse.isDown(3) then  -- Middle mouse button
        engine.camera:move(
            -dx / engine.camera.scaleX,  -- scaleX kullan
            -dy / engine.camera.scaleY   -- scaleY kullan
        )
    end
end

function love.mousepressed(x, y, button)
    imgui.MousePressed(button)
end

function love.mousereleased(x, y, button)
    imgui.MouseReleased(button)
end

function love.wheelmoved(x, y)
    imgui.WheelMoved(y)
    
    -- Zoom camera with mouse wheel
    if not imgui.GetWantCaptureMouse() then
        if y > 0 then
            engine.camera:zoom(1.1)
        elseif y < 0 then
            engine.camera:zoom(0.9)
        end
    end
end

function love.textinput(text)
    imgui.TextInput(text)
end



function love.quick()
	imgui.ShutdownDock()
end