local DEBUG = false

local nearby = require('openmw.nearby')
local types = require('openmw.types')
local self = require('openmw.self')
local I = require('openmw.interfaces')

local lastAttacker = nil

I.Combat.addOnHitHandler(function(attack)
    if DEBUG then print("[BattleExp] addOnHitHandler") end
    if attack.attacker then
        if DEBUG then print("[BattleExp] attacker registered") end
        lastAttacker = attack.attacker
    end
end)

local function isPlayerAlly(actor)
    local AI = I.AI
    if not AI then return false end
    local package = AI.getActivePackage(actor)
    if not package then return false end
    return package.target and types.Player.objectIsInstance(package.target)
end

return {
    eventHandlers = {
        Died = function()
            if DEBUG then print("[BattleExp] Died fired") end
            if not lastAttacker then
                if DEBUG then print("[BattleExp] No lastAttacker!") end
                return
            end
            if not lastAttacker.isValid then
                if DEBUG then print("[BattleExp] lastAttacker not valid!") end
                return
            end
            local isPlayer = types.Player.objectIsInstance(lastAttacker)
            if DEBUG then print(string.format("[BattleExp] isPlayer: %s", tostring(isPlayer))) end
            local isAlly = not isPlayer and isPlayerAlly(lastAttacker)
            if DEBUG then print(string.format("[BattleExp] isAlly: %s", tostring(isAlly))) end
            if not isPlayer and not isAlly then
                if DEBUG then print("[BattleExp] Not player or ally, skipping") end
                return
            end
            local enemyLevel = types.Actor.stats.level(self.object).current
            if DEBUG then print(string.format("[BattleExp] enemyLevel: %d", enemyLevel)) end
            if isPlayer then
                lastAttacker:sendEvent('GrantEnduranceReward', { level = enemyLevel })
            else
                for _, actor in ipairs(nearby.actors) do
                    if types.Player.objectIsInstance(actor) then
                        actor:sendEvent('GrantEnduranceReward', { level = enemyLevel })
                        break
                    end
                end
            end
        end
    }
}
