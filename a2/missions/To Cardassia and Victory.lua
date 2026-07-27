-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 9 CONVERSION
-- Behaviour evidence: a2_kling09S.dsl, a2_kling09R.drl, a2_kling09.bzn.

class 'A2Kling09Mission'

local function valid( entity ) return entity ~= nil and entity.valid end

local function live( entity )
    return valid( entity ) and ( entity.crew == nil or entity.crew > 0 )
end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function findLabel( label )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft ) and entity.label == label
    end ):findOne( )
end

local function findCraft( odf, team )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( odf == nil or entity.odf == odf )
            and ( team == nil or entity.player.number == team )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( )
end

local function nearest( position, entities )
    local answer, best
    for _, entity in pairs( entities ) do
        if valid( entity ) then
            local distance = distanceSquared( position, entity.position )
            if best == nil or distance < best then answer, best = entity, distance end
        end
    end
    return answer
end

local function safeOrder( entity, order, target )
    if not live( entity ) then return end
    local ok, message
    if target == nil then
        ok, message = pcall( function( ) entity:giveOrder( order ) end )
    else
        ok, message = pcall( function( ) entity:giveOrder( order, target ) end )
    end
    if not ok then
        print( "[CardassiaVictory] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local function numberedLabels( prefix, count )
    local answer = { }
    for index = 1, count do answer[ #answer + 1 ] = prefix .. tostring( index ) end
    return answer
end

local PLANET_LABELS = {
    "objectPlanetCardassia", "objectPlanetOnir", "objectPlanetFroa",
    "objectPlanetIngar", "objectPlanetSveirod"
}

local PLANET_POSITIONS = {
    Vector( 12100, 0, 1900 ), Vector( 14000, 0, 6800 ),
    Vector( 6300, 0, 8800 ), Vector( 1312, 0, 3252 ),
    Vector( 1670, 0, 11005 )
}

local DEFENSE_FLEETS = {
    numberedLabels( "carfleet1_", 14 ),
    numberedLabels( "carfleet2_", 4 ),
    numberedLabels( "carfleet3_", 4 ),
    numberedLabels( "carfleet4_", 9 )
}

local SCOUT_GROUP = {
    "objectScout1", "objectScout2", "objectRescue1_1", "objectRescue1_2",
    "objectRescue2_1", "objectRescue2_2"
}

local MOBILE_CARDASSIAN_ODFS = {
    [ "cdestroy.odf" ] = true, [ "cdestroy2.odf" ] = true,
    [ "cfrigate.odf" ] = true, [ "cscout.odf" ] = true,
    [ "ccruise1.odf" ] = true, [ "ccruise2.odf" ] = true,
    [ "ccruise3.odf" ] = true, [ "cbattle.odf" ] = true,
    [ "cbattle2.odf" ] = true, [ "cassault.odf" ] = true,
    [ "cspecial.odf" ] = true, [ "csuper.odf" ] = true
}

function A2Kling09Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.sighted = { false, false, false, false, false }
    self.captured = { false, false, false, false, false }
    self.siegeSent = { false, false, false, false, false }
    self.scoutsActive = false
    self.rescueSent = { false, false }
    self.martokWarningPlayed = false
end

function A2Kling09Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k09_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self, timerObject, hook ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling09Mission:setup( )
    print( "[CardassiaVictory] clean-room a2_kling09 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.scriptedCardassian = Player( 8 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedCardassian, Player.Relation.Enemy )
    self.scriptedCardassian:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedCardassian, Player.Relation.Ally )
    self.scriptedCardassian:setRelation( self.cardassian, Player.Relation.Ally )
    self:isolateDefenseFleets( )
    Objectives:load( "a2_kling09_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling09Mission:isolateEntity( entity )
    if not live( entity ) then return end
    safeOrder( entity, GameObject.Order.Stop, nil )
    pcall( function( )
        entity.forceOntoMap = false
        entity.player = self.scriptedCardassian
        entity.perceivedTeam = self.cardassian
    end )
end

function A2Kling09Mission:isolateDefenseFleets( )
    for _, fleet in ipairs( DEFENSE_FLEETS ) do
        for _, label in ipairs( fleet ) do self:isolateEntity( findLabel( label ) ) end
    end
    for _, label in ipairs( SCOUT_GROUP ) do self:isolateEntity( findLabel( label ) ) end
end

function A2Kling09Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.martok = findLabel( "objectMartok" )
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -440, 200, -580 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "TO CARDASSIA AND VICTORY", 50, 50, 8.0, true )
    UI:addSubtitle( "Cardassian Home System", 50, 85, 8.0, true )
    Media:playMusic( "mkli30.wav" )
    self:schedule( "intro_voice", 4.0, "playIntroVoice" )
    self:schedule( "opening_done", 38.0, "finishOpening" )
end

function A2Kling09Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling09_intro.wav" ) end
end

function A2Kling09Mission:planetCraft( )
    return EntityFinder( function( entity )
        if not entity:isType( Entity.Type.Craft ) then return false end
        local odf = string.lower( entity.odf or "" )
        return string.sub( odf, 1, 3 ) == "pb_"
    end ):find( )
end

function A2Kling09Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self.phase = "gameplay"
    self.martok = findLabel( "objectMartok" ) or self.martok
    self.planets = { }
    local allPlanets = self:planetCraft( )
    for index, label in ipairs( PLANET_LABELS ) do
        self.planets[ index ] = findLabel( label )
            or nearest( PLANET_POSITIONS[ index ], allPlanets )
    end
    Objectives:load( "a2_kling09_main.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling09_build_list.aip" )
    self:schedule( "scouts", 180.0, "beginScouting" )
    print( "[CardassiaVictory] gameplay started" )
end

function A2Kling09Mission:beginScouting( )
    if self.phase ~= "gameplay" then return end
    self.scoutsActive = true
    for _, label in ipairs( { "objectScout1", "objectScout2" } ) do
        local scout = findLabel( label )
        if live( scout ) then
            pcall( function( ) scout.forceOntoMap = true end )
            safeOrder( scout, GameObject.Order.Scout, nil )
        end
    end
end

function A2Kling09Mission:checkScoutRescue( )
    if not self.scoutsActive then return end
    for index = 1, 2 do
        local scout = findLabel( "objectScout" .. tostring( index ) )
        if not self.rescueSent[ index ] and live( scout ) and scout.underAttack then
            self.rescueSent[ index ] = true
            for escort = 1, 2 do
                local rescue = findLabel( "objectRescue" .. tostring( index )
                    .. "_" .. tostring( escort ) )
                if live( rescue ) then
                    pcall( function( ) rescue.forceOntoMap = true end )
                    safeOrder( rescue, GameObject.Order.Move, scout )
                end
            end
        end
    end
end

function A2Kling09Mission:playerNearPlanet( planet )
    if not valid( planet ) then return false end
    for _, ship in pairs( findCraft( nil, 1 ) ) do
        if live( ship ) and distanceSquared( ship.position,
            planet.position ) <= 4000000 then return true end
    end
    return false
end

function A2Kling09Mission:releaseDefenseFleet( index )
    local released = 0
    local fleet = DEFENSE_FLEETS[ index ]
    if fleet == nil then return end
    for _, label in ipairs( fleet ) do
        local ship = findLabel( label )
        if live( ship ) then
            local ok = pcall( function( )
                ship.player = self.cardassian
                ship.perceivedTeam = self.cardassian
                ship.forceOntoMap = true
            end )
            if ok then
                safeOrder( ship, GameObject.Order.SearchAndDestroy, nil )
                released = released + 1
            end
        end
    end
    print( "[CardassiaVictory] defense fleet " .. tostring( index )
        .. " released (" .. tostring( released ) .. ")" )
end

function A2Kling09Mission:planetSighted( index )
    self.sighted[ index ] = true
    if index <= 4 then self:releaseDefenseFleet( index ) end
    if index == 1 then
        Media:playMovie( "a2_kling09_head_klingon_2.bik" )
        Media:playMovie( "a2_kling09_head_martok_3.bik" )
    elseif index == 2 then
        Media:playMovie( "a2_kling09_head_kentar_1.bik" )
    end
end

function A2Kling09Mission:planetCaptured( index )
    self.captured[ index ] = true
    if not self.siegeSent[ index ] then
        local names = { "cardassia", "onir", "froa", "ingar", "sveirod" }
        self:schedule( "siege_" .. names[ index ], 60.0,
            "siegeFleet" .. tostring( index ) )
    end
    print( "[CardassiaVictory] planet " .. tostring( index ) .. " captured" )
end

function A2Kling09Mission:orderCounterattack( index )
    if self.siegeSent[ index ] then return end
    self.siegeSent[ index ] = true
    local target = self.planets[ index ]
    local yards = findCraft( "kyard.odf", 1 )
    if #yards > 0 and valid( target ) then target = nearest( target.position, yards ) end
    if not live( target ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if live( ship ) and MOBILE_CARDASSIAN_ODFS[ string.lower( ship.odf or "" ) ] then
            safeOrder( ship, GameObject.Order.Attack, target )
            ordered = ordered + 1
            if ordered >= 8 then break end
        end
    end
    print( "[CardassiaVictory] counterattack " .. tostring( index )
        .. " ordered (" .. tostring( ordered ) .. "/8)" )
end

function A2Kling09Mission:siegeFleet1( ) self:orderCounterattack( 1 ) end
function A2Kling09Mission:siegeFleet2( ) self:orderCounterattack( 2 ) end
function A2Kling09Mission:siegeFleet3( ) self:orderCounterattack( 3 ) end
function A2Kling09Mission:siegeFleet4( ) self:orderCounterattack( 4 ) end
function A2Kling09Mission:siegeFleet5( ) self:orderCounterattack( 5 ) end

function A2Kling09Mission:setObjectiveState( index, state )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = state
    end
    Objectives.visible = true
end

function A2Kling09Mission:updateObjectives( )
    self:setObjectiveState( 1, self.captured[ 1 ] )
    local secondary = self.captured[ 2 ] and self.captured[ 3 ]
        and self.captured[ 4 ] and self.captured[ 5 ]
    self:setObjectiveState( 2, secondary )
end

function A2Kling09Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 3 do self:setObjectiveState( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if valid( self.planets[ 1 ] ) then
        Cineractive:lookFrom( self.planets[ 1 ] )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.planets[ 1 ] )
    end
    UI:addTitle( "CARDASSIA PRIME IS OURS", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling09_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling09Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling09Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "CHANCELLOR MARTOK HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "mfed10.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling09Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling09Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( )
        return
    end

    if not self.martokWarningPlayed and self.martok.underAttack then
        self.martokWarningPlayed = true
        Media:playMovie( "a2_kling09_head_klingon_4.bik" )
    end

    for index, planet in ipairs( self.planets ) do
        if valid( planet ) then
            if not self.sighted[ index ] and self:playerNearPlanet( planet ) then
                self:planetSighted( index )
            end
            local belongsToPlayer = planet.player.number == 1
            if belongsToPlayer and not self.captured[ index ] then
                self:planetCaptured( index )
            elseif not belongsToPlayer and self.captured[ index ] then
                self.captured[ index ] = false
                print( "[CardassiaVictory] planet " .. tostring( index ) .. " lost" )
            end
        end
    end
    self:updateObjectives( )
    self:checkScoutRescue( )

    if self.captured[ 1 ] and self.captured[ 2 ] and self.captured[ 3 ]
        and self.captured[ 4 ] and self.captured[ 5 ] then
        self:startSuccess( )
    end
end

function A2Kling09Mission:cineractiveUpdate( ) end

function A2Kling09Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling09Mission( ) )
