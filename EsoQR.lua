EsoQR = { name = "EsoQR"}

local logger = LibDebugLogger(EsoQR.name)
logger:Warn("RUN")

local debugbool = true
local pixelsize = 5
local maxpixels = 25
gps = LibStub("LibGPS2")

--[[
0.  add button
1.  register event on button click (set_run_var_true())
1.1     unregister event on button click (set_run_var_true())
1.2     register event on button click (set_run_var_false())
1.3     set running_var=true
1.4     call qrcode-generation-function
2   generate qrcode in a loop
2.1     get Chalutier state, Keybindings, GPS
2.2     end qrcode-generation-function when running_var=false

- always in front
]]--

local function _test(eventCode, bookTitle, body, medium, showTitle, bookId)
    --logger:Warn(bookTitle)
    local x, y, zoneMapIndex = gps:LocalToGlobal(GetMapPlayerPosition("player"))
    --local angle = (math.deg(GetPlayerCameraHeading())-180) % 360
    --localization = string.format("%f : %f : %d", x, y, angle)

    local ok, tab_or_message = qrcode(bookTitle) --THIS IS AN IMPORTANT LINE
    
    if not ok then
        logger:Warn("is NOT ok")
    else
        logger:Warn("is ok")
        --blank
        for r=0,maxpixels-1 do
            for c=0,maxpixels-1 do
                EsoQR.UI.pixel[r][c]:SetHidden(true)
            end
        end
        
        --set
        for i,ref in pairs(tab_or_message) do
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

function EsoQR.OnAddOnLoaded(event, addonName)
    if addonName == EsoQR.name then
        logger:Warn("init esoqr")
        EVENT_MANAGER:UnregisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED)
        
        EsoQR.UI = WINDOW_MANAGER:CreateControl(nil, GuiRoot, CT_TOPLEVELCONTROL)
        EsoQR.UI:SetMouseEnabled(true)
        EsoQR.UI:SetClampedToScreen(true)
        EsoQR.UI:SetMovable(true)
        EsoQR.UI:SetDimensions(64, 92)
        EsoQR.UI:SetDrawLevel(0)
        EsoQR.UI:SetDrawLayer(0)
        EsoQR.UI:SetDrawTier(0)
        
        EsoQR.UI.background = WINDOW_MANAGER:CreateControl(nil, EsoQR.UI, CT_TEXTURE)
        EsoQR.UI.background:SetDimensions(4 + maxpixels*pixelsize + 4, 4 + maxpixels*pixelsize + 4) -- 4 + 25*2 + 4
        EsoQR.UI.background:SetColor(1, 1, 1)
        EsoQR.UI.background:SetAnchor(TOPLEFT, EsoQR.UI, TOPLEFT, 0, 0)
        EsoQR.UI.background:SetHidden(false)
        EsoQR.UI.background:SetDrawLevel(0)
        
        EsoQR.UI.pixel = {}
        for i = 0,24 do
            EsoQR.UI.pixel[i] = {}
            for j = 0,24 do
                EsoQR.UI.pixel[i][j] = WINDOW_MANAGER:CreateControl(nil, EsoQR.UI, CT_TEXTURE)
                EsoQR.UI.pixel[i][j]:SetDimensions(pixelsize, pixelsize)
                EsoQR.UI.pixel[i][j]:SetColor(0, 0, 0)
                EsoQR.UI.pixel[i][j]:SetAnchor(TOPLEFT, EsoQR.UI.background, TOPLEFT, 4+(i*pixelsize), 4+(j*pixelsize))
                EsoQR.UI.pixel[i][j]:SetHidden(true)
                EsoQR.UI.pixel[i][j]:SetDrawLevel(1)
            end
        end
        
        if debugbool then
            EVENT_MANAGER:RegisterForEvent(EsoQR.name, EVENT_SHOW_BOOK, _test)
        end
    end
end
 
EVENT_MANAGER:RegisterForEvent(EsoQR.name, EVENT_ADD_ON_LOADED, EsoQR.OnAddOnLoaded)
logger:Warn("RUN DONE")