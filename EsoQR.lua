EsoQR = {
    name = "EsoQR",
    run_var = false,
    oldlocal = ""
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
[ ]  always in front
[ ]  ingame addon menu to change params
[ ]  resize QR Background with table length
[ ]  blank pixels in _drawQR(key) that are not touched
[X]  easy resize QRCode
]]--

--make qr blank
local function _blankQR()
    for row=0,EsoQRparams.maxpixels-1 do
        for col=0,EsoQRparams.maxpixels-1 do
            EsoQR.UI.pixel[row][col]:SetHidden(true)
        end
    end
end

--draw qr
local function _drawQR(key)
    local ok, qrtable = qrcode(key)
    if ok then
        for i,ref in pairs(qrtable) do
            for j,val in pairs(ref) do
                if val < 0 then
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(true)
                else
                    EsoQR.UI.pixel[i-1][j-1]:SetHidden(false)
                end
            end
        end
    end
end

local function _generateQR()
    EVENT_MANAGER:UnregisterForUpdate(EsoQR.name)
    local updatetime_ms = EsoQRparams.updatetime
    
    --get the gps values and form them to a string
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
    local localization = string.format("%f : %f : %d", x, y, angle)

    --draw QRC with new location
    if EsoQR.oldlocal ~= localization then
        EsoQR.oldlocal = localization
        _blankQR()
        _drawQR(localization)
        
    --dont draw QRC when location didn't change
    else
        updatetime_ms = updatetime_ms * 2
    end
    
    --wait a moment before running again
    if EsoQR.run_var then
        EVENT_MANAGER:RegisterForUpdate(EsoQR.name, updatetime_ms, _generateQR)
    else
        _blankQR()
    end
end

local function _toggle_running_state()
    if EsoQR.run_var then
        EsoQR.run_var = false
        EsoQR.UI.button:SetNormalTexture(EsoQR.name .. "/img/start_mouseup.dds")
        EsoQR.UI.button:SetMouseOverTexture(EsoQR.name .. "/img/start_mouseover.dds")
    else
        EsoQR.run_var = true
        EsoQR.oldlocal = ""
        EsoQR.UI.button:SetNormalTexture(EsoQR.name .. "/img/start_running.dds")
        EsoQR.UI.button:SetMouseOverTexture(EsoQR.name .. "/img/start_running.dds")
        _generateQR()
    end
end

function EsoQR.OnAddOnLoaded(event, addonName)
    if addonName == EsoQR.name then
        --init once and never come here again
        EVENT_MANAGER:UnregisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED)
        
        --load settings
        EsoQRparams = ZO_SavedVars:NewAccountWide("EsoQRparamsvar", 1, nil, EsoQRdefaults)
        
        --create qr ui code elements
        EsoQR.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
        EsoQR.UI:SetMouseEnabled(true)
        EsoQR.UI:SetClampedToScreen(true)
        EsoQR.UI:SetMovable(true)
        EsoQR.UI:SetDimensions(64, 92)
        EsoQR.UI:SetDrawLevel(0)
        EsoQR.UI:SetDrawLayer(0)
        EsoQR.UI:SetDrawTier(0)
        
        EsoQR.UI.background = WINDOW_MANAGER:CreateControl(nil, EsoQR.UI, CT_TEXTURE)
        EsoQR.UI.background:SetDimensions(4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4, 4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4) -- 4 + 25*2 + 4
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
                EsoQR.UI.pixel[i][j]:SetDrawLevel(1)
            end
        end
        
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
        local panelName = EsoQR.name .. "Settings" -- TODO the name will be used to create a global variable, pick something unique or you may overwrite an existing variable!
         
        local panelData = {
            type = "panel",
            name = EsoQR.name .. " Settings",
            author = "Semjon Kerner",
        }
        local panel = LAM:RegisterAddonPanel(panelName, panelData)
        local optionsData = {
            --[[
            {
                type = "slider",
                name = "Maximum Pixels",
                min = 22,
                max = 30,
                default = 25,
                getFunc = function() return params.maxpixels end,
                setFunc = function(value) params.maxpixels = maxpixels end
            },
            ]]--
            {
                type = "slider",
                name = "Pixel Size",
                min = 1,
                max = 10,
                default = 2,
                getFunc = function() return EsoQRparams.pixelsize end,
                setFunc = function(value)
                    EsoQRparams.pixelsize = value
                    EsoQR.UI.background:SetDimensions(4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4, 4 + EsoQRparams.maxpixels*EsoQRparams.pixelsize + 4) -- 4 + 25*2 + 4
                    for i = 0,EsoQRparams.maxpixels-1 do
                        for j = 0,EsoQRparams.maxpixels-1 do
                            EsoQR.UI.pixel[i][j]:SetDimensions(EsoQRparams.pixelsize, EsoQRparams.pixelsize)
                            EsoQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, EsoQR.UI.background, TOPLEFT, 4+(i*EsoQRparams.pixelsize), 4+(j*EsoQRparams.pixelsize))
                        end
                    end
                end
            },
            {
                type = "slider",
                name = "Updatetime",
                min = 100,
                max = 10000,
                default = 400,
                getFunc = function() return EsoQRparams.updatetime end,
                setFunc = function(value) EsoQRparams.updatetime = value end
            }
        }
        LAM:RegisterOptionControls(panelName, optionsData)
        
    end
end
 
EVENT_MANAGER:RegisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED, EsoQR.OnAddOnLoaded)