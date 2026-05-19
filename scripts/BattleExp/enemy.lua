local DEBUG = true
local nearby = require('openmw.nearby')
local types = require('openmw.types')
local self = require('openmw.self')
local I = require('openmw.interfaces')
local core = require('openmw.core')
local lastAttacker = nil

-- at the top of enemy.lua
local isThisActorPlayerSummon = false

local function findPlayer()
  for _, actor in ipairs(nearby.actors) do
    if types.Player.objectIsInstance(actor) then
      return actor
    end
  end
  return nil
end

local function checkAndCachePlayerSummon()
  local playerObj = findPlayer()
  if not playerObj then return end

  local recordId = self.recordId

  if DEBUG then print('[BattleExp] checkAndCachePlayerSummon') end
  if DEBUG then print('[BattleExp] creature name (self.recordId)', tostring(recordId)) end

  if not recordId:find('_summ') then
    if DEBUG then print('[BattleExp] checkAndCachePlayerSummon: not a summon creature, skipping') end
    return
  end

  local AI = I.AI
  if not AI then return end

  -- At spawn time, before combat, Follow->player should be the active package
  local package = AI.getActivePackage(self.object)
  if DEBUG then print(string.format('[BattleExp] checkAndCachePlayerSummon: package=%s', tostring(package and package.type))) end

  if not (package and package.type == 'Follow' and package.target and types.Player.objectIsInstance(package.target)) then
    if DEBUG then print('[BattleExp] The creature was not summoned by the player!') end
  end

  if DEBUG then print('[BattleExp] checkAndCachePlayerSummon: this actor is a player summon, caching') end
  isThisActorPlayerSummon = true
end

I.Combat.addOnHitHandler(function(attack)
  if DEBUG then print('[BattleExp] addOnHitHandler') end
  if attack.attacker then
    if DEBUG then print('[BattleExp] attacker registered', tostring(attack.attacker.name)) end
    lastAttacker = attack.attacker
  end
end)

local function isPlayerAlly(actor)
  if isThisActorPlayerSummon then return true end

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
  engineHandlers = {
    onInit = checkAndCachePlayerSummon,
  },
  eventHandlers = {
    Died = function()
      local enemyName = getEnemyName(self.object)
      local enemyLevel = types.Actor.stats.level(self.object).current
      local payload = { level = enemyLevel, name = enemyName }
      if DEBUG then print(string.format('[BattleExp] "Died" event fired for %s', tostring(enemyName))) end
      if not lastAttacker then
        -- killer is unknown, maybe magic was used?
        for _, actor in ipairs(nearby.actors) do
          if types.Player.objectIsInstance(actor) then
            actor:sendEvent('GrantBattleExpConditionally', payload)
            break
          end
        end
        if DEBUG then print('[BattleExp] No lastAttacker!') end
        return
      end
      if not lastAttacker.isValid then
        if DEBUG then print('[BattleExp] lastAttacker not valid!') end
        return
      end
      local isKillerPlayer = types.Player.objectIsInstance(lastAttacker)
      local isKillerPlayerAlly = not isKillerPlayer and isPlayerAlly(lastAttacker)
      if DEBUG then print(string.format('[BattleExp] lastAttacker: %s', tostring(lastAttacker.name))) end
      if DEBUG then print(string.format('[BattleExp] isKillerPlayer: %s', tostring(isKillerPlayer))) end
      if DEBUG then print(string.format('[BattleExp] isKillerPlayerAlly: %s', tostring(isKillerPlayerAlly))) end
      if not isKillerPlayer and not isKillerPlayerAlly then
        if DEBUG then print('[BattleExp] Killer is not player or ally, skipping...') end
        return
      end

      if isKillerPlayer then
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
