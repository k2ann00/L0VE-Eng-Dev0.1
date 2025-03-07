--[[ local State = {
    world = nil,
    assets = {},
    consoleLog = {},
    selectedAsset = nil,
    draggedAsset = nil,
    dragStarted = false,
    scenes = {},
    currentScene = nil,
    animations = {},
    currentAnimation = nil,
    cameraSettings = {
        x = 0,
        y = 0,
        scaleX = 1,
        scaleY = 1,
        rotation = 0,
        target = nil
    },
    windowSizes = {
        assetManager = {width = 300, height = 300},
        console = {width = 300, height = 200},
        animator = {width = 400, height = 300},
        sceneView = {width = 800, height = 600},
        hierarchy = {width = 250, height = 400},
        inspector = {width = 300, height = 400},
        error = {width = 300, height = 200}
    },
    showWindows = {
        assetManager = true,
        console = true,
        animator = true,
        sceneEditor = true,
        properties = true,
        hierarchy = true,
        inspector = true
    }
}

return State
 ]]

 -- TODO: animasyon hızını düzenle
local world

local State = {
    world = nil,
    assets = {},
    consoleLog = {},
    selectedAsset = nil,
    draggedAsset = nil,
    dragStarted = false,
    scenes = {},
    currentScene = nil,
    animations = {},
    currentAnimation = nil,
    selectedEntity = nil,
    cameraSettings = {
        x = 0,
        y = 0,
        scaleX = 1,
        scaleY = 1,
        rotation = 0,
        target = nil
    },
    windowSizes = {
        assetManager = {width = 300, height = 300},
        console = {width = 300, height = 200},
        animator = {width = 400, height = 300},
        sceneView = {width = 800, height = 600},
        hierarchy = {width = 250, height = 400},
        inspector = {width = 300, height = 400},
        tilemap = {width = 700, height = 700},
        error = {width = 300, height = 200}
    },
    showWindows = {
        assetManager = true,
        console = true,
        animator = false,
        sceneEditor = true,
        properties = true,
        hierarchy = true,
        inspector = true,
        tilemap = false
    }
}

return State