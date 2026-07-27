-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 4 CONVERSION
-- Behaviour evidence: a2_fed04S.dsl, a2_fed04R.drl, a2_fed04.bzn.

class 'A2Federation04Mission'

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

local function nearest( position, entities, limit )
    local result = nil
    local best = ( limit or 100000 ) * ( limit or 100000 )
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

local FED_START = Vector( 3439.3801, 0, 895.98834 )
local BORG_BUILD = {
    Vector( 8977.302, 0, 11788.398 ), Vector( 9100, 0, 11780 ),
    Vector( 9225, 0, 11780 ), Vector( 9350, 0, 11780 ),
    Vector( 9474.833, 0, 11773.607 )
}
local ENTERPRISE_START = Vector( 2038.1659, 0, 12140.118 )
local WORMHOLE_POSITION = Vector( 10538.199, -40, 10840.3 )

function A2Federation04Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.tachyonBuilt = false
    self.vulcanBuilt = false
    self.yardBuilt = false
    self.repairBuilt = false
    self.enterpriseArrived = false
    self.enterpriseRepaired = false
    self.wormholeSeen = false
    self.borgDestroyed = false
    self.objectiveStage = 1
end

function A2Federation04Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f04_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation04Mission:setup( )
    print( "[AlongNeutralZone] clean-room a2_fed04 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.romulan = Player( 3 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.romulan, Player.Relation.Neutral )
    self.romulan:setRelation( self.player, Player.Relation.Neutral )
    Objectives:load( "a2_fed04_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation04Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Path( "FIRST_CAMERA_PATH" ), 0.14 )
    Cineractive:lookAt( FED_START )
    UI:addTitle( "ALONG THE NEUTRAL ZONE", 50, 50, 8.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "intro", 4.0, "playIntro" )
    self:schedule( "done", 55.0, "finishOpening" )
end

function A2Federation04Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed04_intro.wav" ) end
end

function A2Federation04Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed04_main.txt" )
    Objectives.visible = true
    self.base = nearest( FED_START, findCraft( "fbase.odf", 1 ) )
    self.enterprise = nearest( ENTERPRISE_START, findCraft( "fente.odf", nil ) )
    self.borg:loadAIP( "a2_fed04_borg_generic.aip" )
    self.romulan:loadAIP( "a2_fed04_rom_generic.aip" )
    self:schedule( "wave_one", 500.0, "borgWaveOne" )
    self:schedule( "warning", 1000.0, "enterpriseWarning" )
    self:schedule( "wave_two", 900.0, "borgWaveTwo" )
    self:schedule( "wave_three", 1000.0, "borgWaveThree" )
    self:schedule( "wave_four", 1100.0, "borgWaveFour" )
    self:schedule( "enterprise", 1200.0, "enterpriseAppears" )
    print( "[AlongNeutralZone] gameplay started" )
end

function A2Federation04Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation04Mission:refreshObjectives( )
    if self.tachyonBuilt then self:complete( 1 ) end
    if self.vulcanBuilt then self:complete( 2 ) end
    if self.yardBuilt then self:complete( 3 ) end
    if self.objectiveStage >= 2 and self.repairBuilt then self:complete( 4 ) end
    if self.objectiveStage >= 3 and self.enterpriseRepaired then self:complete( 5 ) end
    if self.borgDestroyed then
        local index = self.objectiveStage == 1 and 4 or ( self.objectiveStage == 2 and 5 or 6 )
        self:complete( index )
    end
    if self.objectiveStage >= 3 and self.enterpriseArrived and live( self.enterprise ) then self:complete( 7 ) end
end

function A2Federation04Mission:objectiveBuiltChecks( )
    if not self.tachyonBuilt and #findCraft( "fedpod5.odf", 1 ) > 0 then
        self.tachyonBuilt = true
        self:complete( 1 )
        Media:playMovie( "a2_fed04_tachyon.bik" )
        print( "[AlongNeutralZone] Tachyon Grid researched" )
    end
    if not self.vulcanBuilt and #findCraft( "fupgrade.odf", 1 ) > 0 then
        self.vulcanBuilt = true
        self:complete( 2 )
        Media:playMovie( "a2_fed04_vulcan.bik" )
        print( "[AlongNeutralZone] Vulcan Research Institute built" )
    end
    if not self.yardBuilt and #findCraft( "fyard2.odf", 1 ) > 0 then
        self.yardBuilt = true
        self:complete( 3 )
        Media:playMovie( "a2_fed04_shipyard.bik" )
        print( "[AlongNeutralZone] advanced shipyard built" )
    end
    if not self.repairBuilt and #findCraft( "fsrepair.odf", 1 ) > 0 then
        self.repairBuilt = true
        self:complete( 4 )
        Media:playSound( "a2_fed04_repair.wav" )
        print( "[AlongNeutralZone] repair ship built" )
    end
end

function A2Federation04Mission:targetForBorg( position )
    local target = nearest( position, findCraft( "fmining.odf", 1 ) )
    if target == nil then target = nearest( position, findCraft( "fbase.odf", 1 ) ) end
    if target == nil then target = nearest( position, findCraft( nil, 1 ) ) end
    return target
end

function A2Federation04Mission:spawnBorgWave( odfs )
    local target = self:targetForBorg( BORG_BUILD[ 1 ] )
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 2, BORG_BUILD[ index ] )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation04Mission:borgWaveOne( )
    if self.phase == "gameplay" then
        self:spawnBorgWave( { "bdestroy.odf", "bdestroy.odf", "bdestroy.odf", "bdestroy.odf" } )
    end
end

function A2Federation04Mission:borgWaveTwo( )
    if self.phase == "gameplay" then
        self:spawnBorgWave( { "bcruise1.odf", "bcruise1.odf" } )
    end
end

function A2Federation04Mission:borgWaveThree( )
    if self.phase == "gameplay" then
        self:spawnBorgWave( { "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bcruise2.odf", "bcruise2.odf" } )
    end
end

function A2Federation04Mission:borgWaveFour( )
    if self.phase == "gameplay" then
        self:spawnBorgWave( { "bbattle1.odf", "bcruise2.odf", "bcruise2.odf", "bcruise2.odf" } )
    end
end

function A2Federation04Mission:enterpriseWarning( )
    if self.phase ~= "gameplay" then return end
    self.objectiveStage = 2
    Objectives:load( "a2_fed04_second.txt" )
    Objectives.visible = true
    self:refreshObjectives( )
    Media:playSound( "a2_fed04_ent_warning.wav" )
    print( "[AlongNeutralZone] Enterprise distress call received" )
end

function A2Federation04Mission:enterpriseAppears( )
    if self.phase ~= "gameplay" then return end
    self.enterprise = nearest( ENTERPRISE_START, findCraft( "fente.odf", nil ) )
    if not live( self.enterprise ) then
        self.enterprise = Entity.add( "fente.odf", 1, ENTERPRISE_START )
    else
        pcall( function( ) self.enterprise.player = self.player end )
        pcall( function( ) self.enterprise.position = ENTERPRISE_START end )
    end
    pcall( function( ) self.enterprise.name = "USS Enterprise-E" end )
    pcall( function( ) self.enterprise.shields = 0.0 end )
    local destination = self.base or FED_START
    safeOrder( self.enterprise, GameObject.Order.Go, destination )
    self.enterpriseArrived = true
    self.objectiveStage = 3
    Objectives:load( "a2_fed04_third.txt" )
    Objectives.visible = true
    self:refreshObjectives( )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:lookFrom( Path( "ENTERPRISE_ARRIVE_PATH" ), 0.60 )
    Cineractive:lookAt( self.enterprise )
    UI:addTitle( "USS ENTERPRISE-E", 50, 50, 6.0, true )
    Media:playSound( "a2_fed04_ent_arrives.wav" )
    self:schedule( "enterprise_cine_done", 18.0, "endEnterpriseCineractive" )
    print( "[AlongNeutralZone] Enterprise arrived" )
end

function A2Federation04Mission:endEnterpriseCineractive( )
    if self.phase == "gameplay" then Cineractive.active = false end
end

function A2Federation04Mission:checkEnterpriseRepair( )
    if not self.enterpriseArrived or self.enterpriseRepaired or not live( self.enterprise ) then return end
    local repair = nearest( self.enterprise.position, findCraft( "fsrepair.odf", 1 ), 650 )
    local shields, maxShields = 0, 0
    pcall( function( )
        shields = self.enterprise.shields or 0
        maxShields = self.enterprise.maxShields or 0
    end )
    if live( repair ) and maxShields > 0 and shields / maxShields >= 0.90 then
        self.enterpriseRepaired = true
        self:complete( 5 )
        Media:playMovie( "a2_fed04_ent_repaired.bik" )
        print( "[AlongNeutralZone] Enterprise repaired" )
    end
end

function A2Federation04Mission:checkWormhole( )
    if self.wormholeSeen then return end
    local scout = nearest( WORMHOLE_POSITION, findCraft( nil, 1 ), 1700 )
    if live( scout ) then
        self.wormholeSeen = true
        Media:playMovie( "a2_fed04_wormhole.bik" )
        print( "[AlongNeutralZone] wormhole sighted" )
    end
end

function A2Federation04Mission:checkBorgDestroyed( )
    if self.borgDestroyed then return end
    if #findCraft( nil, 2 ) == 0 then
        self.borgDestroyed = true
        self:refreshObjectives( )
        print( "[AlongNeutralZone] all Borg destroyed" )
    end
end

function A2Federation04Mission:readyToWin( )
    return self.tachyonBuilt and self.vulcanBuilt and self.yardBuilt
        and self.repairBuilt and self.enterpriseArrived
        and self.enterpriseRepaired and self.borgDestroyed
end

function A2Federation04Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:refreshObjectives( )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 2.0 )
    Cineractive:lookFrom( Path( "FIRST_WIN_CAMERA_PATH" ), 0.05 )
    Cineractive:lookAt( WORMHOLE_POSITION )
    UI:addTitle( "MISSION ACCOMPLISHED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed04_win.wav" )
    self:schedule( "success", 33.0, "finishSuccess" )
end

function A2Federation04Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation04Mission:startFailure( title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( "a2_fed04_lose.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation04Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation04Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if self.enterpriseArrived and ( not live( self.enterprise )
        or ( self.enterprise.crew ~= nil and self.enterprise.crew <= 0 ) ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED" ); return
    end
    if #findCraft( nil, 1 ) == 0 then
        self:startFailure( "ALL FEDERATION FORCES HAVE BEEN LOST" ); return
    end
    self:objectiveBuiltChecks( )
    self:checkWormhole( )
    self:checkEnterpriseRepair( )
    self:checkBorgDestroyed( )
    if self:readyToWin( ) then self:startSuccess( ) end
end

function A2Federation04Mission:cineractiveUpdate( ) end

function A2Federation04Mission:cineractiveFinish( forced )
    if not forced then return end
    if self.phase == "opening" then self:finishOpening( )
    elseif self.enterpriseArrived and self.phase == "gameplay" then Cineractive.active = false end
end

MMM.register( A2Federation04Mission( ) )
