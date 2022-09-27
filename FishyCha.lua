FishyCha =
{
    name            = "FishyCha",
    currentState    = 0,
    angle           = 0,
    swimming        = false,
    state           = {}
}
FishyCha.state     = {
    idle      =  0, --Running around, neither looking at an interactable nor fighting
    lookaway  =  1, --Looking at an interactable which is NOT a fishing hole
    looking   =  2, --Looking at a fishing hole
    depleted  =  3, --fishing hole just depleted
    nobait    =  5, --Looking at a fishing hole, with NO bait equipped
    fishing   =  6, --Fishing
    reelin    =  7, --Reel in!
    loot      =  8, --Lootscreen open, only right after Reel in!
    invfull   =  9, --No free inventory slots
    fight     = 14, --Fighting / Enemys taunted
    dead      = 15  --Dead
}

local function _changeState(state, overwrite)
    if FishyCha.currentState == state then return end

    if FishyCha.currentState == FishyCha.state.fight and not overwrite then return end

    if FishyCha.swimming and state == FishyCha.state.looking then state = FishyCha.state.lookaway end

    EVENT_MANAGER:UnregisterForUpdate(FishyCha.name .. "STATE_REELIN_END")
    EVENT_MANAGER:UnregisterForUpdate(FishyCha.name .. "STATE_DEPLETED_END")
    EVENT_MANAGER:UnregisterForEvent(FishyCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if state == FishyCha.state.depleted then
        EVENT_MANAGER:RegisterForUpdate(FishyCha.name .. "STATE_DEPLETED_END", 3000, function()
            if FishyCha.currentState == FishyCha.state.depleted then _changeState(FishyCha.state.idle) end
        end)

    elseif state == FishyCha.state.fishing then
        FishyCha.angle = (math.deg(GetPlayerCameraHeading())-180) % 360

        if not GetSetting_Bool(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) then -- false = auto_loot off
            LOOT_SCENE:RegisterCallback("StateChange", _LootSceneCB)
        end
        EVENT_MANAGER:RegisterForEvent(FishyCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if FishyCha.currentState == FishyCha.state.fishing then _changeState(FishyCha.state.reelin) end
        end)

    elseif state == FishyCha.state.reelin then
        EVENT_MANAGER:RegisterForUpdate(FishyCha.name .. "STATE_REELIN_END", 3000, function()
            if FishyCha.currentState == FishyCha.state.reelin then _changeState(FishyCha.state.idle) end
        end)
    end

    FishyCha.currentState = state
    FishyCha.CallbackManager:FireCallbacks(FishyCha.name .. "FishyCha_STATE_CHANGE", FishyCha.currentState)
end

local function _lootRelease()
    local action, _, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    local angleDiv = ((math.deg(GetPlayerCameraHeading())-180) % 360) - FishyCha.angle

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
        _changeState(FishyCha.state.looking)
    elseif action then
        _changeState(FishyCha.state.lookaway)
    elseif -30 < angleDiv and angleDiv < 30 then
        _changeState(FishyCha.state.depleted)
    else
        _changeState(FishyCha.state.idle)
    end
end

local function _lootRelease()
    local action, _, _, _, additionalInfo = GetGameCameraInteractableActionInfo()
    local angleDiv = ((math.deg(GetPlayerCameraHeading())-180) % 360) - FishyCha.angle

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then
        _changeState(FishyCha.state.looking)
    elseif action then
        _changeState(FishyCha.state.lookaway)
    elseif -30 < angleDiv and angleDiv < 30 then
        _changeState(FishyCha.state.depleted)
    else
        _changeState(FishyCha.state.idle)
    end
end

function _LootSceneCB(oldState, newState)
    if newState == SCENE_HIDDEN then -- IDLE
        _lootRelease()
        LOOT_SCENE:UnregisterCallback("StateChange", _LootSceneCB)
    elseif FishyCha.currentState ~= FishyCha.state.reelin and FishyCha.currentState ~= FishyCha.state.loot then -- fishing interrupted
        LOOT_SCENE:UnregisterCallback("StateChange", _LootSceneCB)
    elseif newState == SCENE_SHOWN then -- LOOT, INVFULL
        if (GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)) <= 0 then
            _changeState(FishyCha.state.invfull)
        else
            _changeState(FishyCha.state.loot)
        end
    end
end

local tmpInteractableName = ""
local tmpNotMoving = true
function FishyCha_OnAction()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()

    if action and (FishyCha.currentState == FishyCha.state.fishing or FishyCha.currentState == FishyCha.state.reeling) and INTERACTION_FISH ~= GetInteractionType() then -- fishing interrupted
        _changeState(FishyCha.state.idle)

    elseif action and IsPlayerTryingToMove() and FishyCha.currentState < FishyCha.state.fishing then
        _changeState(FishyCha.state.lookaway)
        tmpInteractableName = ""
        tmpNotMoving = false
        EVENT_MANAGER:RegisterForUpdate(FishyCha.name .. "MOVING", 400, function()
            if not IsPlayerTryingToMove() then
                EVENT_MANAGER:UnregisterForUpdate(FishyCha.name .. "MOVING")
                tmpNotMoving = true
            end
        end)

    elseif action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then -- NOBAIT, LOOKING
        if not GetFishingLure() then
            _changeState(FishyCha.state.nobait)
        elseif FishyCha.currentState < FishyCha.state.fishing and tmpNotMoving then
            _changeState(FishyCha.state.looking)
            tmpInteractableName = interactableName
        end

    elseif action and tmpInteractableName == interactableName and INTERACTION_FISH == GetInteractionType() then -- FISHING, REELIN+
        if FishyCha.currentState > FishyCha.state.fishing then return end
        _changeState(FishyCha.state.fishing)

    elseif action then -- LOOKAWAY
        _changeState(FishyCha.state.lookaway)
        tmpInteractableName = ""

    elseif FishyCha.currentState == FishyCha.state.reelin and GetSetting_Bool(SETTING_TYPE_LOOT, LOOT_SETTING_AUTO_LOOT) then --DEPLETED
        _lootRelease()

    elseif FishyCha.currentState ~= FishyCha.state.depleted then -- IDLE
        _changeState(FishyCha.state.idle)
        tmpInteractableName = ""
    end
end

function fishyChaInit()

    FishyCha.CallbackManager = ZO_CallbackObject:New()

    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", FishyCha_OnAction)
    ZO_PreHookHandler(RETICLE.interact, "OnHide", FishyCha_OnAction)

    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_SWIMMING, function(eventCode) FishyCha.swimming = true end)
    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_NOT_SWIMMING, function(eventCode) FishyCha.swimming = false end)
    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_DEAD, function(eventCode) _changeState(FishyCha.state.dead, true) end)
    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_ALIVE, function(eventCode) _changeState(FishyCha.state.idle) end)
    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if inCombat then
            _changeState(FishyCha.state.fight)
        elseif FishyCha.currentState == FishyCha.state.fight then
            _changeState(FishyCha.state.idle, true)
        end
    end)

    _changeState(FishyCha.state.idle)
end
