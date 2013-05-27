--==============================================================
-- Copyright (c) 2010-2011 Zipline Games, Inc. 
-- All Rights Reserved. 
-- http://getmoai.com
--==============================================================

--==============================================================
-- set up
--==============================================================
print ( "hello, moai!" )

SCREEN_UNITS_X = 480
SCREEN_UNITS_Y = 320
SCREEN_WIDTH = SCREEN_UNITS_X
SCREEN_HEIGHT = SCREEN_UNITS_Y
HAZI_WIDTH = 75
HAZI_HEIGHT = 124

BABY_WIDTH=32
BABY_HEIGHT=32

BASE_X = 0
BASE_Y = SCREEN_UNITS_Y / 2 * -1

MIN_ENEMY_SPEED = 50
MAX_ENEMY_SPEED = 200
ALLY_SPEED = 500

MOAISim.openWindow ( "Rocket Lobster", SCREEN_WIDTH, SCREEN_HEIGHT )

viewport = MOAIViewport.new ()
viewport:setScale ( SCREEN_UNITS_X, SCREEN_UNITS_Y )
viewport:setSize ( SCREEN_WIDTH, SCREEN_HEIGHT )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )

font =  MOAIFont.new ()
font:loadFromTTF ("arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?! ", 12, 163 )

textbox = MOAITextBox.new ()
textbox:setFont ( font )
textbox:setRect ( -160, -80, 160, 80 )
textbox:setLoc ( 0, -160 )
textbox:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
textbox:setYFlip ( true )
alive = true

--==============================================================
-- utility functions
--==============================================================

--------------------------------
function angle ( x1, y1, x2, y2 )

	return math.atan2 ( y2 - y1, x2 - x1 ) * ( 180 / math.pi )
end

--------------------------------
function distance ( x1, y1, x2, y2 )

	return math.sqrt ((( x2 - x1 ) ^ 2 ) + (( y2 - y1 ) ^ 2 ))
end

local clock = os.clock
function sleep(n)  -- seconds
  local t0 = clock()
  while clock() - t0 <= n do end
end

--==============================================================
-- base
--==============================================================
lobsterGfx = MOAIGfxQuad2D.new ()
lobsterGfx:setTexture ( "images/openlobster.png" )
lobsterGfx:setRect ( -128, -128, 128, 128 )

haziGfx = MOAIGfxQuad2D.new ()
haziGfx:setTexture ( "images/luftballon.png" )
haziGfx:setRect ( -HAZI_WIDTH, -HAZI_HEIGHT, HAZI_WIDTH / 3, HAZI_HEIGHT / 3)

base = MOAIProp2D.new ()
base:setDeck ( lobsterGfx )
base:setLoc ( BASE_X, BASE_Y )

layer:insertProp ( base )
layer:insertProp ( textbox )

--==============================================================
-- hazi
--==============================================================

function makeHazi()
  hazi = MOAIProp2D.new ()
  hazi:setDeck ( haziGfx )
  hazi:setLoc ( BASE_X, BASE_Y * -1)
  hazi.hits = 0
  hazi.size = 75
  layer:insertProp ( hazi )
end

makeHazi()

--==============================================================
-- baby
--==============================================================

babyGfx = MOAIGfxQuad2D.new ()
babyGfx:setTexture ( "images/baby.png" )
babyGfx:setRect ( -32, -32, 32, 32 )

function makeBaby(x, y) 
  local baby = MOAIProp2D.new ()
  baby:setDeck ( babyGfx )
  baby:setLoc ( x, y )
  baby.size = 32
  baby.alive = true
  layer:insertProp ( baby )  
  return baby
end

local babySpace = BABY_WIDTH * 1.5
local babyOff = -SCREEN_WIDTH / 2;
local babies  = {
  makeBaby(babyOff + babySpace,BASE_Y),
  makeBaby(babyOff + babySpace * 2,BASE_Y),
  makeBaby(babyOff + babySpace * 3,BASE_Y),
  makeBaby(babyOff + babySpace * 7,BASE_Y),
  makeBaby(babyOff + babySpace * 8,BASE_Y),
  makeBaby(babyOff + babySpace * 9,BASE_Y),
}

--==============================================================
-- explosion rig
--==============================================================
explosionGfx = MOAIGfxQuad2D.new ()
explosionGfx:setTexture ( "images/fire.png" )
explosionGfx:setRect ( -32, -32, 32, 32 )


--------------------------------
-- pcm - should pass in the initialization here - location, size, etc.
function makeExplosion ( x, y, size )

  local explosion = MOAIProp2D.new ()
  explosion:setDeck ( explosionGfx )
  explosion:setLoc ( x, y )
  explosion.size = size
  layer:insertProp ( explosion )

  ----------------
  function explosion:main ()
	    
    for i = 1, self.size do
      self:setFrame ( -i, -i, i, i )
      coroutine.yield ()
    end
    
    layer:removeProp ( self )
  end
  
  explosion.thread = MOAIThread.new ()
  explosion.thread:run ( explosion.main, explosion )

end

--==============================================================
-- rocket 
--==============================================================
rocketGfx = MOAIGfxQuad2D.new ()
rocketGfx:setTexture ( "images/rocket.png" )
rocketGfx:setRect ( -32, -32, 32, 32 )

gameOver = false
enemyRockets = {}

--------------------------------
function makeRocket ( isAlly, startX, startY, targetX, targetY, speed )

  local travelDist = distance ( startX, startY, targetX, targetY )
  local travelTime = travelDist / speed

  local rocket = MOAIProp2D.new ()
  rocket:setDeck ( rocketGfx )
  layer:insertProp ( rocket )

  rocket:setLoc ( startX, startY )
  rocket:setRot ( angle ( startX, startY, targetX, targetY ) + 90 )
  rocket.isAlly = isAlly
  rocket.size = 32
  
  if not isAlly then
    enemyRockets [ rocket ] = rocket
  end

  ----------------
  function rocket:explode ( size )
    local x, y = self:getLoc ()
    local explosion = makeExplosion ( x, y, size )

    layer:removeProp ( self )
    
    if not isAlly then
      enemyRockets [ self ] = nil
    end
    
    self.thread:stop ()
  end

    function rocket:checkHit ( prop )

    local x1, y1 = self:getLoc ()
    local x2, y2 = prop:getLoc ()

    return distance ( x1, y1, x2, y2 ) - prop.size <= self.size
  end


  ----------------			
  function rocket:main ()
		    
    -- wait for the rocket to travel all the way to its target
    local seekAction = self:seekLoc ( targetX, targetY, travelTime, MOAIEaseType.LINEAR )
    
    while seekAction:isActive() do     
      if self.isAlly then
	for rocket in pairs ( enemyRockets ) do
	  if self:checkHit ( rocket ) then
	    self:explode ( 32 )
	    rocket:explode( 32 )
	  end
	end
	
	if self:checkHit(hazi) then
	  hazi.hits = hazi.hits + 1;
	  self:explode ( 32 )
	end
      else
	for index, baby in pairs ( babies ) do
	  if self:checkHit ( baby ) then
	    baby.alive = false
	    layer:removeProp(baby)
	    self:explode ( 32 )
	  end
	end
	

      end
      coroutine.yield ()
    end
    
    layer:removeProp ( self )
  end	

  rocket.thread = MOAIThread.new ()
  rocket.thread:run ( rocket.main, rocket )

end

--------------------------------
function launchEnemyRocket ( startX, startY )
  local baby = babies[math.random(1,#babies)]
  local babyX, babyY = baby:getLoc()
  makeRocket ( false, startX, startY, babyX, babyY, math.random ( MIN_ENEMY_SPEED, MAX_ENEMY_SPEED ))
end

--------------------------------
function launchAllyRocket ( targetX, targetY )
  makeRocket ( true, BASE_X, BASE_Y, targetX, targetY, ALLY_SPEED )
end

--==============================================================
-- game loop
--==============================================================
mainThread = MOAIThread.new ()

mainThread:run ( 

  function ()
    local level = 0
    while not gameOver do
      level = level + 1
      MIN_ENEMY_SPEED = MIN_ENEMY_SPEED * 1.2
      MAX_ENEMY_SPEED = MAX_ENEMY_SPEED * 1.2
      local frames = 0
      hazi.hits = 0
      textbox:setString ( "Level " .. tostring(level) )
      local spoolAction = textbox:spool ()
      while spoolAction:isActive() do
	coroutine.yield()
      end
      sleep(1)
      textbox:setString ( "Save the babies!" )
      spoolAction = textbox:spool ()
      while spoolAction:isActive() do
	coroutine.yield()
      end
      
      while not MOAIInputMgr.device.mouseLeft:down() do
	coroutine.yield()
      end
      textbox:setString ("")
      textbox:spool ()
      
      while not gameOver and not (hazi.hits >= 50) do
	print(hazi.hits)
	coroutine.yield()
	frames = frames + 1
	
	if frames % 30 == 0 then
	  launchEnemyRocket (hazi:getLoc())
	end
	if frames >= 90 then
	  frames = 0
	  hazi:seekLoc( 
	    math.random( -SCREEN_WIDTH + 200, SCREEN_WIDTH - 200 ),
	    math.random( 150, SCREEN_HEIGHT - HAZI_HEIGHT ), math.random( 1, 3 ), 
	    MOAIEaseType.EASE_IN )
	end

	if MOAIInputMgr.device.mouseLeft:down () then
	  launchAllyRocket ( layer:wndToWorld ( MOAIInputMgr.device.pointer:getLoc () ))
	end
	      
	gameOver = true
	for index, baby in pairs ( babies ) do
	  if baby.alive then
	    gameOver = false
	  end
	end
      end
      textbox:setString ( "You are dead!" )
      textbox:spool ()
    end 
  end
)