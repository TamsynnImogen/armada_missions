-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 7 CONVERSION
-- Behaviour evidence: a2_fed07S.dsl, a2_fed07R.drl, a2_fed07.bzn.

class 'A2Federation07Mission'

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

local ENTERPRISE_POSITION = Vector( 16943.8, 0, 2167.51 )
local ALLEGHENY_POSITION = Vector( 884.859, 0, 1190.61 )
local FED_BASE_POSITION = Vector( 11900, 0, 2200 )
local BORG_ENTRIES = {
    Vector( 19000, 0, 16400 ), Vector( 0, 0, 18800 ),
    Vector( 17000, 0, 19000 ), Vector( 3900, 0, 19000 )
}

function A2Federation07Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.repaired = false
    self.repairTimerArmed = false
    self.contactPlayed = false
end

function A2Federation07Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f07_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation07Mission:setup( )
    print( "[TheCavalry] clean-room a2_fed07 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.neutral = Player( 3 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.neutral, Player.Relation.Ally )
    self.neutral:setRelation( self.player, Player.Relation.Ally )
    Objectives:load( "a2_fed07_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation07Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 2600, 450, 1900 ) )
    Cineractive:lookAt( ALLEGHENY_POSITION )
    UI:addTitle( "THE CAVALRY", 50, 50, 8.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "distress_one", 2.0, "distressOne" )
    self:schedule( "distress_two", 10.0, "distressTwo" )
    self:schedule( "intro_done", 24.0, "finishOpening" )
end

function A2Federation07Mission:distressOne( )
    if self.phase == "opening" then Media:playSound( "a2_fed07_distress_Namura_1.wav" ) end
end

function A2Federation07Mission:distressTwo( )
    if self.phase == "opening" then Media:playSound( "a2_fed07_distress_3.wav" ) end
end

function A2Federation07Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed07_A.txt" )
    Objectives.visible = true
    self.enterprise = nearest( ENTERPRISE_POSITION, findCraft( "fente.odf", 1 ) )
    if self.enterprise == nil then self.enterprise = nearest( ENTERPRISE_POSITION, findCraft( "fgalaxy.odf", 1 ) ) end
    self.allegheny = nearest( ALLEGHENY_POSITION, findCraft( "fgalaxy.odf", nil ) )
    if live( self.allegheny ) and self.allegheny.player.number ~= 1 then
        pcall( function( ) self.allegheny.player = self.player end )
    end
    self.base = nearest( FED_BASE_POSITION, findCraft( "fbase.odf", 1 ), 1800 )
    if self.base == nil then self.base = Entity.add( "fbase.odf", 1, FED_BASE_POSITION ) end
    self.borg.resources.dilithium = 5000
    self.borg.resources.metal = 5000
    self.borg:loadAIP( "a2_fed07_build_list.aip" )
    self:schedule( "initial_attack", 180.0, "initialAttack" )
    self:schedule( "siege_one", 840.0, "siegeOne" )
    self:schedule( "siege_two", 960.0, "siegeTwo" )
    self:schedule( "siege_three", 1200.0, "siegeThree" )
    self:schedule( "allegheny_cube", 1320.0, "alleghenyCube" )
    self:schedule( "siege_four", 1440.0, "siegeFour" )
    self:schedule( "borg_cash", 60.0, "borgCash" )
    print( "[TheCavalry] gameplay started" )
end

function A2Federation07Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation07Mission:target( position )
    local answer = nearest( FED_BASE_POSITION, findCraft( "fbase.odf", 1 ) )
    if answer == nil then answer = nearest( position, findCraft( nil, 1 ) ) end
    return answer
end

function A2Federation07Mission:spawnAttack( position, odfs, target )
    target = live( target ) and target or self:target( position )
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 2, position + Vector( index * 95, 0, ( index % 3 ) * 90 ) )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation07Mission:initialAttack( )
    if self.phase ~= "gameplay" then return end
    self:spawnAttack( Vector( 12100, 0, 2200 ), {
        "bdestroy.odf", "bdestroy.odf", "bdestroy.odf", "bdestroy.odf"
    }, self.enterprise )
end

function A2Federation07Mission:siegeOne( )
    self:spawnAttack( BORG_ENTRIES[ 1 ], { "bdestroy.odf", "bcruise2.odf" }, nil )
end

function A2Federation07Mission:siegeTwo( )
    self:spawnAttack( BORG_ENTRIES[ 2 ], { "bcruise1.odf", "bcruise1.odf" }, nil )
end

function A2Federation07Mission:siegeThree( )
    self:spawnAttack( BORG_ENTRIES[ 3 ], { "bcruise1.odf", "bcruise1.odf" }, nil )
end

function A2Federation07Mission:siegeFour( )
    self:spawnAttack( BORG_ENTRIES[ 4 ], { "bcruise1.odf", "bcruise1.odf" }, nil )
end

function A2Federation07Mission:alleghenyCube( )
    if self.phase ~= "gameplay" or not live( self.allegheny ) then return end
    self:spawnAttack( Vector( 1200, 0, 8000 ), { "bbattle1.odf" }, self.allegheny )
end

function A2Federation07Mission:borgCash( )
    if self.phase ~= "gameplay" then return end
    self.borg.resources.dilithium = self.borg.resources.dilithium + 1000
    self.borg.resources.metal = self.borg.resources.metal + 1000
    self:schedule( "borg_cash", 60.0, "borgCash" )
end

function A2Federation07Mission:markRepaired( )
    if self.repaired then return end
    self.repaired = true
    Objectives:load( "a2_fed07_B.txt" )
    Objectives.visible = true
    self:complete( 1 )
    Media:playSound( "a2_fed07_allegheny_repaired.wav" )
    print( "[TheCavalry] USS Allegheny restored" )
end

function A2Federation07Mission:finishRepairCheck( )
    if self.phase ~= "gameplay" or self.repaired or not live( self.allegheny ) then return end
    local repairShip = nearest( self.allegheny.position, findCraft( "fsrepair.odf", 1 ), 500 )
    if live( repairShip ) then
        self:markRepaired( )
    else
        self.repairTimerArmed = false
    end
end

function A2Federation07Mission:hasLivingBorg( )
    for _, entity in pairs( findCraft( nil, 2 ) ) do
        if live( entity ) and entity.odf ~= "mwrmhole.odf" then return true end
    end
    return false
end

function A2Federation07Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 2 )
    self:complete( 3 )
    self:complete( 4 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( -500, 250, -500 ) )
        Cineractive:lookAt( self.enterprise )
    end
    Media:playSound( "a2_fed07_success.wav" )
    UI:addTitle( "SYSTEM J-356 SECURED", 50, 50, 8.0, true )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Federation07Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation07Mission:startFailure( title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( "a2_fed01_failure.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation07Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation07Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if not live( self.enterprise ) then self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED" ); return end
    if not live( self.allegheny ) then self:startFailure( "THE ALLEGHENY HAS BEEN DESTROYED" ); return end

    if not self.contactPlayed and nearest( self.allegheny.position, findCraft( nil, 1 ), 1000 ) ~= nil then
        self.contactPlayed = true
        Media:playMovie( "a2_fed01_meet_the_borg.bik" )
    end

    if not self.repaired then
        local repairShip = nearest( self.allegheny.position, findCraft( "fsrepair.odf", 1 ), 500 )
        if live( repairShip ) and not self.repairTimerArmed then
            self.repairTimerArmed = true
            self:schedule( "repair_check", 20.0, "finishRepairCheck" )
        end
        local shieldReady = self.allegheny.maxShields ~= nil and self.allegheny.maxShields > 0
            and self.allegheny.shields / self.allegheny.maxShields >= 0.9
        if live( repairShip ) and shieldReady then self:markRepaired( ) end
    elseif not self:hasLivingBorg( ) then
        self:startSuccess( )
    end
end

function A2Federation07Mission:cineractiveUpdate( ) end

function A2Federation07Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation07Mission( ) )
