local picPath = require("data.data_picPath")
local plistPngPath = require("data.data_plistPath")
local scheduler = require("framework.scheduler")
local common = require("app.common")
local scheduler = require("framework.scheduler")
local CommonConfirmView = import("..views.CommonConfirmView")

local LoadingScene = class("LoadingScene", function()
    return display.newScene("LoadingScene")
end)

function LoadingScene:ctor()
  self._mainNode = CsbContainer:createLoadingCsb("LoadingScene.csb"):addTo(self)
  local _ani = cc.CSLoader:createTimeline("LoadingScene.csb")
  self._mainNode:runAction(_ani)
  _ani:gotoFrameAndPlay(0,215,false)
  -- 添加扫光遮罩
  self:addLightSweep()
  self._aniScheduler = scheduler.performWithDelayGlobal(function()
      _ani:gotoFrameAndPlay(135,215,true)
  end,215/GAME_FRAME_RATE)
  -- 添加扫光后的光
  local _logoNode = cc.uiloader:seekNodeByName(self._mainNode, "mLogoNode")
  self._shiningAniNode = cc.uiloader:load("ShiningAniNode.csb"):addTo(_logoNode)
  self._shiningAni = cc.CSLoader:createTimeline("ShiningAniNode.csb")
  self._shiningAniNode:runAction(self._shiningAni)
  self._shiningAniNode:setVisible(false)

  local _startBtn = cc.uiloader:seekNodeByName(self._mainNode, "mStartBtn")
  CsbContainer:decorateBtn(_startBtn, function()
      if game.PLAYERID~="" then
          UserDefaultUtil:recordCreateRole("luffy")
          _startBtn:setEnabled(false)
          self:enterMapScene()
      end
  end)

  self.all_num = #picPath + #plistPngPath
  self.load_num = 0
  self.load_plist = 0

  -- 设置全局随机种子
  math.newrandomseed()

  -- 先确定玩家sdk返回的puid
  self:initPuid()
  if game.PLAYERID=="" then
      return
  end
  -- 初始化倒计时和体力值
  self:initEnergyNum()
  -- 初始化50体力倒计时
  self:init50EnergyCount()
  -- 初始化宝箱剩余时间
  self:initBoxLeftTime()
  -- 初始化当前关卡
  self:initNowStage()
  -- 初始化星星
  self:initStageStars()
  -- 初始化关卡最大分数
  self:initStageMaxScore()
  -- 初始化帮手等级
  self:initHelperLevels()
  -- 初始化船的等级和经验
  self:initShipLevelAndExp()
  -- 初始化船的类型
  self:initShipType()
  -- 初始化金币数
  self:initGold()
  -- 初始化音乐和音效开关
  self:initMusicAndSound()
  -- 初始化当前引导步数
  self:initGuideStep()
  -- 初始化当前是否第一次开始游戏
  self:initFirstGame()
  -- 初始化是否买过一元购
  self:initOneYuan()
  -- 初始化统计部分
  self:initRecord()

  -- 每秒走一次，倒计时用
  GameUtil_addSecond()

  -- 先播放开场动画
  if game.firstEnterGame==true then
      local _preMoveNode = CsbContainer:createPushCsb("Prefacemov.csb"):addTo(self)
      local _preMoveAni = cc.CSLoader:createTimeline("Prefacemov.csb")
      _preMoveNode:runAction(_preMoveAni)
      _preMoveAni:gotoFrameAndPlay(0,280,false)
      scheduler.performWithDelayGlobal(function( )
          _preMoveNode:removeFromParent()
      end,280/GAME_FRAME_RATE)
  end

  -- 检查更新，并下载新包
  -- self.needRequest = true -- 防止重复请求
  self:checkVersion()
end

-- 添加扫光
function LoadingScene:addLightSweep(  )
    local _logoNode = cc.uiloader:seekNodeByName(self._mainNode, "mLogoNode")
    local _logoSprite = cc.uiloader:seekNodeByName(self._mainNode, "mLogoSprite")
    local clipSize = _logoSprite:getContentSize()

    local spark = display.newSprite("pic/spark.png")

    local clippingNode = cc.ClippingNode:create():addTo(_logoNode,1,1)

    clippingNode:setAlphaThreshold(0)
    clippingNode:setContentSize(clipSize)

    clippingNode:setStencil(_logoSprite)
    clippingNode:addChild(spark,1)

    spark:runAction(cc.RepeatForever:create(cc.Sequence:create(
        cc.CallFunc:create(function()
            spark:setPositionX(-self:getContentSize().width)
        end),
        cc.MoveTo:create(1.5,cc.p(self:getContentSize().width/2,0)),
        cc.CallFunc:create(function()
            self._shiningAniNode:setVisible(true)
            self._shiningAni:gotoFrameAndPlay(0,8,false)
        end)
    )))
end
function LoadingScene:initPuid( )
    if device.platform == "android" then
        local args = {}
        local className = "org/cocos2dx/sdk/EyeCat"
        local ok, _puid = luaj.callStaticMethod(className, "eye_getPuid", args, "()Ljava/lang/String;")
        print("LoadingScene:initPuid:",_puid)
        if not ok then
            game.PLAYERID = "android"
        else
            game.PLAYERID = _puid
        end
    elseif device.platform == "windows" then
        game.PLAYERID = "Win32"
    end
end

-- 初始化倒计时和体力值
function LoadingScene:initEnergyNum()
  if UserDefaultUtil:GetEnergy() == nil then
    return
  end
  local elapsedTime,countTime,energyNum = UserDefaultUtil:GetEnergy()
  if energyNum>=game.MAXENERGY then
    game.myEnergy = energyNum
    return
  end

  local diffTime = math.max((common:getElapsedTime() - elapsedTime),0)
  game.myEnergy = math.min((math.floor(diffTime/game.addOneEnergyTime)+energyNum),game.MAXENERGY)
  game.countTime = math.max((countTime-diffTime),0)
end
-- 初始化50体力倒计时
function LoadingScene:init50EnergyCount()
  if UserDefaultUtil:Get50EnergyCount() == nil then
    return
  end
  local elapsedTime,countTime = UserDefaultUtil:Get50EnergyCount()
  local diffTime = math.max((common:getElapsedTime() - elapsedTime),0)
  game.count50EnergyTime = math.max((countTime-diffTime),0)
end
-- 初始化宝箱剩余时间
function LoadingScene:initBoxLeftTime()
  print("LoadingScene:initBoxLeftTime")
  if UserDefaultUtil:GetBoxLeftTime() == nil then
    return
  end
  local elapsedTime,countTime = UserDefaultUtil:GetBoxLeftTime()
  print("LoadingScene:initBoxLeftTime common:getElapsedTime() elapsedTime,countTime"..common:getElapsedTime()..","..elapsedTime..","..countTime)
  local diffTime = math.max((common:getElapsedTime() - elapsedTime),0)
  game.boxLeftTime = math.max((countTime-diffTime),0)
end
-- 初始化当前关卡
function LoadingScene:initNowStage()
  if UserDefaultUtil:GetNowMaxStage()~=0 then
    game.NowStage = UserDefaultUtil:GetNowMaxStage()
  end
end
-- 初始化星星
function LoadingScene:initStageStars()
  if UserDefaultUtil:getStageStars()~=nil then
    game.stageStars = UserDefaultUtil:getStageStars()--{1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1,1}--UserDefaultUtil:getStageStars()
    game.myStarNum = 0
    for i,v in ipairs(game.stageStars) do
      game.myStarNum = game.myStarNum + v
    end
  end
end
-- 初始化关卡最大分数
function LoadingScene:initStageMaxScore()
  if UserDefaultUtil:getStageMaxScore()~=nil then
    game.stageMaxScore = UserDefaultUtil:getStageMaxScore()
  end
end
-- 初始化帮手等级
function LoadingScene:initHelperLevels()
  if UserDefaultUtil:getHelperLevel()~=nil then
    game.helper = UserDefaultUtil:getHelperLevel()
  end
end
-- 初始化船的等级和经验
function LoadingScene:initShipLevelAndExp()
  if UserDefaultUtil:getShipLevel()~=0 then
    game.nowShipLevel = UserDefaultUtil:getShipLevel()
  end
  if UserDefaultUtil:getShipExp()~=0 then
    game.nowShipExp = UserDefaultUtil:getShipExp()
  end
end
-- 初始化船的类型
function LoadingScene:initShipType()
  if UserDefaultUtil:getShipType()~=0 then
    game.nowShip = UserDefaultUtil:getShipType()
  end
end
-- 初始化金币
function LoadingScene:initGold()
  if UserDefaultUtil:getGold()~=0 then
    game.myGold = UserDefaultUtil:getGold()
  end
end
-- 初始化音乐和音效开关
function LoadingScene:initMusicAndSound()
  if UserDefaultUtil:getMusic()==0 or UserDefaultUtil:getSound()==0 then
    return
  end
  game.MusicOn = UserDefaultUtil:getMusic()==1
  game.SoundOn = UserDefaultUtil:getSound()==1
end
-- 初始化当前引导步数
function LoadingScene:initGuideStep()
  if UserDefaultUtil:getGuideStep()~=0 then
      game.guideStep = UserDefaultUtil:getGuideStep()
  end
end
-- 初始化当前是否第一次开始游戏
function LoadingScene:initFirstGame()
  if UserDefaultUtil:getFirstGame()~=0 then
      game.firstEnterGame = UserDefaultUtil:getFirstGame()==1
  end
end
-- 初始化是否买过一元购
function LoadingScene:initOneYuan()
  if UserDefaultUtil:getOneYuan()~=0 then
      game.boughtOneYuan = UserDefaultUtil:getOneYuan()==1
  end
end
-- 初始化统计部分
function LoadingScene:initRecord()
    -- 伙伴使用统计
    if UserDefaultUtil:getRecordHeplerUse()~=nil then
        game.recordHelperUse = UserDefaultUtil:getRecordHeplerUse()
    end
    -- 复活购买信息
    if UserDefaultUtil:getRecordRebirthBuy()~=nil then
        game.recordRebirthBuy = UserDefaultUtil:getRecordRebirthBuy()
    end
    -- 战斗结果信息
    if UserDefaultUtil:getRecordResult()~=nil then
        game.recordResult = UserDefaultUtil:getRecordResult()
    end
end

-- 加载资源进度条
function LoadingScene:enterMapScene()
  for i=1,#picPath do
    display.addImageAsync(picPath[i], handler(self,self.loadPic))
  end
  for i=1,#plistPngPath do
    display.addImageAsync(plistPngPath[i], handler(self,self.loadPlist))
  end
  
end

function LoadingScene:cacheAni()
    -- add disapear ani
    local frames = display.newFrames("disappear%02d.png",1,6)
    local animation = display.newAnimation(frames,0.6/6)     --0.6s里面播放6帧
    display.setAnimationCache("disappear",animation)
    -- add mayixian ani
    frames = display.newFrames("mayixian%d.png",1,6)
    animation = display.newAnimation(frames,0.2/6)     
    display.setAnimationCache("mayixian",animation)
    -- add 冰块破碎动画
    frames = display.newFrames("ice_%d.png",1,8)
    animation = display.newAnimation(frames,0.4/8)     
    display.setAnimationCache("ice",animation)
    -- add 石块破碎动画
    frames = display.newFrames("stone_%d.png",1,8)
    animation = display.newAnimation(frames,0.4/8)     
    display.setAnimationCache("stone",animation)
    -- add 物块静止时的扫光动画
    frames = display.newFrames("dangong%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("dangong",animation)
    frames = display.newFrames("dao%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("dao",animation)
    frames = display.newFrames("dun%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("dun",animation)
    frames = display.newFrames("juzi%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("juzi",animation)
    frames = display.newFrames("maozi%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("maozi",animation)
    frames = display.newFrames("xin%d.png",1,5)
    animation = display.newAnimation(frames,0.8/5)     
    display.setAnimationCache("xin",animation)
    -- add 水波纹动画
    frames = display.newFrames("waterflash_1_%02d.png",1,5)
    animation = display.newAnimation(frames,0.5/5)     
    display.setAnimationCache("wave1",animation)
    frames = display.newFrames("waterflash_2_%02d.png",1,7)
    animation = display.newAnimation(frames,0.7/7)     
    display.setAnimationCache("wave2",animation)
    frames = display.newFrames("waterflash_3_%02d.png",1,9)
    animation = display.newAnimation(frames,0.9/9)     
    display.setAnimationCache("wave3",animation)
    -- add 炸弹动画
    frames = display.newFrames("bomb_%d.png",1,3)
    animation = display.newAnimation(frames,0.3/3)     
    display.setAnimationCache("bomb",animation)
    -- 地图页面的广告的闪烁动画
    frames = display.newFrames("Adani%02d.png",1,11)
    animation = display.newAnimation(frames,1.1/11)     
    display.setAnimationCache("Adani",animation)
    -- 滑到飞到人身上爆炸动画
    frames = display.newFrames("body_%d.png",1,6)
    animation = display.newAnimation(frames,0.6/6)     
    display.setAnimationCache("bodySplash",animation)
end

function LoadingScene:isLoadingFinish(  )
  if self.load_num==self.all_num then 
    self:cacheAni()
    if game.firstEnterGame==true then
      app:enterScene("GameScene", nil, "fade", 0.6, display.COLOR_WHITE)
    else
      app:enterScene("MapScene", nil, "fade", 0.6, display.COLOR_WHITE)
    end
  end
end
function LoadingScene:loadPic( )
  self.load_num = self.load_num + 1
  print("LoadingScene:loadPic "..self.load_num)
  self:isLoadingFinish()
end
function LoadingScene:loadPlist( )
  self.load_plist = self.load_plist + 1
  local _plistPath = plistPngPath[self.load_plist]:sub(0,-5)..".plist"
  display.addSpriteFrames(_plistPath,plistPngPath[self.load_plist])
  self.load_num = self.load_num + 1
  print("LoadingScene:loadPlist "..self.load_num)
  self:isLoadingFinish()
end

function LoadingScene:onEnter()
  print("LoadingScene:onEnter")
  if game.firstEnterGame==true then 
    scheduler.performWithDelayGlobal(function()
        GameUtil_PlayMusic(GAME_MUSIC.loadingMusic)
    end,280/GAME_FRAME_RATE)
  else
    GameUtil_PlayMusic(GAME_MUSIC.loadingMusic)
  end
end

function LoadingScene:onExit()
  scheduler.unscheduleGlobal(self._aniScheduler)
	print("LoadingScene:onExit")
end

function LoadingScene:checkVersion()
  if network.getInternetConnectionStatus()~=0 then
      function callback(event)
          -- if self.needRequest==false then return end
          local ok = (event.name == "completed")
          local request = event.request
          if event.name then print("request event.name = " .. event.name) end
          if not ok then
              print("请求失败 "..request:getErrorMessage())
              -- MessagePopView.new("请求失败 "..request:getErrorMessage()):addTo(self)
              return
          end
          local code = request:getResponseStatusCode()
          if code ~= 200 then
              print("请求错误，代码 "..request:getResponseStatusCode())
              MessagePopView.new("请求错误，代码 "..request:getResponseStatusCode()):addTo(self)
              return
          end
          if json.decode(request:getResponseString()) then
              print("请求 LoadingScene:checkVersion "..request:getResponseString())
              local versionCfg = json.decode(request:getResponseString())
              local serverVersionTb = common:chageVersionStrToTb(versionCfg.version)
              local localVersionTb = common:chageVersionStrToTb(game.VERSION)
              if serverVersionTb[1]>localVersionTb[1] or serverVersionTb[2]>localVersionTb[2] then
                  if device.platform == "android" then
                      CommonConfirmView.new("需要更新新版本",function()
                          device.openURL(versionCfg.androidApk)
                          app.exit()
                      end,1):addTo(self)
                  elseif device.platform == "ios" then
                      CommonConfirmView.new("需要更新新版本",function()
                          device.openURL(versionCfg.iosApk)
                          app.exit()
                      end,1):addTo(self)
                  end
              else
                  -- MessagePopView.new("当前版本已经是最新版本"):addTo(self)
              end
          end
      end
      -- 创建一个请求，并以 GET 方式发送数据到服务端
      local url = "http://43.240.244.84/game/ServerVersion.cfg"
      local request = network.createHTTPRequest(callback, url, "GET")
      request:setTimeout(10)
      -- 开始请求。当请求完成时会调用 callback() 函数
      request:start()
  end
end

return LoadingScene
