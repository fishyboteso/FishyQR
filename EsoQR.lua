EsoQR = {
    name = "EsoQR",
    run_var = false,
}

local gps = LibStub("LibGPS2")

--PARAMS:
local EsoQRparams = {}
local EsoQRdefaults = {
    pixelsize = 3,
    maxpixels = 25,
    updatetime = 400
}

--[[
[X] 0.  add button
[X] 1.  register event on button click (set_run_var_true())
[X] 1.1     unregister event on button click (set_run_var_true())
[X] 1.2     register event on button click (set_run_var_false())
[X] 1.3     set running_var=true
[X] 1.4     call qrcode-generation-function
[X] 2   generate qrcode in a loop
[ ] 2.1     get Chalutier state, Keybindings, GPS
[X] 2.2     end qrcode-generation-function when running_var=false

TODO:
[X] add start/stop command to QR
[X] always in front
[X] make key-string CSV
[X] ingame addon menu to change params
[X] resize QR Background with table length
[X] blank only pixels in _drawQR(keyString) that are not touched
[X] easy resize QRCode
]]--

-- QR -------------------------------
--make qr blank
local function _blankQR()
    for row=0,EsoQRparams.maxpixels-1 do
        for col=0,EsoQRparams.maxpixels-1 do
            EsoQR.UI.pixel[row][col]:SetHidden(true)
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
                if j > EsoQRparams.maxpixels then
                    return
                end

                if val < 0 then
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(true)
                else
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(false)
                end
            end
        end
        
        --make unused pixels blank
        if tmpLastPixel < EsoQRparams.maxpixels then
            for i = 1, tmpLastPixel do
                for j = tmpLastPixel+1, EsoQRparams.maxpixels do
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
            for i = tmpLastPixel+1, EsoQRparams.maxpixels do
                for j = 1, EsoQRparams.maxpixels do
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(true)
                end
            end
        end
        
        --resize background
        EsoQR.UI.background:SetDimensions(4 + tmpLastPixel*EsoQRparams.pixelsize + 4, 4 + tmpLastPixel*EsoQRparams.pixelsize + 4)
    end
end

local tmpKeyString = ""
local function _generateQR(keyString)
    EVENT_MANAGER:UnregisterForUpdate(EsoQR.name .. "generateQR")
    local updatetime_ms = EsoQRparams.updatetime
    
    --get the gps values and form them to a string
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
    local keyString = string.format("%f,%f,%d,%d", x, y, angle, ProvCha.currentState) -- add all data here

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
    if EsoQR.run_var then
        EVENT_MANAGER:RegisterForUpdate(EsoQR.name .. "generateQR", updatetime_ms, _generateQR)
    else
        _blankQR()
    end
end

-- STATES ----------------------------
local function _stopState()
    EsoQR.run_var = false
    EVENT_MANAGER:UnregisterForUpdate(EsoQR.name .. "startStateUpdate")
    EVENT_MANAGER:UnregisterForUpdate(EsoQR.name .. "generateQR")
    _drawQR("stop")
    EsoQR.UI.button:SetNormalTexture(EsoQR.name .. "/img/start_mouseup.dds")
    EsoQR.UI.button:SetMouseOverTexture(EsoQR.name .. "/img/start_mouseover.dds")
end

local function _startStateUpdate()
    EVENT_MANAGER:UnregisterForUpdate(EsoQR.name .. "startStateUpdate")
    tmpKeyString = ""
    EsoQR.UI.button:SetNormalTexture(EsoQR.name .. "/img/start_running.dds")
    EsoQR.UI.button:SetMouseOverTexture(EsoQR.name .. "/img/start_running.dds")
    _generateQR()
end

local function _startState()
    _drawQR("start")
    EsoQR.run_var = true
    EVENT_MANAGER:RegisterForUpdate(EsoQR.name .. "startStateUpdate", 2000, _startStateUpdate)
end

local function _toggle_running_state()
    --if state was running: stop and hide
    if EsoQR.run_var then
        _stopState()

    --if state was stopped: run and show
    else
        _startState()
    end
end

-- INIT -----------------------------
function EsoQR.OnAddOnLoaded(event, addonName)
    if addonName == EsoQR.name then
        --init once and never come here again
        EVENT_MANAGER:UnregisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED)
        
        --load params variable
        EsoQRparams = ZO_SavedVars:NewAccountWide("EsoQRparamsvar", 1, nil, EsoQRdefaults)
        
        --create qr ui code elements
        EsoQR.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
        EsoQR.UI:SetMouseEnabled(true)
        EsoQR.UI:SetClampedToScreen(true)
        EsoQR.UI:SetMovable(true)
        EsoQR.UI:SetDimensions(64, 92)
        EsoQR.UI:SetDrawLevel(0)
        EsoQR.UI:SetDrawLayer(DL_MAX_VALUE)
        EsoQR.UI:SetDrawTier(DT_MAX_VALUE)
        
        EsoQR.UI.background = WINDOW_MANAGER:CreateControl(nil, EsoQR.UI, CT_TEXTURE)
        EsoQR.UI.background:SetDimensions(4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4, 4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4)
        EsoQR.UI.background:SetColor(1, 1, 1)
        EsoQR.UI.background:SetAnchor(TOPLEFT, EsoQR.UI, TOPLEFT, 0, 0)
        EsoQR.UI.background:SetHidden(false)
        EsoQR.UI.background:SetDrawLevel(0)
        
        EsoQR.UI.pixel = {}
        for i = 0,EsoQRparams.maxpixels-1 do
            EsoQR.UI.pixel[i] = {}
            for j = 0,EsoQRparams.maxpixels-1 do
                EsoQR.UI.pixel[i][j] = WINDOW_MANAGER:CreateControl(nil, EsoQR.UI, CT_TEXTURE)
                EsoQR.UI.pixel[i][j]:SetDimensions(EsoQRparams.pixelsize, EsoQRparams.pixelsize)
                EsoQR.UI.pixel[i][j]:SetColor(0, 0, 0)
                EsoQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, EsoQR.UI.background, TOPLEFT, 4+(i*EsoQRparams.pixelsize), 4+(j*EsoQRparams.pixelsize))
                EsoQR.UI.pixel[i][j]:SetHidden(true)
                EsoQR.UI.pixel[i][j]:SetDrawLevel(0)
            end
        end
        
        _drawQR("stop")
        
        --add start button
        EsoQR.UI.button =  WINDOW_MANAGER:CreateControl(EsoQR.name .. "button", ZO_ChatWindow, CT_BUTTON)
        EsoQR.UI.button:SetDimensions(20, 20)
        EsoQR.UI.button:SetAnchor(TOPLEFT, ZO_ChatWindowNotifications, TOPRIGHT, 75, 5)
        EsoQR.UI.button:SetNormalTexture(EsoQR.name .. "/img/start_mouseup.dds")
        EsoQR.UI.button:SetPressedTexture(EsoQR.name .. "/img/start_mousedown.dds")
        EsoQR.UI.button:SetMouseOverTexture(EsoQR.name .. "/img/start_mouseover.dds")
        EsoQR.run_var = false
        EsoQR.UI.button:SetHandler("OnClicked", _toggle_running_state)

        --addon menu
        local LAM = LibAddonMenu2
        local panelName = EsoQR.name .. "Settings"
         
        local panelData = {
            type = "panel",
            name = EsoQR.name .. " Settings",
            author = "Semjon Kerner",
        }
        local panel = LAM:RegisterAddonPanel(panelName, panelData)
        local optionsData = {
            {
                type = "slider",
                name = "Maximum Pixels",
                min = 25,
                max = 75,
                default = 25,
                getFunc = function() return EsoQRparams.maxpixels end,
                setFunc = function(value) EsoQRparams.maxpixels = value end,
                tooltip = "Set the maximum of pixels for QR Code that get initialized.",
                requiresReload = true
            },
            {
                type = "slider",
                name = "Pixel Size",
                min = 1,
                max = 8,
                default = 2,
                getFunc = function() return EsoQRparams.pixelsize end,
                setFunc = function(value)
                    EsoQRparams.pixelsize = value
                    EsoQR.UI.background:SetDimensions(4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4, 4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4)
                    for i = 0,EsoQRparams.maxpixels-1 do
                        for j = 0,EsoQRparams.maxpixels-1 do
                            EsoQR.UI.pixel[i][j]:SetDimensions(EsoQRparams.pixelsize, EsoQRparams.pixelsize)
                            EsoQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, EsoQR.UI.background, TOPLEFT, 4+(i*EsoQRparams.pixelsize), 4+(j*EsoQRparams.pixelsize))
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
                getFunc = function() return EsoQRparams.updatetime end,
                setFunc = function(value) EsoQRparams.updatetime = value end,
                tooltip = "Set the wait time between each QR Code Update in ms."
            }
        }
        LAM:RegisterOptionControls(panelName, optionsData)
        
    end
end
 
EVENT_MANAGER:RegisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED, EsoQR.OnAddOnLoaded)