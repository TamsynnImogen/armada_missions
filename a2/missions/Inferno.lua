-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 6 CONVERSION
-- Behaviour evidence: a2_fed06S.dsl, a2_fed06R.drl, a2_fed06.bzn.

class 'A2Federation06Mission'

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

local PORTAL_POSITION = Vector( 6600, -75, 5200 )
local FED_ENTRY = Vector( 6600, 0, 6000 )
local BORG_ENTRY = Vector( 11900, 0, 4100 )

function A2Federation06Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.portalCaptured = false
    self.borgDestroyed = false
    self.lastPortalOwner = nil
    self.portalSelfDestructArmed = false
    self.portalDestructGeneration = 0
end

function A2Federation06Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f06_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation06Mission:setup( )
    print( "[Inferno] clean-room a2_fed06 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    Objectives:load( "a2_fed06_primary.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation06Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 7800, 500, 6600 ) )
    Cineractive:lookAt( PORTAL_POSITION )
    UI:addTitle( "INFERNO", 50, 50, 8.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntro" )
    self:schedule( "intro_done", 25.0, "finishOpening" )
end

function A2Federation06Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed06_intro.wav" ) end
end

function A2Federation06Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed06_primary.txt" )
    Objectives.visible = true
    self.portal = nearest( PORTAL_POSITION, findCraft( "bportal.odf", nil ) )
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ]
    self.borg.resources.dilithium = 10000
    self.borg.resources.metal = 10000
    self.borg:loadAIP( "a2_modified_defensive.aip" )

    -- The stock rules randomise these arrivals. Fixed points retain their order
    -- and keep the clean-room mission deterministic under MMM.
    self:schedule( "fed_wave_one", 240.0, "fedWaveOne" )
    self:schedule( "fed_wave_two", 480.0, "fedWaveTwo" )
    self:schedule( "fed_wave_three", 720.0, "fedWaveThree" )
    self:schedule( "borg_wave_one", 360.0, "borgWaveOne" )
    self:schedule( "borg_wave_two", 660.0, "borgWaveTwo" )
    self:schedule( "borg_wave_three", 960.0, "borgWaveThree" )
    self:schedule( "borg_wave_four", 1260.0, "borgWaveFour" )
    print( "[Inferno] gameplay started" )
end

function A2Federation06Mission:complete( index, state )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = state == nil and true or state
    end
    Objectives.visible = true
end

function A2Federation06Mission:target( position )
    local answer = nearest( PORTAL_POSITION, findCraft( "fbase.odf", 1 ) )
    if answer == nil then answer = nearest( position, findCraft( nil, 1 ) ) end
    return answer
end

function A2Federation06Mission:spawnFleet( team, position, odfs, target )
    local result = { }
    for index, odf in ipairs( odfs ) do
        local offset = Vector( ( index % 4 ) * 110, 0, math.floor( index / 4 ) * 125 )
        local ship = Entity.add( odf, team, position + offset )
        result[ #result + 1 ] = ship
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
    return result
end

function A2Federation06Mission:fedWaveOne( )
    if self.phase ~= "gameplay" then return end
    self:spawnFleet( 1, FED_ENTRY, {
        "fbattle.odf", "fbattle.odf", "fgalaxy.odf", "fgalaxy.odf",
        "fgalaxy.odf", "fgalaxy.odf", "fcruise1.odf", "fcruise1.odf",
        "fcruise1.odf", "fcruise1.odf", "fassault.odf", "fassault.odf"
    }, nil )
    Media:playSound( "a2_fed06_assault_Ensign_1.wav" )
end

function A2Federation06Mission:fedWaveTwo( )
    if self.phase ~= "gameplay" then return end
    self:spawnFleet( 1, FED_ENTRY, {
        "fbattle.odf", "fbattle.odf", "fbattle.odf", "fbattle.odf",
        "fgalaxy.odf", "fgalaxy.odf", "fcruise1.odf", "fcruise1.odf",
        "fcruise2.odf", "fcruise2.odf", "fconst.odf", "fconst.odf"
    }, nil )
    Media:playSound( "a2_fed06_construction_Ensign_1.wav" )
end

function A2Federation06Mission:fedWaveThree( )
    if self.phase ~= "gameplay" then return end
    self:spawnFleet( 1, FED_ENTRY, {
        "fbattle.odf", "fgalaxy.odf", "fgalaxy.odf", "fcruise1.odf",
        "fcruise1.odf", "fdestroy.odf", "fdestroy.odf", "fconst.odf",
        "fconst.odf", "fassault.odf", "fdestroy.odf", "ffrigate.odf"
    }, nil )
    Media:playSound( "a2_fed06_frigate_Ensign_1.wav" )
end

function A2Federation06Mission:borgWave( odfs )
    if self.phase ~= "gameplay" then return end
    self:spawnFleet( 2, BORG_ENTRY, odfs, self:target( BORG_ENTRY ) )
end

function A2Federation06Mission:borgWaveOne( )
    self:borgWave( { "bbattle1.odf", "bbattle1.odf", "bbattle1.odf",
        "bbattle1.odf", "bcruise1.odf", "bcruise1.odf" } )
end

function A2Federation06Mission:borgWaveTwo( )
    self:borgWave( { "bbattle1.odf", "bbattle1.odf", "bbattle1.odf", "bbattle1.odf",
        "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bcruise2.odf",
        "bcruise2.odf", "bcruise2.odf" } )
end

function A2Federation06Mission:borgWaveThree( )
    self:borgWave( { "bbattle1.odf", "bbattle1.odf", "bbattle1.odf", "bbattle1.odf",
        "bcruise1.odf", "bcruise1.odf", "bcruise3.odf", "bcruise3.odf",
        "bcruise3.odf", "bcruise3.odf", "bcruise3.odf", "bcruise3.odf" } )
end

function A2Federation06Mission:borgWaveFour( )
    self:borgWave( { "bbattle2.odf", "bbattle2.odf", "bbattle1.odf", "bbattle1.odf",
        "bbattle1.odf", "bcruise3.odf", "bcruise3.odf", "bcruise3.odf",
        "bcruise3.odf", "bcruise3.odf", "bcruise3.odf", "bcruise3.odf" } )
end

function A2Federation06Mission:portalOwnerChanged( owner )
    self.lastPortalOwner = owner
    if owner == 1 then
        self.portalCaptured = true
        self.portalSelfDestructArmed = false
        self.portalDestructGeneration = self.portalDestructGeneration + 1
        self:complete( 1, true )
        Media:playMovie( "a2_fed06_gate_captured_Ensign_1.bik" )
        self:schedule( "portal_picard", 9.0, "portalPicard" )
        print( "[Inferno] transwarp portal captured" )
    elseif owner == 2 and self.portalCaptured then
        self.portalCaptured = false
        self:complete( 1, false )
        Media:playSound( "a2_fed06_gate_lost_Ensign_1.wav" )
        self:schedule( "portal_lost_two", 4.0, "portalLostTwo" )
        self.portalSelfDestructArmed = true
        self:armPortalSelfDestruct( )
        print( "[Inferno] Borg recaptured portal; self-destruct armed" )
    end
end

function A2Federation06Mission:armPortalSelfDestruct( )
    self.portalDestructGeneration = self.portalDestructGeneration + 1
    local generation = self.portalDestructGeneration
    local id = "a2f06_portal_self_destruct_" .. tostring( generation )
    local timer = Timer( id, 70.0, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended and generation == self.portalDestructGeneration then
            self:portalSelfDestruct( )
        end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation06Mission:portalPicard( )
    if self.phase == "gameplay" and live( self.portal ) and self.portal.player.number == 1 then
        Media:playMovie( "a2_fed06_gate_captured_pic_1.bik" )
    end
end

function A2Federation06Mission:portalLostTwo( )
    if self.phase == "gameplay" and live( self.portal ) and self.portal.player.number == 2 then
        Media:playSound( "a2_fed06_gate_lost_Computer_1.wav" )
        self:schedule( "portal_lost_three", 4.0, "portalLostThree" )
    end
end

function A2Federation06Mission:portalLostThree( )
    if self.phase == "gameplay" and live( self.portal ) and self.portal.player.number == 2 then
        Media:playSound( "a2_fed06_gate_lost_Pic_1.wav" )
    end
end

function A2Federation06Mission:portalSelfDestruct( )
    if self.phase == "gameplay" and self.portalSelfDestructArmed
        and live( self.portal ) and self.portal.player.number == 2 then
        self:startFailure( "THE BORG DESTROYED THE TRANSWARP PORTAL", "a2_fed10_gate_destroyed.wav" )
    end
end

function A2Federation06Mission:hasLivingBorg( )
    for _, entity in pairs( findCraft( nil, 2 ) ) do
        if live( entity ) and entity.odf ~= "bportal.odf" and entity.odf ~= "mwrmhole.odf" then
            return true
        end
    end
    return false
end

function A2Federation06Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 3, true )
    self:complete( 4, true )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.portal ) then
        Cineractive:lookFrom( self.portal )
        Cineractive:setCameraOffset( Vector( -800, 350, -800 ) )
        Cineractive:lookAt( self.portal )
    end
    UI:addTitle( "INFERNO EXTINGUISHED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed06_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Federation06Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation06Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation06Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation06Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ] or self.enterprise
    if not live( self.enterprise ) or ( self.enterprise.crew ~= nil and self.enterprise.crew <= 0 ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED", "a2_fed01_failure.wav" ); return
    end
    if not live( self.portal ) then
        self:startFailure( "THE TRANSWARP PORTAL HAS BEEN DESTROYED", "a2_fed10_gate_destroyed.wav" ); return
    end

    local owner = self.portal.player.number
    if owner ~= self.lastPortalOwner then self:portalOwnerChanged( owner ) end
    if not self.borgDestroyed and not self:hasLivingBorg( ) then
        self.borgDestroyed = true
        self:complete( 2, true )
        print( "[Inferno] Borg forces eliminated" )
    end
    if self.borgDestroyed and owner == 1 then self:startSuccess( ) end
end

function A2Federation06Mission:cineractiveUpdate( ) end

function A2Federation06Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation06Mission( ) )
