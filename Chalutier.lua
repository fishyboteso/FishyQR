FishyCha_STATE_IDLE      = 0 --Running around, neither looking at an interactable nor fighting
FishyCha_STATE_LOOKAWAY  = 1 --Looking at an interactable which is NOT a fishing hole
FishyCha_STATE_LOOKING   = 2 --Looking at a fishing hole
FishyCha_STATE_NOBAIT    = 5 --Looking at a fishing hole, with NO bait equipped
FishyCha_STATE_FISHING   = 6 --Fishing
FishyCha_STATE_REELIN    = 7 --Reel in!
FishyCha_STATE_LOOT      = 8 --Lootscreen open, only right after Reel in!
FishyCha_STATE_INVFULL   = 9 --No free inventory slots
FishyCha_STATE_FIGHT     = 14 --Fighting / Enemys taunted
FishyCha_STATE_DEAD      = 15 --Dead

FishyCha = {
    name = "fishyCha",
    currentState = FishyCha_STATE_IDLE
}

local function changeState(state, overwrite)
    if FishyCha.currentState == state then return end

    if FishyCha.currentState == FishyCha_STATE_FIGHT and not overwrite then return end

    EVENT_MANAGER:UnregisterForUpdate(FishyCha.name .. "STATE_REELIN")
    EVENT_MANAGER:UnregisterForUpdate(FishyCha.name .. "STATE_FISHING")
    EVENT_MANAGER:UnregisterForEvent(FishyCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE)

    if state == FishyCha_STATE_FISHING then
        LOOT_SCENE:RegisterCallback("StateChange", _fishyChaLootSceneCB)
        --inventory opens
        EVENT_MANAGER:RegisterForEvent(FishyCha.name .. "OnSlotUpdate", EVENT_INVENTORY_SINGLE_SLOT_UPDATE, function()
            if FishyCha.currentState == FishyCha_STATE_FISHING then changeState(FishyCha_STATE_REELIN) end
        end)
        --avoid fishing interrupted badly
        EVENT_MANAGER:RegisterForUpdate(FishyCha.name .. "STATE_FISHING", 28000, function()
            if FishyCha.currentState == FishyCha_STATE_FISHING then changeState(FishyCha_STATE_IDLE) end
        end)

    elseif state == FishyCha_STATE_REELIN then
        EVENT_MANAGER:RegisterForUpdate(FishyCha.name .. "STATE_REELIN", 3000, function()
            if FishyCha.currentState == FishyCha_STATE_REELIN then changeState(FishyCha_STATE_IDLE) end
        end)

    end
    FishyCha.currentState = state
    FishyCha.CallbackManager:FireCallbacks(FishyCha.name .. "StateChange", FishyCha.currentState)
end

function _fishyChaLootSceneCB(oldState, newState)
    if newState == "showing" then -- LOOT, INVFULL
        if (GetBagUseableSize(BAG_BACKPACK) - GetNumBagUsedSlots(BAG_BACKPACK)) <= 0 then
            changeState(FishyCha_STATE_INVFULL)
        else
            changeState(FishyCha_STATE_LOOT)
        end
    end
    if newState == "hiding" then -- IDLE
        changeState(FishyCha_STATE_IDLE)
        LOOT_SCENE:UnregisterCallback("StateChange", _fishyChaLootSceneCB)
    end
end

local tmpInteractableName = ""
function fishyChaOnAction()
    local action, interactableName, _, _, additionalInfo = GetGameCameraInteractableActionInfo()

    if action and additionalInfo == ADDITIONAL_INTERACT_INFO_FISHING_NODE then -- NOBAIT, LOOKING
        if not GetFishingLure() then
            changeState(FishyCha_STATE_NOBAIT)
        elseif FishyCha.currentState < FishyCha_STATE_FISHING then
            changeState(FishyCha_STATE_LOOKING)
            tmpInteractableName = interactableName
        end

    elseif action and tmpInteractableName == interactableName then -- FISHING, REELIN+
        if FishyCha.currentState > FishyCha_STATE_FISHING then return end
        changeState(FishyCha_STATE_FISHING)

    elseif action then -- LOOKAWAY
        changeState(FishyCha_STATE_LOOKAWAY)
        tmpInteractableName = ""

    else -- IDLE
        changeState(FishyCha_STATE_IDLE)
        tmpInteractableName = ""
    end
end

function fishyChaInit()
    FishyCha.CallbackManager = ZO_CallbackObject:New()

    ZO_PreHookHandler(RETICLE.interact, "OnEffectivelyShown", fishyChaOnAction)
    ZO_PreHookHandler(RETICLE.interact, "OnHide", fishyChaOnAction)

    EVENT_MANAGER:RegisterForEvent(FishyCha.name, EVENT_PLAYER_DEAD, function(eventCode) changeState(FishyCha_STATE_DEAD, true) end)
    EVENT_MANAGER:RegisterForEvent(FishyQR.name, EVENT_PLAYER_ALIVE, function(eventCode) changeState(FishyCha_STATE_IDLE) end)
    EVENT_MANAGER:RegisterForEvent(FishyQR.name, EVENT_PLAYER_COMBAT_STATE, function(eventCode, inCombat)
        if inCombat then
            changeState(FishyCha_STATE_FIGHT)
        elseif FishyCha.currentState == FishyCha_STATE_FIGHT then
            changeState(FishyCha_STATE_IDLE, true)
        end
    end)

    FishyCha.currentState = FishyCha_STATE_IDLE
end
