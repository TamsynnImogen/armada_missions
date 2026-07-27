-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 5 CONVERSION
-- Behaviour evidence: a2_fed05S.dsl, a2_fed05R.drl, a2_fed05.bzn.

class 'A2Federation05Mission'

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

local PORTAL_POSITION = Vector( 7100, -75, 13200 )
local FED_BASE_POSITION = Vector( 4330.7734, 0, 2114.5105 )
local WEST_ENTRY = Vector( 300, 0, 6500 )
local EAST_ENTRY = Vector( 13700, 0, 6200 )

function A2Federation05Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.gateFound = false
    self.ending = false
    self.ended = false
end

function A2Federation05Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f05_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation05Mission:setup( )
    print( "[IntoTheBreach] clean-room a2_fed05 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 4 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    Objectives:load( "a2_fed05_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation05Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 4500, 300, 1500 ) )
    Cineractive:lookAt( FED_BASE_POSITION )
    UI:addTitle( "INTO THE BREACH", 50, 50, 8.0, true )
    UI:addSubtitle( "Regula Badlands", 50, 85, 7.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "voice", 2.0, "playIntro" )
    self:schedule( "done", 24.0, "finishOpening" )
end

function A2Federation05Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed05_intro.wav" ) end
end

function A2Federation05Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed05_A.txt" )
    Objectives.visible = true
    self.portal = nearest( PORTAL_POSITION, findCraft( "bportal.odf", nil ) )
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ]
    self.base = nearest( FED_BASE_POSITION, findCraft( "fbase.odf", 1 ) )
    self.borg:loadAIP( "a2_fed05_main.aip" )
    self:schedule( "enterprise_attack", 180.0, "attackEnterprise" )
    self:schedule( "base_attack", 600.0, "baseAttack" )
    self:schedule( "second_attack", 1200.0, "secondBaseAttack" )
    self:schedule( "east_attack", 1600.0, "eastAttack" )
    self:schedule( "west_attack", 2000.0, "westAttack" )
    self:schedule( "east_attack_two", 2400.0, "eastAttackTwo" )
    self:schedule( "cash", 1200.0, "giveBorgCash" )
    print( "[IntoTheBreach] gameplay started" )
end

function A2Federation05Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation05Mission:target( position )
    local answer = nearest( position, findCraft( "fbase.odf", 1 ) )
    if answer == nil then answer = nearest( position, findCraft( nil, 1 ) ) end
    return answer
end

function A2Federation05Mission:spawnAttack( position, odfs, preferred )
    local target = live( preferred ) and preferred or self:target( position )
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 4, position + Vector( index * 90, 0, index * 70 ) )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation05Mission:attackEnterprise( )
    if self.phase == "gameplay" then
        self:spawnAttack( EAST_ENTRY, {
            "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bcruise2.odf"
        }, self.enterprise )
    end
end

function A2Federation05Mission:baseAttack( )
    if self.phase == "gameplay" then
        self:spawnAttack( WEST_ENTRY, {
            "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bassault.odf"
        }, self.base )
    end
end

function A2Federation05Mission:secondBaseAttack( )
    if self.phase == "gameplay" then
        self:spawnAttack( EAST_ENTRY, {
            "bbattle1.odf", "bcruise2.odf", "bcruise2.odf", "bassault.odf"
        }, self.enterprise )
    end
end

function A2Federation05Mission:eastAttack( )
    if self.phase == "gameplay" then
        self:spawnAttack( EAST_ENTRY, {
            "bcruise1.odf", "bcruise2.odf", "bspecial.odf", "bassault.odf", "bassault.odf"
        }, nil )
    end
end

function A2Federation05Mission:westAttack( )
    if self.phase == "gameplay" then
        self:spawnAttack( WEST_ENTRY, {
            "bbattle1.odf", "bcruise2.odf", "bassault.odf", "bassault.odf", "bspecial.odf"
        }, self.enterprise )
    end
end

function A2Federation05Mission:eastAttackTwo( )
    if self.phase == "gameplay" then
        self:spawnAttack( EAST_ENTRY, {
            "bbattle1.odf", "bcruise2.odf", "bcruise2.odf", "bspecial.odf", "bassault.odf"
        }, self.enterprise )
    end
end

function A2Federation05Mission:giveBorgCash( )
    if self.phase ~= "gameplay" then return end
    self.borg.resources.dilithium = self.borg.resources.dilithium + 2000
    self.borg.resources.metal = self.borg.resources.metal + 2000
    self:schedule( "cash", 1200.0, "giveBorgCash" )
end

function A2Federation05Mission:gateDiscovered( )
    if self.gateFound then return end
    self.gateFound = true
    self:complete( 1 )
    Media:playMovie( "a2_fed05_gate.bik" )
    self:schedule( "mama_warning", 10.0, "mamaWarning" )
    print( "[IntoTheBreach] transwarp portal located" )
end

function A2Federation05Mission:mamaWarning( )
    if self.phase ~= "gameplay" or self.ending then return end
    Media:playMovie( "a2_fed05_here_comes_mama.bik" )
    self:schedule( "mama", 15.0, "finalAttack" )
end

function A2Federation05Mission:finalAttack( )
    if self.phase ~= "gameplay" or self.ending then return end
    local mama = Entity.add( "bbattle3.odf", 4, PORTAL_POSITION + Vector( 0, 0, 700 ) )
    local target = live( self.enterprise ) and self.enterprise or self:target( PORTAL_POSITION )
    if live( target ) then safeOrder( mama, GameObject.Order.Attack, target ) end
    print( "[IntoTheBreach] final Borg defender released" )
end

function A2Federation05Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 2 )
    self:complete( 3 )
    self:complete( 4 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.portal ) then
        Cineractive:lookFrom( self.portal )
        Cineractive:setCameraOffset( Vector( -650, 300, -650 ) )
        Cineractive:lookAt( self.portal )
    end
    UI:addTitle( "TRANSWARP PORTAL SECURED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed05_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Federation05Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation05Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation05Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation05Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ] or self.enterprise
    if not live( self.enterprise ) or ( self.enterprise.crew ~= nil and self.enterprise.crew <= 0 ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED", "a2_fed05_failure.wav" ); return
    end
    if not live( self.portal ) then
        self:startFailure( "THE TRANSWARP PORTAL HAS BEEN DESTROYED", "a2_fed05_gate_gone.wav" ); return
    end
    if not self.gateFound and nearest( PORTAL_POSITION, findCraft( nil, 1 ), 1800 ) ~= nil then
        self:gateDiscovered( )
    end
    if self.portal.player.number == 1 then self:startSuccess( ) end
end

function A2Federation05Mission:cineractiveUpdate( ) end

function A2Federation05Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation05Mission( ) )
