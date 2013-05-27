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

MIN_ENEMY_SPEED = 200
MAX_ENEMY_SPEED = 300

ALLY_SPEED = 300

MOAISim.openWindow ( "Rocket Lobster", SCREEN_WIDTH, SCREEN_HEIGHT )

viewport = MOAIViewport.new ()
viewport:setScale ( SCREEN_UNITS_X, SCREEN_UNITS_Y )
viewport:setSize ( SCREEN_WIDTH, SCREEN_HEIGHT )

layer = MOAILayer2D.new ()
layer:setViewport ( viewport )
MOAISim.pushRenderPass ( layer )

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

--==============================================================
-- base
--==============================================================
lobsterGfx = MOAIGfxQuad2D.new ()
lobsterGfx:setTexture ( "openlobster.png" )
lobsterGfx:setRect ( -128, -128, 128, 128 )

haziGfx = MOAIGfxQuad2D.new ()
haziGfx:setTexture ( "images/luftballon.png" )
haziGfx:setRect ( -HAZI_WIDTH, -HAZI_HEIGHT, HAZI_WIDTH / 3, HAZI_HEIGHT / 3)

hazi = MOAIProp2D.new ()
hazi:setDeck ( haziGfx )
hazi:setLoc ( BASE_X, BASE_Y * -1)
layer:insertProp ( hazi )

base = MOAIProp2D.new ()
base:setDeck ( lobsterGfx )
base:setLoc ( BASE_X, BASE_Y )
layer:insertProp ( base )

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
  layer:insertProp ( baby )  
end

local babyOff = -SCREEN_WIDTH / 2;
local babySpace = BABY_WIDTH * 1.5
local babies  = {
  makeBaby(babyOff + babySpace,BASE_Y),
  makeBaby(babyOff + babySpace * 2,BASE_Y),
  makeBaby(babyOff + babySpace * 3,BASE_Y),
  makeBaby(babyOff + babySpace * 4,BASE_Y),
  makeBaby(babyOff + babySpace * 5,BASE_Y),
  makeBaby(babyOff + babySpace * 6,BASE_Y),
  makeBaby(babyOff + babySpace * 7,BASE_Y),
  makeBaby(babyOff + babySpace * 8,BASE_Y),
  makeBaby(babyOff + babySpace * 9,BASE_Y),
}

--==============================================================
-- explosion rig
--==============================================================
explosionGfx = MOAIGfxQuad2D.new ()
explosionGfx:setTexture ( "fire.png" )
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
  function explosion:checkHit ( prop )

    local x1, y1 = self:getLoc ()
    local x2, y2 = prop:getLoc ()

    return distance ( x1, y1, x2, y2 ) <= self.size
  end

  ----------------
  function explosion:main ()
	    
    for i = 1, self.size do
      
      self:setFrame ( -i, -i, i, i )
      
      for rocket in pairs ( enemyRockets ) do
	      if self:checkHit ( rocket ) then
		      rocket:explode ( 64 )
	      end
      end
      
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
rocketGfx:setTexture ( "rocket.png" )
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

if not isAlly then
  enemyRockets [ rocket ] = rocket
end

----------------
function rocket:explode ( size )
  local x, y = self:getLoc ()
  local explosion = makeExplosion ( x, y, size )

  layer:removeProp ( self )		
  enemyRockets [ self ] = nil
  self.thread:stop ()
end

----------------			
function rocket:main ()
		  
  -- wait for the rocket to travel all the way to its target
  MOAIThread.blockOnAction ( self:seekLoc ( targetX, targetY, travelTime, MOAIEaseType.LINEAR ))
  
  -- spawn an explosion where the rocket is
  if self.isAlly then
    -- ally rocket hit end of its path, so it explodes
    self:explode ( 64 )
  else
    -- if enemy rocket gets to end of its path, the base is hit so do big explosion
    self:explode ( 128 )
    
    -- set the game over flag
    gameOver = true
    
    -- hide the base
    layer:removeProp ( base )
  end
end	

rocket.thread = MOAIThread.new ()
rocket.thread:run ( rocket.main, rocket )

end

--------------------------------
function launchEnemyRocket ( startX, startY )
  print(#babies)
  makeRocket ( false, startX, startY, babies[math.random(1,#babies)].getLoc(), math.random ( MIN_ENEMY_SPEED, MAX_ENEMY_SPEED ))
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

		local frames = 0

		while not gameOver do
		
			coroutine.yield()
			frames = frames + 1
			
			if frames >= 90 then
				frames = 0
				launchEnemyRocket (hazi:getLoc())
				hazi:seekLoc( 
				  math.random( -SCREEN_WIDTH + 200, SCREEN_WIDTH - 200 ),
				  math.random( 150, SCREEN_HEIGHT - HAZI_HEIGHT ), math.random( 1, 3 ), 
				  MOAIEaseType.EASE_IN )
			end

			if MOAIInputMgr.device.mouseLeft:down () then
				launchAllyRocket ( layer:wndToWorld ( MOAIInputMgr.device.pointer:getLoc () ))
			end
		end
		
		local font = MOAIFont.new ()
		font:loadFromTTF ( "arialbd.ttf", "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789,.?!", 12, 163 )

		local textbox = MOAITextBox.new ()
		textbox:setFont ( font )
		textbox:setTextSize ( font:getScale ())
		textbox:setRect ( -160, -80, 160, 80 )
		textbox:setAlignment ( MOAITextBox.CENTER_JUSTIFY )
		textbox:setYFlip ( true )
		textbox:setString ( "You are dead!" )
		
		layer:insertProp ( textbox )
		textbox:spool ()
	end 
)