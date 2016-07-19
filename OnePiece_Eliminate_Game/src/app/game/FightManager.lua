----------------------------------------------------------------------------------
--[[
    FILE:           FightManager.lua
    DESCRIPTION:    战斗逻辑控制类
    AUTHOR:         ZhaoLu
    CREATED:        2016-06-15
--]]
----------------------------------------------------------------------------------
local GameConfig = require("data.GameConfig")
local monsterCfg = require("data.data_monster")
local skillCfg = require("data.data_skill")
local helperCfg = require("data.data_helper")
local shipCfg = GameUtil_getShipCfg()
local scheduler = require("framework.scheduler")
local stageCfg = require("data.data_stage")
local stageMapCfg = require("data.data_stagemap")
local common = require("app.common")

local FightManager = {}

function FightManager:init()
    -- print("FightManager:init")
    self.nowMonster = 1 --当前关卡玩家打到了第几个怪物
	self.shipExp = 0 -- 当前关卡获得经验
	self.winGold = 0 -- 当前关卡获得金币数
	self.starNum = 1 -- 当前关卡星星数
	self.highestScore = 0 -- 当前关卡最高分
	game.getScores = 0

	self.in_dun_skill = 0 -- 盾的技能持续4回合，是否在4回合内的判断标志
	self._skillDefNum = 0 -- 使用盾的技能增加的防御值

	self._onceRoleHarm = 0 --主角此次被打伤害
	self._onceEnemyHarm = 0 -- 敌人此次被打伤害
	self._onceRoleMeat = 0 -- 主角此次加血值

	game.collectNum = 0
	
	self.nowMonsterTb = common:parseStrOnlyWithComma(stageCfg[game.nowStage].monsterId)
	self.lifeNum = shipCfg[game.nowShipLevel].life --玩家当前最大生命
	self:resetFightData()
	self:changeFightBg()
end

function FightManager:resetFightData()
	self.round = 0

	self.nowMonsterId = tonumber(self.nowMonsterTb[self.nowMonster])
	if self.nowMonsterId==nil then
		self.nowMonsterId = 0
		return
	end
    sendMessage({msg="GAMESCENE_REFRESH_ROUND"})
	self.attackNum = 0 --玩家1次攻击伤害
	self.defNum = 0 -- 玩家1次防御
	self.enemyLife = monsterCfg[self.nowMonsterId].life -- 敌人血量

	sendMessage({msg="GAMESCENE_REFRESH_LIFE"})
end
-- boss几回合后攻击
function FightManager:getLeftRound()
	return monsterCfg[self.nowMonsterId].interval-self.round
end
-- boss当前属性
function FightManager:getEnemyAttr()
	return monsterCfg[self.nowMonsterId].type
end
-- 当前目标剩余（怪物或是收集物）
function FightManager:getGoalLeftNum()
	local goalId,goalCount = self:getGoalId()
	if goalId==0 then
		return #self.nowMonsterTb-self.nowMonster+1
	else
		return goalCount - game.collectNum
	end
end

function FightManager:addRound()
	self.round = self.round+1
	sendMessage({msg="GAMESCENE_REFRESH_ROUND"})
end
-- 防御技能计算回合数
function FightManager:calDun2Skill()
	self.in_dun_skill = math.max(self.in_dun_skill-1,0)
end
-- 每一轮判断一次boss是否要攻击
function FightManager:judgeEnemyAttack( )
	-- 如果没怪了
	if monsterCfg[self.nowMonsterId]==nil then return false end
	-- 如果打死一个怪了
	if self.enemyLife==0 then
		self.round=0
		return false
	end

	if self.round>=monsterCfg[self.nowMonsterId].interval then
		sendMessage({msg ="GAMESCENE_DISABLE"})
		scheduler.performWithDelayGlobal(function()
			self:enemyAttack()
			self.round = 0
			sendMessage({msg="GAMESCENE_REFRESH_ROUND"})
		end, 0.3)
		return true
	else
		sendMessage({msg ="GAMESCENE_ENABLE"})
		return false
	end
end

function FightManager:enemyAttack()
	-- 计算血量
	local monsterAttck = math.max(0,(monsterCfg[self.nowMonsterId].attack-self.defNum))
	self.lifeNum = math.max(0,(self.lifeNum - monsterAttck))

	self._onceRoleHarm = monsterAttck

	sendMessage({msg ="ENEMY_ROLE",aniStr = "attack"})
	sendMessage({msg ="MAIN_ROLE",aniStr = "beat"})
end

-- 基础伤害、血量、防御值
function FightManager:getBasicNum(actType,cellId)
	if actType == "attack" then
		local attackNum = shipCfg[game.nowShipLevel].attack
		local level = game.helper[cellId]
		local attackAdd = skillCfg[level] and skillCfg[level]["attr"..helperCfg[cellId].attr] or 0
		attackNum = attackNum + attackAdd
		return attackNum
	elseif actType == "def" then
		local level = game.helper[5]
		local defNum = shipCfg[game.nowShipLevel].def
		local attrAdd = skillCfg[level] and skillCfg[level]["attr"..helperCfg[5].attr] or 0
		defNum = defNum + tonumber(attrAdd)
		return defNum
	elseif actType == "life" then
		local level = game.helper[6]
		local lifeNum = shipCfg[game.nowShipLevel].life
		local attrAdd = skillCfg[level] and skillCfg[level]["attr"..helperCfg[6].attr] or 0
		lifeNum = lifeNum + tonumber(attrAdd)
		return lifeNum
	end 
end
-- 和boss属性相克或相同的加成
function FightManager:getCellMultiplication( cellId )
	-- boss无属性
	if monsterCfg[self.nowMonsterId].type==0 then
		return 1
	end

	if cellId == monsterCfg[self.nowMonsterId].type then
		return 0.5
	elseif (cellId+1)%4==monsterCfg[self.nowMonsterId].type or (cellId==3 and monsterCfg[self.nowMonsterId].type==4) then
		return 2
	end
	return 1
end
--计算物块连消后双方生命值和防御值
function FightManager:calActNum( cellIdTb )
	local meatAdd,defAdd = 0,0
	for i,cellId in ipairs(cellIdTb) do
		if cellId<=4 then
			local attackAdd = self:getBasicNum("attack",cellId)*self:getCellMultiplication(cellId)
			self.attackNum = math.ceil(self.attackNum + attackAdd)
		elseif cellId == 6 then
			meatAdd = meatAdd + 1
		elseif cellId == 5 then
			defAdd = defAdd + 1
		end
	end
	self.enemyLife = math.max(0,(self.enemyLife - self.attackNum))
	self.lifeNum = math.min(shipCfg[game.nowShipLevel].life,(self.lifeNum + self:getBasicNum("life")*meatAdd))
	self.defNum = self:getBasicNum("def")*defAdd
	if self.in_dun_skill>0 then
		self.defNum = self.defNum + self._skillDefNum
	end

	-- 动画播放时要弹出数字动画
	self._onceEnemyHarm = self.attackNum
	self._onceRoleMeat = self:getBasicNum("life")*meatAdd
end
-- 计算帮手直接伤害
function FightManager:calHelperNum( btnNum )
	local skillId = helperCfg[game.helperOnFight[btnNum]].skill
	local skillNum = skillCfg[game.helper[skillId]]["skill"..skillId]

	if skillId>=1 and skillId<=4 then
		self.enemyLife = math.max(0,(self.enemyLife - skillNum))
		self._onceEnemyHarm = skillNum
	elseif skillId==5 then
		self.in_dun_skill = 4
		self._skillDefNum = skillNum
	elseif skillId==6 then
		self._onceRoleMeat = skillNum
		self.lifeNum = math.min(shipCfg[game.nowShipLevel].life,(self.lifeNum + skillNum))
	end
end
-- 展示帮手动画
function FightManager:runHelperAni( btnNum )
	--sendMessage({msg="GAMESCENE_DISABLE"})
    local skillId = helperCfg[game.helperOnFight[btnNum]].skill
	if skillId>=1 and skillId<=4 then
		sendMessage({msg="HELPER_ANI",csbFile = "zoro.csb"})
		
	elseif skillId==5 then
		sendMessage({msg="HELPER_ANI",csbFile = "luffy01.csb"})
		sendMessage({msg ="MAIN_ROLE",aniStr = "shield2"})
	elseif skillId==6 then
		sendMessage({msg="HELPER_ANI",csbFile = "luffy01.csb"})
		sendMessage({msg ="MAIN_ROLE",aniStr = "meat"})
	end
end
-- 计算连接伤害
function FightManager:calLinkHarm( cellId,linkCount )
	local attackNum = 0
	for i=1,linkCount do
		attackNum = math.ceil(attackNum + self:getBasicNum("attack",cellId)*self:getCellMultiplication(cellId))
	end
	return attackNum
end
-- 计算连接加血
function FightManager:calLinkMeat( linkCount )
	return self:getBasicNum("life")*linkCount
end
-- 战斗一轮结束后重置攻击伤害
function FightManager:resetAttackNum()
	self.attackNum = 0
end
-- 战斗一轮结束后重置防御伤害
function FightManager:resetDefNum()
	self.defNum = 0
end
-- 打败一个怪物后重置数据
function FightManager:beatOneEnemy()
	self.nowMonster = self.nowMonster + 1
	self:resetFightData()
end
-- 获取当前怪物
function FightManager:getNowEnemyCsb()
	if self.nowMonsterId~=0 then
		return monsterCfg[self.nowMonsterId].csb
	else
		return nil
	end
end
-- 获取主角当前等级总血量
function FightManager:getNowRoleMaxLife()
	return shipCfg[game.nowShipLevel].life
end
-- 获取当前敌人总血量
function FightManager:getNowEnemyMaxLife()
	return monsterCfg[self.nowMonsterId].life
end
-- 复活设置当前血量
function FightManager:setRoleLifePercent(per)
	self.lifeNum = per*shipCfg[game.nowShipLevel].life
end

-- 战斗胜利计算星星数和获得经验
function FightManager:calStarAndExp()
	-- 计算星星数
	for i=3,1,-1 do
		if game.getScores>stageCfg[game.nowStage]["starScore"..i] then
			self.starNum = i
			break
		end
	end
	-- 记录星星数
	if game.stageStars[game.nowStage] then
		game.stageStars[game.nowStage] = math.max(self.starNum,game.stageStars[game.nowStage])
	else
		game.stageStars[game.nowStage] = self.starNum
	end
	UserDefaultUtil:saveStageStars()

	local rewardStr = stageCfg[game.nowStage]["starReward"..self.starNum]
	local rewardCfg = common:parseStrWithComma(rewardStr)
	for i,v in ipairs(rewardCfg) do
		if v.id == game.ITEM.EXP then
			self.shipExp = v.count
		elseif v.id == game.ITEM.GOLD then
			self.winGold = v.count
		end
	end
	game.nowShipExp = game.nowShipExp + self.shipExp
	game.myGold = game.myGold + self.winGold
	-- 船升级
	if game.nowShipExp>=shipCfg[game.nowShipLevel].needExp then
		game.nowShipExp = game.nowShipExp - shipCfg[game.nowShipLevel].needExp
		game.nowShipLevel = game.nowShipLevel + 1
		game.isShipUpgrade = true
		UserDefaultUtil:saveShipLevel()
	end
	UserDefaultUtil:saveShipExp()

	-- 保存最高分
	if game.stageMaxScore[game.nowStage] then
		game.stageMaxScore[game.nowStage] = math.max(game.stageMaxScore[game.nowStage],game.getScores)
	else
		game.stageMaxScore[game.nowStage] = game.getScores
	end
	self.highestScore = game.stageMaxScore[game.nowStage]
	UserDefaultUtil:saveStageMaxScore()

	-- 保存关卡数据
	UserDefaultUtil:SaveNowMaxStage()
end

-- 收集物达到要求胜利
function FightManager:judgeWin()
	local _goalTb = common:parseStrWithComma(stageCfg[game.nowStage].goal)
	for i,v in ipairs(_goalTb) do
		-- 收集物
		if v.id==2 and game.collectNum==v.count then
			sendMessage({msg="WIN"})
		end
	end
end
-- 判断关卡目标，返回目标物id
function FightManager:getGoalId()
	local _goalTb = common:parseStrWithComma(stageCfg[game.nowStage].goal)
	for i,v in ipairs(_goalTb) do
		if v.id == 1 then
			return 0,v.count
		-- 收集物
		elseif v.id==2 then
			return stageCfg[game.nowStage].collectId,v.count
		end
	end
end

-- 切换战斗背景
function FightManager:changeFightBg()
	local mapTb = common:parseStrOnlyWithComma(stageCfg[game.nowStage].stageMap)
	sendMessage({msg="GAMESCENE_CHANGE_FIGHTBG",bgPic = stageMapCfg[tonumber(mapTb[self.nowMonster])].picPath}) 
end

return FightManager