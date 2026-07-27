-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 10 CONVERSION
-- Behaviour evidence: a2_fed10S.dsl, a2_fed10R.drl, a2_fed10.bzn.

class 'A2Federation10Mission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
end

local function normalizedOdf( name )
    return string.gsub( string.lower( name or "" ), "%.odf$", "" )
end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function findCraft( odf, team )
    local wantedOdf = normalizedOdf( odf )
    local entities = EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( odf == nil or normalizedOdf( entity.odf ) == wantedOdf )
            and ( team == nil or entity.player.number == team )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( )
    return entities or { }
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

local function spawn( odf, player, position )
    local ok, entity = pcall( function( )
        return Entity.add( odf, player, position )
    end )
    if ok and not live( entity ) and player ~= nil then
        entity = nearest( position, findCraft( odf, player.number ), 500 )
    end
    if not ok or not live( entity ) then
        print( "[ThereAndBackAgain] failed to create " .. tostring( odf )
            .. ": " .. tostring( entity ) )
        return nil
    end
    return entity
end

local PORTAL_POSITION = Vector( 9000, -75, 3600 )
local ENTERPRISE_ENTRY = Vector( 500, 0, 9800 )
local FED_BASE_POSITION = Vector( 9600, -75, 4000 )
local FLEET_ENTRY = Vector( 500, 0, 9600 )
local BORG_ENTRIES = {
    Vector( 4400, 0, 12600 ), Vector( 300, 0, 9600 ),
    Vector( 300, 0, 4300 ), Vector( 500, 0, 300 )
}

function A2Federation10Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.incomingFleets = { }
    self.escortedFleets = 0
    self.caddebostan = nil
    self.caddebostanActive = false
end

function A2Federation10Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f10_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation10Mission:setup( )
    print( "[ThereAndBackAgain] clean-room a2_fed10 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.incoming = Player( 3 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.incoming, Player.Relation.Ally )
    self.incoming:setRelation( self.player, Player.Relation.Ally )
    self.incoming:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.incoming, Player.Relation.Enemy )
    Objectives:load( "a2_fed10_primary.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation10Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 5.0 )
    Cineractive:lookFrom( Vector( 8200, 400, 4800 ) )
    Cineractive:lookAt( PORTAL_POSITION )
    UI:addTitle( "THERE AND BACK AGAIN", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    self:schedule( "intro_voice", 7.0, "playIntro" )
    self:schedule( "intro_done", 52.0, "finishOpening" )
end

function A2Federation10Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed10_intro.wav" ) end
end

function A2Federation10Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed10_primary.txt" )
    Objectives.visible = true
    self.portal = nearest( PORTAL_POSITION, findCraft( "bportal.odf", nil ) )
    self.enterprise = nearest( ENTERPRISE_ENTRY, findCraft( "fente.odf", 1 ) )
    if self.enterprise == nil then
        self.enterprise = spawn( "fente.odf", self.player, ENTERPRISE_ENTRY )
    end
    self:ensureStartingFleet( )
    self.borg.resources.dilithium = 10000
    self.borg.resources.metal = 10000
    self.borg.resources.latinum = 10000
    self.borg:loadAIP( "a2_modified_defensive.aip" )

    self:schedule( "fed_wave_one", 90.0, "fedWaveOne" )
    self:schedule( "fed_wave_two", 180.0, "fedWaveTwo" )
    self:schedule( "fed_wave_three", 270.0, "fedWaveThree" )
    self:schedule( "fed_wave_four", 360.0, "fedWaveFour" )
    self:schedule( "fed_wave_five", 450.0, "fedWaveFive" )
    self:schedule( "fed_wave_six", 540.0, "fedWaveSix" )
    self:schedule( "fed_wave_seven", 630.0, "fedWaveSeven" )
    self:schedule( "fed_wave_eight", 720.0, "fedWaveEight" )
    self:schedule( "fed_wave_nine", 810.0, "fedWaveNine" )
    self:schedule( "caddebostan", 900.0, "fedWaveCaddebostan" )

    self:schedule( "borg_one", 135.0, "borgAttackOne" )
    self:schedule( "borg_two", 235.0, "borgAttackTwo" )
    self:schedule( "borg_three", 335.0, "borgAttackThree" )
    self:schedule( "borg_four", 435.0, "borgAttackFour" )
    self:schedule( "borg_five", 535.0, "borgAttackFive" )
    self:schedule( "borg_six", 635.0, "borgAttackSix" )
    self:schedule( "borg_seven", 735.0, "borgAttackSeven" )
    self:schedule( "borg_eight", 835.0, "borgAttackEight" )
    print( "[ThereAndBackAgain] gameplay started" )
end

function A2Federation10Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation10Mission:ensureStartingFleet( )
    local nearBase = findCraft( nil, 1 )
    if #nearBase < 8 then
        local odfs = { "fscout.odf", "fscout.odf", "fscout.odf", "fscout.odf",
            "fgalaxy.odf", "fbattle.odf", "fcruise1.odf", "fgalaxy.odf", "fbattle.odf" }
        for index, odf in ipairs( odfs ) do
            spawn( odf, self.player, FED_BASE_POSITION
                + Vector( ( index % 4 ) * 110, 0, math.floor( index / 4 ) * 110 ) )
        end
    end
end

function A2Federation10Mission:addIncomingFleet( odfs, movie, sound )
    if self.phase ~= "gameplay" then return end
    if movie ~= nil then Media:playMovie( movie ) elseif sound ~= nil then Media:playSound( sound ) end
    local fleet = { }
    for index, odf in ipairs( odfs ) do
        local ship = spawn( odf, self.incoming, FLEET_ENTRY
            + Vector( ( index % 4 ) * 100, 0, math.floor( index / 4 ) * 100 ) )
        if live( ship ) then
            fleet[ #fleet + 1 ] = ship
            if live( self.portal ) then safeOrder( ship, GameObject.Order.Go, self.portal ) end
        end
    end
    self.incomingFleets[ #self.incomingFleets + 1 ] = fleet
end

function A2Federation10Mission:fedWaveOne( )
    self:addIncomingFleet( { "fgalaxy.odf", "fcruise1.odf", "fdestroy.odf", "ffrigate.odf" }, "a2_fed10_wave1.bik", nil )
end

function A2Federation10Mission:fedWaveTwo( )
    self:addIncomingFleet( { "fbattle.odf", "fcruise2.odf", "fdestroy.odf", "fscout.odf" }, "a2_fed10_wave2.bik", nil )
end

function A2Federation10Mission:fedWaveThree( )
    self:addIncomingFleet( { "fgalaxy.odf", "fcruise1.odf", "fcruise1.odf", "fassault.odf" }, "a2_fed10_flee1.bik", nil )
end

function A2Federation10Mission:fedWaveFour( )
    self:addIncomingFleet( { "fbattle.odf", "fcruise2.odf", "ffrigate.odf", "fdestroy.odf" }, "a2_fed10_wave1.bik", nil )
end

function A2Federation10Mission:fedWaveFive( )
    self:addIncomingFleet( { "fgalaxy.odf", "fcruise1.odf", "fdestroy.odf", "fscout.odf" }, nil, "a2_fed10_flee2.wav" )
end

function A2Federation10Mission:fedWaveSix( )
    self:addIncomingFleet( { "fbattle.odf", "fcruise2.odf", "fcruise2.odf", "fassault.odf" }, "a2_fed10_wave2.bik", nil )
end

function A2Federation10Mission:fedWaveSeven( )
    self:addIncomingFleet( { "fgalaxy.odf", "fcruise1.odf", "ffrigate.odf", "fdestroy.odf" }, nil, "a2_fed10_flee3.wav" )
end

function A2Federation10Mission:fedWaveEight( )
    self:addIncomingFleet( { "fbattle.odf", "fcruise2.odf", "fcruise1.odf", "fscout.odf" }, "a2_fed10_flee1.bik", nil )
end

function A2Federation10Mission:fedWaveNine( )
    self:addIncomingFleet( { "fgalaxy.odf", "fcruise1.odf", "fcruise2.odf", "fassault.odf" }, nil, "a2_fed10_flee3.wav" )
end

function A2Federation10Mission:fedWaveCaddebostan( )
    if self.phase ~= "gameplay" then return end
    Objectives:load( "a2_fed10_modified.txt" )
    Objectives.visible = true
    Media:playSound( "a2_fed10_final_wave.wav" )
    self.caddebostan = spawn( "fcaddebostan.odf", self.incoming, FLEET_ENTRY )
    self.caddebostanActive = live( self.caddebostan )
    if self.caddebostanActive and live( self.portal ) then
        safeOrder( self.caddebostan, GameObject.Order.Go, self.portal )
    end
    self:schedule( "cad_borg", 18.0, "caddebostanAttack" )
    print( "[ThereAndBackAgain] USS Caddebostan entered the system" )
end

function A2Federation10Mission:borgAttack( entry, odfs, target )
    if self.phase ~= "gameplay" then return end
    target = live( target ) and target or self.portal
    for index, odf in ipairs( odfs ) do
        local ship = spawn( odf, self.borg, entry
            + Vector( ( index % 4 ) * 100, 0, math.floor( index / 4 ) * 110 ) )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation10Mission:borgAttackOne( )
    self:borgAttack( BORG_ENTRIES[ 1 ], { "bbattle1.odf", "bbattle1.odf", "bbattle1.odf",
        "bbattle1.odf", "bcruise1.odf", "bcruise1.odf" }, self.portal )
end

function A2Federation10Mission:borgAttackTwo( )
    self:borgAttack( BORG_ENTRIES[ 2 ], { "bbattle1.odf", "bbattle1.odf", "bbattle1.odf",
        "bcruise1.odf", "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bcruise2.odf" }, self.portal )
end

function A2Federation10Mission:borgAttackThree( )
    self:borgAttack( BORG_ENTRIES[ 3 ], { "bbattle1.odf", "bcruise2.odf", "bbattle1.odf",
        "bcruise2.odf", "bcruise1.odf", "bcruise1.odf", "bcruise2.odf" }, self.portal )
end


function A2Federation10Mission:borgAttackFour( )
    self:borgAttack( BORG_ENTRIES[ 4 ], { "bcruise2.odf", "bcruise2.odf", "bcruise2.odf",
        "bbattle1.odf", "bbattle1.odf", "bcruise3.odf", "bcruise3.odf" }, self.portal )
end

function A2Federation10Mission:borgAttackFive( ) self:borgAttackFour( ) end
function A2Federation10Mission:borgAttackSix( ) self:borgAttackThree( ) end

function A2Federation10Mission:borgAttackSeven( )
    self:borgAttack( BORG_ENTRIES[ 1 ], { "bcruise2.odf", "bcruise2.odf", "bcruise2.odf",
        "bbattle2.odf", "bbattle2.odf", "bcruise3.odf", "bcruise3.odf" }, self.portal )
end

function A2Federation10Mission:borgAttackEight( ) self:borgAttackSeven( ) end

function A2Federation10Mission:caddebostanAttack( )
    if self.caddebostanActive then
        self:borgAttack( BORG_ENTRIES[ 2 ], { "bcruise2.odf", "bcruise2.odf",
            "bcruise3.odf", "bbattle1.odf" }, self.caddebostan )
    end
end

function A2Federation10Mission:retireArrivedFleets( )
    if not live( self.portal ) then return end
    for _, fleet in pairs( self.incomingFleets ) do
        local arrived = false
        for _, ship in pairs( fleet ) do
            if live( ship ) and distanceSquared( ship.position, self.portal.position ) <= 500 * 500 then arrived = true end
        end
        if arrived and not fleet.retired then
            fleet.retired = true
            self.escortedFleets = self.escortedFleets + 1
            for _, ship in pairs( fleet ) do if live( ship ) then Entity.remove( ship ) end end
            print( "[ThereAndBackAgain] incoming fleet reached portal" )
        end
    end
end

function A2Federation10Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 1 )
    self:complete( 2 )
    self:complete( 3 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.portal ) then
        Cineractive:lookFrom( self.portal )
        Cineractive:setCameraOffset( Vector( -700, 320, -700 ) )
        Cineractive:lookAt( self.portal )
    end
    UI:addTitle( "THE FLEET IS HOME", 50, 50, 8.0, true )
    Media:playSound( "a2_fed10_success1.wav" )
    self:schedule( "success_two", 6.0, "successTwo" )
    self:schedule( "success_done", 18.0, "finishSuccess" )
end

function A2Federation10Mission:successTwo( )
    if self.phase == "success" then Media:playSound( "a2_fed10_success2_Ensign_1.wav" ) end
end

function A2Federation10Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation10Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation10Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation10Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ] or self.enterprise
    if not live( self.enterprise ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED", "a2_fed01_failure.wav" ); return
    end
    if not live( self.portal ) then
        self:startFailure( "THE TRANSWARP PORTAL HAS BEEN DESTROYED", "a2_fed10_gate_destroyed.wav" ); return
    end
    if self.caddebostanActive and not live( self.caddebostan ) then
        self:startFailure( "THE CADDEBOSTAN HAS BEEN DESTROYED", "a2_fed10_ship_destroyed.wav" ); return
    end

    self:retireArrivedFleets( )
    if self.caddebostanActive
        and distanceSquared( self.caddebostan.position, self.portal.position ) <= 500 * 500 then
        self.caddebostanActive = false
        Entity.remove( self.caddebostan )
        self:startSuccess( )
    end
end

function A2Federation10Mission:cineractiveUpdate( ) end

function A2Federation10Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation10Mission( ) )
