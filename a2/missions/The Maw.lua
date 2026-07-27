-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 9 CONVERSION
-- Behaviour evidence: a2_borg09S.dsl, a2_borg09R.drl, a2_borg09.bzn.

class 'A2Borg09Mission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
        and ( entity.crew == nil or entity.crew > 0 )
end

local function odfBase( entity )
    return string.gsub( string.lower( entity.odf or "" ), "%.odf$", "" )
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

local function findCraft( team, odf )
    odf = odf and string.gsub( string.lower( odf ), "%.odf$", "" ) or nil
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( team == nil or entity.player.number == team )
            and ( odf == nil or odfBase( entity ) == odf )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( ) or { }
end

local function safeAdd( odf, team, position )
    local base = string.gsub( string.lower( odf ), "%.odf$", "" )
    local before = { }
    for _, entity in pairs( findCraft( team, base ) ) do before[ entity ] = true end
    local ok, result = pcall( Entity.add, odf, Player( team ), position )
    if ok and live( result ) then return result end

    local nearest, nearestDistance = nil, 1000000000
    for _, entity in pairs( findCraft( team, base ) ) do
        if not before[ entity ] then
            local distance = distanceSquared( entity.position, position )
            if distance < nearestDistance then nearest, nearestDistance = entity, distance end
        end
    end
    return nearest
end

function A2Borg09Mission:__init( )
    self.phase = "loading"
    self.stage = "resources"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.criticalChecksEnabled = false
    self.dilithiumGathered = false
    self.metalGathered = false
    self.scoutsThrough = { }
    self.scoutCount = 0
end

function A2Borg09Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b09_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg09Mission:createTaskForce( )
    self.queen = safeAdd( "bqueen.odf", 1, Vector( 15000, 0, 14800 ) )
    safeAdd( "bbattle1.odf", 1, Vector( 14850, 0, 14650 ) )
    safeAdd( "bbattle2.odf", 1, Vector( 15150, 0, 14650 ) )
    safeAdd( "bcruise1.odf", 1, Vector( 14700, 0, 14950 ) )
    safeAdd( "bconst.odf", 1, Vector( 15250, 0, 14950 ) )

    self.enterprise = safeAdd( "fente.odf", 1, Vector( 16000, 0, 15000 ) )
    safeAdd( "fbattle.odf", 1, Vector( 15850, 0, 14850 ) )
    safeAdd( "fgalaxy.odf", 1, Vector( 16150, 0, 14850 ) )
    safeAdd( "fcruise1.odf", 1, Vector( 15800, 0, 15150 ) )
    safeAdd( "fdestroy.odf", 1, Vector( 16200, 0, 15150 ) )
    safeAdd( "fdestroy2.odf", 1, Vector( 16300, 0, 15050 ) )
    safeAdd( "fconst.odf", 1, Vector( 15700, 0, 15250 ) )
    safeAdd( "fsrepair.odf", 1, Vector( 15900, 0, 15250 ) )
    safeAdd( "ffreight.odf", 1, Vector( 16100, 0, 15550 ) )
    safeAdd( "ffreight.odf", 1, Vector( 16300, 0, 15600 ) )
end

function A2Borg09Mission:setup( )
    print( "[TheMaw] clean-room a2_borg09 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 3 )
    self.player:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.player, Player.Relation.Enemy )
    self.starbase = findLabel( "objectFedStarbase" )
    self.shipyard = findLabel( "objectFedShipyard" )
    self.rift = findLabel( "objectFluidicRift" )
    self:createTaskForce( )
    Objectives:load( "a2_borg09_primary.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg09Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "THE MAW", 50, 50, 8.0, true )
    Media:playMusic( "Mbor300.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 40.0, "finishOpening" )
end

function A2Borg09Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg09_intro.wav" ) end
end

function A2Borg09Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg09_primary.txt" )
    Objectives.visible = true
    self.species:loadAIP( "species8472_build_list.aip" )
    self.phase = "gameplay"
    self:schedule( "critical_checks", 5.0, "enableCriticalChecks" )
    self:schedule( "wave_a", 210.0, "attackStarbase" )
    self:schedule( "wave_b", 420.0, "attackShipyard" )
    self:schedule( "wave_c", 630.0, "attackFleet" )
    self:schedule( "wave_d", 840.0, "attackStarbase" )
    print( "[TheMaw] gameplay started" )
end

function A2Borg09Mission:enableCriticalChecks( ) self.criticalChecksEnabled = true end

function A2Borg09Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg09Mission:sendSpeciesAttack( target, limit )
    if not live( target ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 3, nil ) ) do
        local odf = odfBase( ship )
        if not string.find( odf, "active", 1, true )
            and not string.find( odf, "passive", 1, true )
            and not string.find( odf, "mother", 1, true )
            and not string.find( odf, "collector", 1, true )
            and not string.find( odf, "transmuter", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= limit then break end
        end
    end
end

function A2Borg09Mission:attackStarbase( ) self:sendSpeciesAttack( self.starbase, 6 ) end
function A2Borg09Mission:attackShipyard( ) self:sendSpeciesAttack( self.shipyard, 5 ) end
function A2Borg09Mission:attackFleet( ) self:sendSpeciesAttack( self.enterprise or self.queen, 6 ) end

function A2Borg09Mission:beginScoutStage( )
    if self.stage ~= "resources" then return end
    self.stage = "scouts"
    Objectives:load( "a2_borg09_modified.txt" )
    Objectives.visible = true
    self:setObjective( 1, true )
    self:setObjective( 2, true )
    Media:playSound( "a2_borg09_resources_gathered.wav" )
    Media:playMovie( "a2_borg09_build_scouts.bik" )
end

function A2Borg09Mission:updateScouts( )
    if not live( self.rift ) then return end
    for _, scout in pairs( findCraft( 1, "fscout" ) ) do
        if not self.scoutsThrough[ scout ]
            and distanceSquared( scout.position, self.rift.position ) <= 600 * 600 then
            self.scoutsThrough[ scout ] = true
            self.scoutCount = self.scoutCount + 1
            Media:playSound( "a2_borg09_scouts_through.wav" )
        end
    end
    self:setObjective( 3, self.scoutCount >= 5 )
    if self.scoutCount >= 5 then self:startSuccess( ) end
end

function A2Borg09Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 7 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.rift ) then
        Cineractive:lookFrom( self.rift )
        Cineractive:setCameraOffset( Vector( -560, 260, -760 ) )
        Cineractive:lookAt( self.rift )
    end
    UI:addTitle( "FEDERATION SCOUTS DEPLOYED", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    Media:playSound( "a2_borg09_success1.wav" )
    self:schedule( "success_second", 7.0, "playSecondSuccess" )
    self:schedule( "success", 15.0, "finishSuccess" )
end

function A2Borg09Mission:playSecondSuccess( )
    if self.phase == "success" then Media:playSound( "a2_borg09_success2.wav" ) end
end

function A2Borg09Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg09Mission:startFailure( sound, title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "Mbor10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg09Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg09Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.starbase = findLabel( "objectFedStarbase" ) or self.starbase
    self.shipyard = findLabel( "objectFedShipyard" ) or self.shipyard
    self.rift = findLabel( "objectFluidicRift" ) or self.rift
    if not live( self.queen ) then self.queen = findCraft( 1, "bqueen" )[ 1 ] end
    if not live( self.enterprise ) then self.enterprise = findCraft( 1, "fente" )[ 1 ] end

    if self.criticalChecksEnabled then
        if not live( self.queen ) or self.queen.player.number ~= 1 then
            self:startFailure( "a2_borg08_queen_killed.wav", "THE BORG QUEEN HAS BEEN LOST" )
            return
        end
        if not live( self.enterprise ) or self.enterprise.player.number ~= 1 then
            self:startFailure( "a2_borg08_picard_killed.wav", "THE ENTERPRISE HAS BEEN LOST" )
            return
        end
        if not live( self.starbase ) or self.starbase.player.number ~= 1 then
            self:startFailure( "a2_borg09_station_destroyed.wav", "THE FEDERATION STARBASE HAS BEEN LOST" )
            return
        end
        if not live( self.shipyard ) or self.shipyard.player.number ~= 1 then
            self:startFailure( "a2_borg09_shipyard_destroyed.wav", "EVREN PRIME HAS BEEN LOST" )
            return
        end
    end

    if not self.dilithiumGathered and self.player.resources.dilithium >= 20000 then
        self.dilithiumGathered = true
        Media:playSound( "a2_borg09_dilithium_gathered.wav" )
    end
    if not self.metalGathered and self.player.resources.metal >= 20000 then
        self.metalGathered = true
        Media:playSound( "a2_borg09_metal_gathered.wav" )
    end
    self:setObjective( 1, self.dilithiumGathered )
    self:setObjective( 2, self.metalGathered )

    if self.stage == "resources" and self.dilithiumGathered and self.metalGathered then
        self:beginScoutStage( )
    elseif self.stage == "scouts" then
        self:updateScouts( )
    end
end

function A2Borg09Mission:cineractiveUpdate( ) end
function A2Borg09Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg09Mission( ) )
