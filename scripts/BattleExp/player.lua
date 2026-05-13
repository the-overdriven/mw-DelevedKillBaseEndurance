local DEBUG = true

-- useful commands for testing:
-- reloadlua
-- luap / exit()
-- I.SkillFramework.skillLevelUp('battle_experience')

local ui = require('openmw.ui')
local I = require('openmw.interfaces')
local types = require('openmw.types')
local player = require('openmw.self')
local SF = require('openmw.interfaces').SkillFramework
local storage = require('openmw.storage')
local settings = storage.playerSection('SettingsBattleExp')

if not SF then
  error('[BattleExp] Skill Framework is not loaded! Make sure it is installed and enabled.')
end

local skillIdBattleExp = 'battle_experience'
local useTypes = { Kill = 1 }

SF.registerSkill(skillIdBattleExp, {
  name = 'Battle Experience',
  description = 'Hard-earned combat experience, forged in the ashes of slain foes.',
  icon = { fgr = 'icons/k/Attribute_Endurance.dds' },
  attribute = 'endurance',
  specialization = SF.SPECIALIZATION.Combat,
  skillGain = {
    [useTypes.Kill] = 0.1 -- Amount of XP gained per kill (default)
  }
})

local statBattleExp = SF.getSkillStat(skillIdBattleExp)

-- Curve up the progression
-- progression 25->26 is ~4.18x slower than 5->6
-- progression 49->50 is ~8.26x slower than 5->6
local function getScaledExp(currentSkillLevel, xp)
  local oldSkillProgressionFormula = currentSkillLevel + 1
  local newSkillProgressionFormula = currentSkillLevel * currentSkillLevel / 10 + 1
  local scale = oldSkillProgressionFormula / newSkillProgressionFormula

  local scaledExp = xp * scale

  local userScale = math.min(math.max(settings:get('userBattleExpScale'), 1), 1000) / 100

  local userScaledExp = scaledExp * userScale

  if DEBUG then
    print(string.format(
      '[BattleExp] XP scaling. currentSkillLevel: %s, xp: %.2f, scaledExp: %.4f, userScaledExp: %.4f',
      currentSkillLevel, 
      xp,
      scaledExp,
      userScaledExp
    ))
  end

  return userScaledExp
end

-- Initialize the skill to a base level of 5 if it's currently 0 or nil
-- This ensures the UI progress bar math calculates properly
local skillStat = SF.getSkillStat(skillIdBattleExp)
if skillStat and (skillStat.base == nil or skillStat.base < 5) then
  skillStat.base = 5
end

local function growEndurance(amount)
  local endurance = types.Actor.stats.attributes.endurance(player)
  local newVal = endurance.base + amount
  endurance.base = newVal
  if DEBUG then print(string.format('[BattleExp] Endurance increased to %d', newVal)) end
end

-- HP formula: e + (e^2 / 100)
-- 30 endurance = 39 hp (9 HP more than in vanilla)
-- 50 endurance = 75 hp (15 HP more than in vanilla)
-- 62 endurance = 100 hp (corresponds to ~10 lvl orc)
-- 100 endurance = 200 hp (corresponds to ~20 lvl orc)
local function calcMaxHP(endurance)
  return endurance + (endurance * endurance / 100)
end

local function setHealthFromEndurance()
  local types = require('openmw.types')
  local player = require('openmw.self')
  local e = types.Actor.stats.attributes.endurance(player).base
  local newMaxHP = calcMaxHP(e)
  local health = types.Actor.stats.dynamic.health(player)
  health.base = newMaxHP
  -- if DEBUG then print(string.format('[BattleExp] Endurance=%d -> MaxHP=%.1f', e, newMaxHP)) end
end

-- hide character level in char sheet
local API = require('openmw.interfaces').StatsWindow
local C = API.Constants
API.modifyLine(C.DefaultLines.LEVEL, {
  visibleFn = function()
    return not settings:get('hideLevel')
  end,
})

local meleeSkills = {
  axe = true, 
  bluntweapon = true, 
  longblade = true, 
  shortblade = true, 
  spear = true
}

local SP = require('openmw.interfaces').SkillProgression
SP.addSkillLevelUpHandler(function(skillId, source, options)
  -- prevent leveling up character  
  if settings:get('disableLevel') then
    options.levelUpProgress = 0
  end
end)

SP.addSkillUsedHandler(function(skillId, source)
  if not meleeSkills[skillId] then return end

  -- reward melee fighters with small bonus for every hit  
  if settings:get('rewardMelee') then
    local meleeBonusExp = getScaledExp(statBattleExp.base, 0.01)
    if DEBUG then print('[BattleExp] Rewarded Melee use! %s', meleeBonusExp) end

    SF.skillUsed(skillIdBattleExp, {
      skillGain = meleeBonusExp,
      useType = useTypes.Kill
    })
  end

  -- reward all other melee skills for using a melee skill
  if settings:get('synergicTraining') then
    for otherSkillId, _ in pairs(meleeSkills) do
      if otherSkillId ~= skillId then
        -- if DEBUG then print(string.format('[BattleExp] synergically training: %s', otherSkillId)) end
        local stat = types.NPC.stats.skills[otherSkillId](player)
        stat.progress = stat.progress + 0.01
      end
    end
  end
end)

local function trimZeros(numStr)
  numStr = numStr:gsub("(%..-)0+$", "%1")
  numStr = numStr:gsub("%.$", "")
  return numStr
end

local function formatDisplayedExp(xp)
  local abs = math.abs(xp)
  local num

  if xp % 1 == 0 then
    num = string.format("%.0f", xp)
  elseif abs >= 10 then
    num = string.format("%.1f", xp)
  elseif abs >= 1 then
    num = string.format("%.2f", xp)
  elseif abs >= 0.01 then
    num = string.format("%.3f", xp)
  else
    num = string.format("%.4f", xp)
  end

  return trimZeros(num)
end

return {
  engineHandlers = {
    onLoad = function()
      setHealthFromEndurance()
    end,
    onActive = function()
      setHealthFromEndurance()
    end,
  },
  eventHandlers = {
    UiModeChanged = function(data)
    if not data.newMode then
      -- UI was just closed (rest, char sheet, etc.)
      setHealthFromEndurance()
      end
    end,
    GrantBattleExp = function(data)
      local enemyLevel = data and data.level or 1
      local enemyName = data and data.name
      local baseExpFactor = 0.1

      local reqForCurentLevel = SF.getSkillProgressRequirement(skillIdBattleExp)

      local currentProgressPercent = statBattleExp.progress or 0
      local currentProgress = currentProgressPercent * reqForCurentLevel

      local xpNeededToLevelUp = reqForCurentLevel - currentProgress

      if DEBUG then print(string.format('[BattleExp] xpNeededToLevelUp %s', tostring(xpNeededToLevelUp))) end

      local proportionalExp = enemyLevel * baseExpFactor
      local proportionalExpScaled = getScaledExp(statBattleExp.base, proportionalExp)

      if proportionalExpScaled >= xpNeededToLevelUp then
        local levelBefore = SF.getSkillStat(skillIdBattleExp).base

        -- add until level up
        SF.skillUsed(skillIdBattleExp, {
          skillGain = xpNeededToLevelUp,
          useType = useTypes.Kill
        })
        
        -- carryover surplus XP
        local surplusXP = proportionalExpScaled - xpNeededToLevelUp
        if surplusXP > 0 then
          SF.skillUsed(skillIdBattleExp, {
            skillGain = surplusXP,
            useType = useTypes.Kill
          })
        end

        local levelAfter = SF.getSkillStat(skillIdBattleExp).base
        local levelsGained = levelAfter - levelBefore

        growEndurance(levelsGained) -- +1 Endurance per skill level gained
        setHealthFromEndurance()
      else
        -- no skill level up
        SF.skillUsed(skillIdBattleExp, {
          skillGain = proportionalExpScaled,
          useType = useTypes.Kill
        })
      end

      if settings:get('showXpNotifications') then
        local xpToDisplay = settings:get('showScaledXp') and proportionalExpScaled or proportionalExp
        local xpToDisplayFormatted = formatDisplayedExp(xpToDisplay)
        ui.showMessage(string.format('%s defeated (+%s XP)', enemyName, xpToDisplayFormatted))
      end
    end
  }
}

-- TODO:
-- detect player's summons as killers - even possible?
