-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 9 CONVERSION
-- Behaviour evidence: a2_fed09S.dsl, a2_fed09R.drl, a2_fed09.bzn.

class 'A2Federation09Mission'

local function live( entity ) return entity ~= nil and entity.valid end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function findCraft( odf, team )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( odf == nil or entity.odf == odf )
            and ( team == nil or entity.player.number == team )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( )
end

local function nearest( position, entities, range )
    local result = nil
    local best = ( range or 100000 ) * ( range or 100000 )
    for _, entity in pairs( entities ) do
        if live( entity ) then
            local candidate = distanceSquared( position, entity.position )
            if candidate <= best then result, best = entity, candidate end
        end
    end
    return result
end

local function safeOrder( entity, order, target )
    if not live( entity ) then return end
    pcall( function( ) entity:giveOrder( order, target ) end )
end

local FED_START = Vector( 6200, 0, 6200 )
local BORG_BASE = Vector( 3900, 0, 1200 )
local EXTRACTION = Vector( 6000, 0, 6000 )
local REINFORCEMENT_ENTRY = Vector( 6200, 0, 5200 )

local BASE_ODFS = {
    [ "bbase.odf" ] = true, [ "byard.odf" ] = true, [ "byard2.odf" ] = true,
    [ "btechass.odf" ] = true, [ "bresear.odf" ] = true, [ "brecycle.odf" ] = true,
    [ "bsensor.odf" ] = true, [ "bmining.odf" ] = true,
    [ "bturret.odf" ] = true, [ "bturret2.odf" ] = true
}

function A2Federation09Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.reinforcementsArrived = false
    self.baseAssessed = false
    self.baseDestroyed = false
end

function A2Federation09Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f09_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation09Mission:setup( )
    print( "[StagingGrounds] clean-room a2_fed09 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 3 )
    self.borg = Player( 4 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.species:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.species, Player.Relation.Enemy )
    Objectives:load( "a2_fed09_main_objectives.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation09Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 5600, 350, 6200 ) )
    Cineractive:lookAt( FED_START )
    UI:addTitle( "STAGING GROUNDS", 50, 50, 8.0, true )
    Media:playMusic( "mfed30.wav" )
    self:schedule( "intro_one", 2.0, "introOne" )
    self:schedule( "intro_two", 13.0, "introTwo" )
    self:schedule( "intro_done", 28.0, "finishOpening" )
end

function A2Federation09Mission:introOne( )
    if self.phase == "opening" then Media:playSound( "a2_fed09_intro.wav" ) end
end

function A2Federation09Mission:introTwo( )
    if self.phase == "opening" then Media:playSound( "a2_fed09_second.wav" ) end
end

function A2Federation09Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "recon"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed09_main_objectives.txt" )
    Objectives.visible = true
    self.enterprise = nearest( FED_START, findCraft( "fente.odf", 1 ) )
    if self.enterprise == nil then self.enterprise = nearest( FED_START, findCraft( "fgalaxy.odf", 1 ) ) end
    self.borg:loadAIP( "a2_fed09_build_list.aip" )
    self:schedule( "reinforcements", 300.0, "reinforcements" )
    self:schedule( "scout_report", 450.0, "scoutReport" )
    self:schedule( "borg_wave", 490.0, "borgWave" )
    self:schedule( "defender_one", 340.0, "defenderOne" )
    self:schedule( "defender_two", 420.0, "defenderTwo" )
    self:schedule( "defender_three", 600.0, "defenderThree" )
    print( "[StagingGrounds] reconnaissance phase started" )
end

function A2Federation09Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation09Mission:spawnFleet( team, position, odfs, target )
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, team, position + Vector( ( index % 5 ) * 100, 0, math.floor( index / 5 ) * 105 ) )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation09Mission:reinforcements( )
    if self.phase == "success" or self.phase == "failure" then return end
    self.reinforcementsArrived = true
    self:spawnFleet( 1, REINFORCEMENT_ENTRY, {
        "fbattle.odf", "fbattle.odf", "fgalaxy.odf", "fgalaxy.odf",
        "fcruise1.odf", "fcruise1.odf", "fcruise2.odf", "fcruise2.odf",
        "fdestroy.odf", "ffrigate.odf", "ffrigate.odf", "fassault.odf",
        "fassault.odf", "fscout.odf", "fconst.odf", "fsrepair.odf"
    }, nil )
    Objectives:load( "a2_fed09_second_objectives.txt" )
    Objectives.visible = true
    Media:playSound( "a2_fed09_third.wav" )
    if self.baseAssessed then self.phase = "assault" end
    print( "[StagingGrounds] Federation reinforcements arrived" )
end

function A2Federation09Mission:scoutReport( )
    if self.baseAssessed or self.ending then return end
    self.baseAssessed = true
    Media:playSound( "a2_fed09_fourth.wav" )
    if self.reinforcementsArrived then self.phase = "assault" end
    print( "[StagingGrounds] Borg staging ground assessed" )
end

function A2Federation09Mission:spawnBorgAttack( odfs )
    if self.ending then return end
    self:spawnFleet( 4, BORG_BASE + Vector( 0, 0, 1200 ), odfs, self.enterprise )
end

function A2Federation09Mission:borgWave( )
    self:spawnBorgAttack( { "bcruise1.odf", "bcruise1.odf", "bcruise2.odf",
        "bcruise2.odf", "bassault.odf", "bbattle1.odf" } )
end

function A2Federation09Mission:defenderOne( )
    self:spawnBorgAttack( { "bassault.odf", "bassault.odf", "bcruise1.odf", "bcruise1.odf" } )
end

function A2Federation09Mission:defenderTwo( )
    self:spawnBorgAttack( { "bfrigate.odf", "bfrigate.odf" } )
end

function A2Federation09Mission:defenderThree( )
    self:spawnBorgAttack( { "bfrigate.odf", "bbattle1.odf" } )
end

function A2Federation09Mission:baseIsAlive( )
    for _, entity in pairs( findCraft( nil, 4 ) ) do
        if live( entity ) and BASE_ODFS[ entity.odf ] then return true end
    end
    return false
end

function A2Federation09Mission:beginExtraction( )
    if self.baseDestroyed then return end
    self.baseDestroyed = true
    self.phase = "extraction"
    Objectives:load( "a2_fed09_third_objectives.txt" )
    Objectives.visible = true
    self:complete( 1 )
    Media:playSound( "a2_fed09_fifth.wav" )
    self:spawnFleet( 4, BORG_BASE, {
        "bcruise2.odf", "bcruise2.odf", "bassault.odf", "bassault.odf",
        "bbattle2.odf", "bbattle2.odf"
    }, self.enterprise )
    print( "[StagingGrounds] extraction phase started" )
end

function A2Federation09Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 2 )
    self:complete( 3 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( -550, 260, -550 ) )
        Cineractive:lookAt( self.enterprise )
    end
    UI:addTitle( "FEDERATION FLEET EXTRACTED", 50, 50, 8.0, true )
    Media:playMusic( "mfed10.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Federation09Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation09Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE ENTERPRISE HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed04_lose.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation09Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation09Mission:update( )
    if self.ending or self.phase == "loading" or self.phase == "opening" then return end
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ] or self.enterprise
    if not live( self.enterprise ) then self:startFailure( ); return end

    if not self.baseAssessed and nearest( BORG_BASE, findCraft( nil, 1 ), 1400 ) ~= nil then
        self:scoutReport( )
    end
    if self.reinforcementsArrived and self.baseAssessed and self.phase == "recon" then
        self.phase = "assault"
    end
    if self.phase == "assault" and not self:baseIsAlive( ) then self:beginExtraction( ) end
    if self.phase == "extraction"
        and distanceSquared( self.enterprise.position, EXTRACTION ) <= 850 * 850 then
        self:startSuccess( )
    end
end

function A2Federation09Mission:cineractiveUpdate( ) end

function A2Federation09Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation09Mission( ) )
