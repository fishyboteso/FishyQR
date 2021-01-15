FishyQR = {
    name = "FishyQR",
    author = "Semjon Kerner",
    run_var = false
}

local gps = LibStub("LibGPS2")

--PARAMS:
local FishyQRparams = {}
local FishyQRdefaults = {
    pixelsize = 3,
    maxpixels = 25,
    updatetime = 400
}

-- QR -------------------------------
--make qr blank
local function _blankQR()
    for row=0,FishyQRparams.maxpixels-1 do
        for col=0,FishyQRparams.maxpixels-1 do
            FishyQR.UI.pixel[row][col]:SetHidden(true)
        end
    end
end

--draw qr
local function _drawQR(keyString)
    local ok, qrtable = qrcode(keyString)
    local tmpLastPixel = 0
    if ok then
        --set pixels
        for i,ref in pairs(qrtable) do
            tmpLastPixel = i
            for j,val in pairs(ref) do
                --Error: not enough pixels allocated
                if j > FishyQRparams.maxpixels then
                    return
                end

                if val < 0 then
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                else
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(false)
                end
            end
        end
        
        --make unused pixels blank
        if tmpLastPixel < FishyQRparams.maxpixels then
            for i = 1, tmpLastPixel do
                for j = tmpLastPixel+1, FishyQRparams.maxpixels do
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
            for i = tmpLastPixel+1, FishyQRparams.maxpixels do
                for j = 1, FishyQRparams.maxpixels do
                    FishyQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
        end
        
        --resize background
        FishyQR.UI.background:SetDimensions(4 + tmpLastPixel*FishyQRparams.pixelsize + 4, 4 + tmpLastPixel*FishyQRparams.pixelsize + 4)
    end
end

local tmpKeyString = ""
local function _generateQR(keyString)
    EVENT_MANAGER:UnregisterForUpdate(FishyQR.name .. "generateQR")
    FishyCha.CallbackManager:UnregisterCallback(FishyQR.name .. "ChaStateChange", callback)
    local updatetime_ms = FishyQRparams.updatetime
    
    --get the gps values and form them to a string
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
    local keyString = string.format("%f,%f,%d,%d", x, y, angle, FishyCha.currentState) -- add all data here
    --local keyString = string.format("%f,%f,%d", x, y, angle) -- add all data here

    --draw QRC with new location
    if tmpKeyString ~= keyString then
        tmpKeyString = keyString
        --_blankQR()
        _drawQR(tmpKeyString)
        
    --dont draw QRC when location didn't change, wait twice
    else
        updatetime_ms = updatetime_ms * 2
    end
    
    --wait a moment before running again
    if FishyQR.run_var then
        EVENT_MANAGER:RegisterForUpdate(FishyQR.name .. "generateQR", updatetime_ms, _generateQR)
        FishyCha.CallbackManager:RegisterCallback(FishyQR.name .. "ChaStateChange", callback)
    else
        _blankQR()
    end
end

-- STATES ----------------------------
local function _stopState()
    FishyQR.run_var = false
    EVENT_MANAGER:UnregisterForUpdate(FishyQR.name .. "startStateUpdate")
    EVENT_MANAGER:UnregisterForUpdate(FishyQR.name .. "generateQR")
    _drawQR("stop")
    FishyQR.UI.button:SetNormalTexture(FishyQR.name .. "/img/start_mouseup.dds")
    FishyQR.UI.button:SetMouseOverTexture(FishyQR.name .. "/img/start_mouseover.dds")
end

local function _startStateUpdate()
    EVENT_MANAGER:UnregisterForUpdate(FishyQR.name .. "startStateUpdate")
    tmpKeyString = ""
    FishyQR.UI.button:SetNormalTexture(FishyQR.name .. "/img/start_running.dds")
    FishyQR.UI.button:SetMouseOverTexture(FishyQR.name .. "/img/start_running.dds")
    _generateQR()
end

local function _startState()
    _drawQR("start")
    FishyQR.run_var = true
    EVENT_MANAGER:RegisterForUpdate(FishyQR.name .. "startStateUpdate", 2000, _startStateUpdate)
end

local function _toggle_running_state()
    --if state was running: stop and hide
    if FishyQR.run_var then
        _stopState()

    --if state was stopped: run and show
    else
        _startState()
    end
end

-- INIT -----------------------------
function FishyQR.OnAddOnLoaded(event, addonName)
    if addonName == FishyQR.name then
        --init once and never come here again
        EVENT_MANAGER:UnregisterForEvent(FishyQR.name, EVENT_ADD_ON_LOADED)
        
        --load params variable
        FishyQRparams = ZO_SavedVars:NewAccountWide("FishyQRparamsvar", 1, nil, FishyQRdefaults)
        
        --init chalutier
        fishyChaInit()

        --create qr ui code elements
        FishyQR.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
        FishyQR.UI:SetMouseEnabled(true)
        FishyQR.UI:SetClampedToScreen(true)
        FishyQR.UI:SetMovable(true)
        FishyQR.UI:SetDimensions(64, 92)
        FishyQR.UI:SetDrawLevel(0)
        FishyQR.UI:SetDrawLayer(DL_MAX_VALUE)
        FishyQR.UI:SetDrawTier(DT_MAX_VALUE)
        
        FishyQR.UI.background = WINDOW_MANAGER:CreateControl(nil, FishyQR.UI, CT_TEXTURE)
        FishyQR.UI.background:SetDimensions(4 + FishyQRparams.maxpixels*FishyQRparams.pixelsize + 4, 4 + FishyQRparams.maxpixels*FishyQRparams.pixelsize + 4)
        FishyQR.UI.background:SetColor(1, 1, 1)
        FishyQR.UI.background:SetAnchor(TOPLEFT, FishyQR.UI, TOPLEFT, 0, 0)
        FishyQR.UI.background:SetHidden(false)
        FishyQR.UI.background:SetDrawLevel(0)
        
        FishyQR.UI.pixel = {}
        for i = 0,FishyQRparams.maxpixels-1 do
            FishyQR.UI.pixel[i] = {}
            for j = 0,FishyQRparams.maxpixels-1 do
                FishyQR.UI.pixel[i][j] = WINDOW_MANAGER:CreateControl(nil, FishyQR.UI, CT_TEXTURE)
                FishyQR.UI.pixel[i][j]:SetDimensions(FishyQRparams.pixelsize, FishyQRparams.pixelsize)
                FishyQR.UI.pixel[i][j]:SetColor(0, 0, 0)
                FishyQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, FishyQR.UI.background, TOPLEFT, 4+(i*FishyQRparams.pixelsize), 4+(j*FishyQRparams.pixelsize))
                FishyQR.UI.pixel[i][j]:SetHidden(true)
                FishyQR.UI.pixel[i][j]:SetDrawLevel(0)
            end
        end
        
        _drawQR("stop")
        
        --add start button
        FishyQR.UI.button =  WINDOW_MANAGER:CreateControl(FishyQR.name .. "button", ZO_ChatWindow, CT_BUTTON)
        FishyQR.UI.button:SetDimensions(20, 20)
        FishyQR.UI.button:SetAnchor(TOPLEFT, ZO_ChatWindowNotifications, TOPRIGHT, 75, 5)
        FishyQR.UI.button:SetNormalTexture(FishyQR.name .. "/img/start_mouseup.dds")
        FishyQR.UI.button:SetPressedTexture(FishyQR.name .. "/img/start_mousedown.dds")
        FishyQR.UI.button:SetMouseOverTexture(FishyQR.name .. "/img/start_mouseover.dds")
        FishyQR.run_var = false
        FishyQR.UI.button:SetHandler("OnClicked", _toggle_running_state)

        --addon menu
        local LAM = LibAddonMenu2
        local panelName = FishyQR.name .. "Settings"
         
        local panelData = {
            type = "panel",
            name = FishyQR.name .. " Settings",
            author = FishyQR.author,
        }
        local panel = LAM:RegisterAddonPanel(panelName, panelData)
        local optionsData = {
            {
                type = "slider",
                name = "Maximum Pixels",
                min = 25,
                max = 75,
                default = 25,
                getFunc = function() return FishyQRparams.maxpixels end,
                setFunc = function(value) FishyQRparams.maxpixels = value end,
                tooltip = "Set the maximum of pixels for QR Code that get initialized.",
                requiresReload = true
            },
            {
                type = "slider",
                name = "Pixel Size",
                min = 1,
                max = 8,
                default = 2,
                getFunc = function() return FishyQRparams.pixelsize end,
                setFunc = function(value)
                    FishyQRparams.pixelsize = value
                    FishyQR.UI.background:SetDimensions(4 + FishyQRparams.maxpixels*FishyQRparams.pixelsize + 4, 4 + FishyQRparams.maxpixels*FishyQRparams.pixelsize + 4)
                    for i = 0,FishyQRparams.maxpixels-1 do
                        for j = 0,FishyQRparams.maxpixels-1 do
                            FishyQR.UI.pixel[i][j]:SetDimensions(FishyQRparams.pixelsize, FishyQRparams.pixelsize)
                            FishyQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, FishyQR.UI.background, TOPLEFT, 4+(i*FishyQRparams.pixelsize), 4+(j*FishyQRparams.pixelsize))
                        end
                    end
                end,
                tooltip = "Set the size of each pixel of the QR Code."
            },
            {
                type = "slider",
                name = "Updatetime",
                min = 100,
                max = 1500,
                step = 50,
                default = 400,
                getFunc = function() return FishyQRparams.updatetime end,
                setFunc = function(value) FishyQRparams.updatetime = value end,
                tooltip = "Set the wait time between each QR Code Update in ms."
            }
        }
        LAM:RegisterOptionControls(panelName, optionsData)
        
    end
end
 
EVENT_MANAGER:RegisterForEvent(FishyQR.name, EVENT_ADD_ON_LOADED, FishyQR.OnAddOnLoaded)