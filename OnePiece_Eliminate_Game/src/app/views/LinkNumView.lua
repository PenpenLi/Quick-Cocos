----------------------------------------------------------------------------------
--[[
    FILE:           LinkNumView.lua
    DESCRIPTION:    战斗界面
    AUTHOR:         ZhaoLu
    CREATED:        2016-06-06
--]]
----------------------------------------------------------------------------------
local FightManager = require("app.game.FightManager")
local GameConfig = require("data.GameConfig")
local scheduler = require("framework.scheduler")
local common = require("app.common")

local LinkNumView = class("LinkNumView", function()
    return display.newNode()
end)

function LinkNumView:ctor(gameOverCallback)

    self._mainRoleAni = nil
    self._mainRoleNode = nil

    self._enemyAni = nil
    self._enemyNode = nil

    self:addMainRole()
    self:addEnemy()

    addMessage(self, "LINKNUMVIEW_REFRESH_HARM",self.refreshHarm)
    addMessage(self, "LINKNUMVIEW_ONCE_END_ANI",self.runEndAni)
    addMessage(self, "LINKNUMVIEW_HIDE",self.hideAllNode)

    addMessage(self, "LINK_NUM_VIEW_EXIT",self.onExit)

end

function LinkNumView:addMainRole( )
    print("LinkNumView:addMainRole")
    self._mainRoleNode =cc.CSLoader:createNode("LinkNum.csb"):addTo(self)
    self._mainRoleNode:setScale(1.5)
    self._mainRoleNode:setPosition(-200,0)
    self._mainRoleAni = cc.CSLoader:createTimeline("LinkNum.csb")
    self._mainRoleNode:runAction(self._mainRoleAni)
end

function LinkNumView:addEnemy( )
    print("LinkNumView:addEnemy")
    self._enemyNode = cc.CSLoader:createNode("LinkNum.csb"):addTo(self)
    self._enemyNode:setScale(1.5)
    self._enemyNode:setPosition(200,0)
    self._enemyAni = cc.CSLoader:createTimeline("LinkNum.csb")
    self._enemyNode:runAction(self._enemyAni)
    self:hideAllNode()
end

function LinkNumView:hideAllNode(data)
    self._enemyAni:gotoFrameAndPlay(0,1,true)
    self._mainRoleAni:gotoFrameAndPlay(0,1,true)
end
function LinkNumView:enemyNormalHarmAni()
  self._enemyAni:gotoFrameAndPlay(163,164,true)
end
function LinkNumView:enemyBigHarmAni()
  self._enemyAni:gotoFrameAndPlay(163,164,true)
end
function LinkNumView:enemyEndHarmAni()
  self._enemyAni:gotoFrameAndPlay(61,138,false)
end
function LinkNumView:enemyLoseAni()
  self._enemyAni:gotoFrameAndPlay(0,56,false)
end
function LinkNumView:roleEndHarmAni()
  self._mainRoleAni:gotoFrameAndPlay(61,138,false)
end
function LinkNumView:roleMeatAni()
  self._mainRoleAni:gotoFrameAndPlay(192,193,true)
end
function LinkNumView:roleMeatEndAni()
  self._mainRoleAni:gotoFrameAndPlay(203,218,false)
end
function LinkNumView:roleBeat2Ani()
  self._mainRoleAni:gotoFrameAndPlay(230,241,false)
  self._enemyAni:gotoFrameAndPlay(105,138,false)
end

-- 连接的同时刷新伤害值
function LinkNumView:refreshHarm(data)
  cellId,linkCount = data.cellId,data.count
  if linkCount>=3 and cellId>=1 and cellId<=4 then
      self:enemyNormalHarmAni()
      if linkCount>=6 then
          self:enemyBigHarmAni()
          sendMessage({msg="GameScene_LongLinkAni",showFlag=true})
      else
          sendMessage({msg="GameScene_LongLinkAni",showFlag=false})
      end
      local harmNum =  FightManager:calLinkHarm( cellId,linkCount )
      CsbContainer:setStringForLabel(self._enemyNode, {
          mNormalLabel = "-"..harmNum,
          mBigLabel = "-"..harmNum,
      })
  elseif linkCount>=3 and cellId==6 then
      self:roleMeatAni()
      CsbContainer:setStringForLabel(self._mainRoleNode, {
          mMeatLabel = FightManager:calLinkMeat( linkCount ),
      })
  else
      self:hideAllNode()
      sendMessage({msg="GameScene_LongLinkAni",showFlag=false})
  end

end

-- 连接结束后，播放动作时弹出的伤害动画
function LinkNumView:runEndAni( data )
    local _tag = data.aniTag
    if _tag==GameConfig.LinkNum.enemyBeat then
        scheduler.performWithDelayGlobal(function()
            self:enemyEndHarmAni()
            CsbContainer:setStringForLabel(self._enemyNode, {mEndLabel = "-"..FightManager._onceEnemyHarm})
        end,0.55)
    elseif _tag==GameConfig.LinkNum.enemyLose then
        self:enemyLoseAni()
        -- CsbContainer:setStringForLabel(self._enemyNode, {mEndLabel = FightManager._onceEnemyHarm})
    elseif _tag==GameConfig.LinkNum.roleBeat then
        scheduler.performWithDelayGlobal(function()
            self:roleEndHarmAni()
            CsbContainer:setStringForLabel(self._mainRoleNode, {mEndLabel = "-"..FightManager._onceRoleHarm})
        end,0.55)
    elseif _tag==GameConfig.LinkNum.enemyBeat2 then
        local _onceHarm,_delay = 0,0
        scheduler.performWithDelayGlobal(function() 
            local ranTb = common:random_divide_part(FightManager._onceEnemyHarm,5)
            for i=1,5 do
                scheduler.performWithDelayGlobal(function()
                    self:roleBeat2Ani()
                    _onceHarm = "-"..math.ceil(ranTb[i])
                    CsbContainer:setStringForLabel(self._enemyNode, {mEndLabel = _onceHarm})
                    CsbContainer:setStringForLabel(self._mainRoleNode, {mComboLable = i})
                end,_delay)
                _delay = _delay+15/GAME_FRAME_RATE
            end
        end,0.45)
    elseif _tag==GameConfig.LinkNum.roleMeat then
        self:roleMeatEndAni()
        CsbContainer:setStringForLabel(self._mainRoleNode, {mMeatEndLabel = FightManager._onceRoleMeat})
    end
end

function LinkNumView:onExit()
    removeMessageByTarget(self)

    self:removeAllChildren()
    self._mainRoleAni = nil
    self._mainRoleNode = nil

    self._enemyAni = nil
    self._enemyNode = nil
end

return LinkNumView