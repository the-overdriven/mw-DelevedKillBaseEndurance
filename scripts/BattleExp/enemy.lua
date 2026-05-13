local DEBUG = false

local nearby = require('openmw.nearby')
local types = require('openmw.types')
local self = require('openmw.self')
local I = require('openmw.interfaces')

local lastAttacker = nil

I.Combat.addOnHitHandler(function(attack)
  -- if DEBUG then print('[BattleExp] addOnHitHandler') end
  if attack.attacker then
    -- if DEBUG then print('[BattleExp] attacker registered') end
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

local function getEnemyName(object)
  if types.NPC.objectIsInstance(object) then
    return types.NPC.record(object).name
  elseif types.Creature.objectIsInstance(object) then
    return types.Creature.record(object).name
  end
  return 'Unknown Enemy'
end

return {
  eventHandlers = {
    Died = function()
      local enemyName = getEnemyName(self.object)
      if DEBUG then print(string.format('[BattleExp] "Died" event fired for %s', tostring(enemyName))) end
      if not lastAttacker then
        if DEBUG then print('[BattleExp] No lastAttacker!') end
        return
      end
      if not lastAttacker.isValid then
        if DEBUG then print('[BattleExp] lastAttacker not valid!') end
        return
      end
      local isPlayer = types.Player.objectIsInstance(lastAttacker)
      local isAlly = not isPlayer and isPlayerAlly(lastAttacker)
      if DEBUG then print(string.format('[BattleExp] Killer isPlayer: %s', tostring(isPlayer))) end
      if DEBUG then print(string.format('[BattleExp] Killer isAlly: %s', tostring(isAlly))) end
      if not isPlayer and not isAlly then
        if DEBUG then print('[BattleExp] Killer is not player or ally, skipping...') end
        return
      end
      local enemyLevel = types.Actor.stats.level(self.object).current
      local payload = { level = enemyLevel, name = enemyName }
      if isPlayer then
        lastAttacker:sendEvent('GrantBattleExp', payload)
      else
        for _, actor in ipairs(nearby.actors) do
          if types.Player.objectIsInstance(actor) then
            actor:sendEvent('GrantBattleExp', payload)
            break
          end
        end
      end
    end
  }
}
