-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 2 CONVERSION
-- Behaviour evidence: a2_fed02S.dsl, a2_fed02R.drl, a2_fed02.bzn.

class 'A2Federation02Mission'

local function live( entity )
    return entity ~= nil and entity.valid
end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function findCraft( odf, playerNumber )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( odf == nil or entity.odf == odf )
            and ( playerNumber == nil or entity.player.number == playerNumber )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( )
end

local function nearest( position, entities )
    local answer, best = nil, 1000000000
    for _, entity in pairs( entities ) do
        if live( entity ) then
            local candidate = distanceSquared( position, entity.position )
            if candidate < best then answer, best = entity, candidate end
        end
    end
    return answer
end

local function safeOrder( entity, order, target )
    if not live( entity ) then return end
    pcall( function( ) entity:giveOrder( order, target ) end )
end

local SOURCE_STATION = Vector( 11062.6, -371.152, 4786.3096 )
local DESTINATION_STATION = Vector( 722.7681, 384.4379, 4750.947 )
local DELIVERY_TARGET = 1499 -- Retail uses 1499 to allow for floating-point rounding.

function A2Federation02Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.complete = { false, false, false, false, false }
    self.tradeApiWarningShown = false
    self.stationFound = false
end

function A2Federation02Mission:schedule( name, delay, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f02_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, delay, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation02Mission:setup( )
    print( "[Lifelines] clean-room a2_fed02 conversion loaded" )
    self.player = Player( 1 )
    self.outpost = Player( 2 )
    self.borg = Player( 4 )
    self.player:setRelation( self.outpost, Player.Relation.Ally )
    self.outpost:setRelation( self.player, Player.Relation.Ally )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.outpost:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.outpost, Player.Relation.Enemy )
    Objectives:load( "a2_fed02_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation02Mission:startOpening( )
    self.phase = "opening"
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Path( "INTRO_SHOT" ), 0.29 )
    Cineractive:lookAt( SOURCE_STATION )
    UI:addTitle( "LIFELINES", 50, 50, 7.0, true )
    UI:addSubtitle( "Alpha Theta VI", 50, 85, 7.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "intro_shot_2", 13.0, "openingShotTwo" )
    self:schedule( "intro_done", 22.0, "finishOpening" )
end

function A2Federation02Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_fed02_intro.wav" ) end
end

function A2Federation02Mission:openingShotTwo( )
    if self.phase ~= "opening" then return end
    Cineractive:lookFrom( Path( "INTRO_SHOT2" ), 0.12 )
    Cineractive:lookAt( DESTINATION_STATION )
end

function A2Federation02Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed02_A.txt" )
    Objectives.visible = true
    self.sourceStation = nearest( SOURCE_STATION, findCraft( "ftrading.odf", nil ) )
    self.destinationStation = nearest( DESTINATION_STATION, findCraft( "ftrading.odf", nil ) )
    self.borg.resources.dilithium = 5000
    self.borg.resources.metal = 5000
    self.borg.resources.latinum = 2000
    self.borg:loadAIP( "a2_fed02_main.aip" )
    self.outpost:loadAIP( "a2_fed02_fed2.aip" )
    self:schedule( "source_attack", 30.0, "attackSourceStation" )
    self:schedule( "cargo_raid", 60.0, "raidCargo" )
    print( "[Lifelines] gameplay started" )
end

function A2Federation02Mission:completeObjective( index, media )
    if self.complete[ index ] then return end
    self.complete[ index ] = true
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
    if media ~= nil then
        if string.sub( media, -4 ) == ".bik" then Media:playMovie( media )
        else Media:playSound( media ) end
    end
    print( "[Lifelines] objective " .. tostring( index ) .. " complete" )
end

function A2Federation02Mission:attackSourceStation( )
    if self.phase ~= "gameplay" or not live( self.sourceStation ) then return end
    for _, ship in pairs( findCraft( nil, 4 ) ) do
        if distanceSquared( ship.position, self.sourceStation.position ) < 18000000 then
            safeOrder( ship, GameObject.Order.Attack, self.sourceStation )
        end
    end
end

function A2Federation02Mission:raidCargo( )
    if self.phase ~= "gameplay" then return end
    local cargo = findCraft( "fcargo.odf", 1 )
    if #cargo > 0 then
        local target = cargo[ 1 ]
        local borg = nearest( target.position, findCraft( nil, 4 ) )
        if live( borg ) then safeOrder( borg, GameObject.Order.Attack, target ) end
    end
    self:schedule( "cargo_raid", 30.0, "raidCargo" )
end

function A2Federation02Mission:resourceValue( name )
    local ok, value = pcall( function( ) return self.outpost.resources[ name ] end )
    if ok and type( value ) == "number" then return value end
    return 0
end

function A2Federation02Mission:tradeValue( resource, resourceName )
    local ok, value = pcall( function( )
        return self.player:getAmountTraded(
            resource, Player.TradeDirection.To, self.outpost )
    end )
    if ok and type( value ) == "number" then
        -- Cumulative trade cannot fall if the ally spends the delivered supplies.
        -- Keep the recipient balance as a compatibility fallback for older loaders.
        return math.max( value, self:resourceValue( resourceName ) )
    end
    if not self.tradeApiWarningShown then
        self.tradeApiWarningShown = true
        print( "[Lifelines] warning: cumulative trade API unavailable; using recipient resources" )
    end
    return self:resourceValue( resourceName )
end

function A2Federation02Mission:updateObjectives( )
    local cargo = findCraft( "fcargo.odf", 1 )
    if not self.complete[ 1 ] and #cargo > 0 then
        self:completeObjective( 1, "a2_fed02_built_ship.wav" )
    end

    local playerCraft = findCraft( nil, 1 )
    if not self.complete[ 2 ] and live( self.destinationStation )
        and nearest( self.destinationStation.position, playerCraft ) ~= nil then
        local scout = nearest( self.destinationStation.position, playerCraft )
        if distanceSquared( scout.position, self.destinationStation.position ) <= 2250000 then
            self.stationFound = true
            self:completeObjective( 2, "a2_fed02_cargo.wav" )
        end
    end

    local metalTraded = self:tradeValue( Resources.Type.Metal, "metal" )
    local dilithiumTraded = self:tradeValue( Resources.Type.Dilithium, "dilithium" )
    local latinumTraded = self:tradeValue( Resources.Type.Latinum, "latinum" )
    if not self.complete[ 3 ] and metalTraded >= DELIVERY_TARGET then
        self:completeObjective( 3, "a2_fed02_metal.bik" )
    end
    if not self.complete[ 4 ] and dilithiumTraded >= DELIVERY_TARGET then
        self:completeObjective( 4, "a2_fed02_dilithium.bik" )
    end
    if not self.complete[ 5 ] and latinumTraded >= DELIVERY_TARGET then
        self:completeObjective( 5, "a2_fed02_latinum.bik" )
    end
end

function A2Federation02Mission:stationsAlive( )
    return live( self.sourceStation ) and live( self.destinationStation )
        and ( self.sourceStation.crew == nil or self.sourceStation.crew > 0 )
        and ( self.destinationStation.crew == nil or self.destinationStation.crew > 0 )
end

function A2Federation02Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:completeObjective( 6, nil )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:lookFrom( Path( "VICTORY_SHOT" ), 0.18 )
    if live( self.sourceStation ) then Cineractive:lookAt( self.sourceStation ) end
    UI:addTitle( "SUPPLY TRANSFER COMPLETE", 50, 50, 8.0, true )
    Media:playSound( "a2_fed02_success.wav" )
    print( "[Lifelines] victory accepted; recording mission success" )
    -- MMM must receive the result now so a lost Lua timer cannot prevent the
    -- campaign from unlocking the next mission during the ending sequence.
    Mission:finish( true, 12.0 )
end

function A2Federation02Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation02Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "A TRADING STATION HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed02_station_gone.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation02Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation02Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if not self:stationsAlive( ) then self:startFailure( ); return end
    self:updateObjectives( )
    if self.complete[ 1 ] and self.complete[ 2 ] and self.complete[ 3 ]
        and self.complete[ 4 ] and self.complete[ 5 ] then
        self:startSuccess( )
    end
end

function A2Federation02Mission:cineractiveUpdate( ) end

function A2Federation02Mission:cineractiveFinish( forced )
    if not forced then return end
    if self.phase == "opening" then self:finishOpening( )
    elseif self.phase == "success" then self:finishSuccess( ) end
end

MMM.register( A2Federation02Mission( ) )
