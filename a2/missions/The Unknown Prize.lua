-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 5 CONVERSION
-- Behaviour evidence: a2_kling05S.dsl, a2_kling05R.drl, a2_kling05.bzn.

class 'A2Kling05Mission'

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

local function safeOrder( entity, order, target )
    if not live( entity ) then return end
    local ok, message
    if target == nil then
        ok, message = pcall( function( ) entity:giveOrder( order ) end )
    else
        ok, message = pcall( function( ) entity:giveOrder( order, target ) end )
    end
    if not ok then
        print( "[UnknownPrize] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local SCRIPTED_CARDASSIANS = {
    "Quantum", "Quantum_escort_4", "Quantum_escort_5",
    "Quantum_split_2", "Quantum_split_3", "Quantum_split_5", "Quantum_split_6",
    "worm1_orbit1", "worm1_orbit2", "worm1_scout1", "worm1_scout2",
    "worm2_guard1", "random3", "random4", "random5", "random6",
    "sad_1", "sad_2", "sad_3", "cscout5", "cscout6"
}

local ROAMERS = {
    "random3", "random4", "random5", "random6", "sad_1", "sad_2", "sad_3"
}

local QUANTUM_GUARDS = {
    "Quantum_escort_4", "Quantum_escort_5", "Quantum_split_2",
    "Quantum_split_3", "Quantum_split_5", "Quantum_split_6"
}

local MOBILE_CARDASSIAN_ODFS = {
    [ "cdestroy.odf" ] = true, [ "cfrigate.odf" ] = true,
    [ "cscout.odf" ] = true, [ "ccruise1.odf" ] = true,
    [ "ccruise2.odf" ] = true, [ "ccruise3.odf" ] = true,
    [ "cbattle.odf" ] = true, [ "cbattle2.odf" ] = true,
    [ "cassault.odf" ] = true
}

local QUANTUM_ESCAPE = Vector( 7000, 0, 10500 )

function A2Kling05Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.wormDiscovered = false
    self.quantumCaptured = false
    self.quantumRunning = false
end

function A2Kling05Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k05_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling05Mission:setup( )
    print( "[UnknownPrize] clean-room a2_kling05 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.scriptedCardassian = Player( 8 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedCardassian, Player.Relation.Enemy )
    self.scriptedCardassian:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedCardassian, Player.Relation.Ally )
    self.scriptedCardassian:setRelation( self.cardassian, Player.Relation.Ally )
    self:isolateScriptedCardassians( )
    Objectives:load( "a2_kling05_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling05Mission:isolateScriptedCardassians( )
    for _, label in ipairs( SCRIPTED_CARDASSIANS ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedCardassian
                ship.perceivedTeam = self.cardassian
            end )
            if not ok then
                print( "[UnknownPrize] could not isolate " .. label
                    .. ": " .. tostring( message ) )
            end
        end
    end
end

function A2Kling05Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.base = findLabel( "Klingbase" )
    if valid( self.base ) then
        Cineractive:lookFrom( self.base )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.base )
    end
    UI:addTitle( "THE UNKNOWN PRIZE", 50, 50, 8.0, true )
    UI:addSubtitle( "Ket'sch Tor Belt", 50, 85, 8.0, true )
    Media:playMusic( "mkli30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling05Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling05_intro.wav" ) end
end

function A2Kling05Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self.phase = "gameplay"
    self.base = findLabel( "Klingbase" ) or self.base
    self.quantum = findLabel( "Quantum" )
    self.worm = findLabel( "worm_one" )
    self.martok = findLabel( "Martok's Negh'Var" )
        or findLabel( "kbattle21451" )
    Objectives:load( "a2_kling05_A.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling05_build.aip" )

    for _, label in ipairs( SCRIPTED_CARDASSIANS ) do
        local ship = findLabel( label )
        if live( ship ) then pcall( function( ) ship.forceOntoMap = true end ) end
    end
    for _, label in ipairs( ROAMERS ) do
        safeOrder( findLabel( label ), GameObject.Order.SearchAndDestroy, nil )
    end
    for _, label in ipairs( QUANTUM_GUARDS ) do
        safeOrder( findLabel( label ), GameObject.Order.Move,
            Vector( 5000, 0, 7250 ) )
    end
    safeOrder( findLabel( "worm1_orbit1" ), GameObject.Order.Move,
        Vector( 1600, 0, 9600 ) )
    safeOrder( findLabel( "worm1_orbit2" ), GameObject.Order.Move,
        Vector( 2350, 0, 9000 ) )
    print( "[UnknownPrize] gameplay started" )
end

function A2Kling05Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling05Mission:playerNearWormhole( )
    if not valid( self.worm ) then return false end
    for _, ship in pairs( findCraft( nil, 1 ) ) do
        if live( ship ) and distanceSquared( ship.position,
            self.worm.position ) <= 2250000 then return true end
    end
    return false
end

function A2Kling05Mission:discoverWormhole( )
    if self.wormDiscovered then return end
    self.wormDiscovered = true
    self:complete( 1 )
    Media:playMovie( "a2_kling05_worm_one.bik" )
    self:schedule( "base_attack_one", 280.0, "baseAttackOne" )
    self:schedule( "base_attack_two", 480.0, "baseAttackTwo" )
    self:schedule( "base_attack_three", 850.0, "baseAttackThree" )
    print( "[UnknownPrize] first wormhole discovered" )
end

function A2Kling05Mission:orderCardassiansAt( target, desired )
    if not live( target ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if live( ship ) and MOBILE_CARDASSIAN_ODFS[ string.lower( ship.odf or "" ) ] then
            safeOrder( ship, GameObject.Order.Attack, target )
            ordered = ordered + 1
            if ordered >= desired then break end
        end
    end
    print( "[UnknownPrize] Cardassian attack ordered ("
        .. tostring( ordered ) .. "/" .. tostring( desired ) .. ")" )
end

function A2Kling05Mission:baseAttackOne( ) self:orderCardassiansAt( self.base, 3 ) end
function A2Kling05Mission:baseAttackTwo( ) self:orderCardassiansAt( self.base, 4 ) end
function A2Kling05Mission:baseAttackThree( ) self:orderCardassiansAt( self.base, 4 ) end

function A2Kling05Mission:quantumRun( )
    if self.quantumCaptured or self.quantumRunning or not live( self.quantum ) then return end
    self.quantumRunning = true
    safeOrder( self.quantum, GameObject.Order.Move, QUANTUM_ESCAPE )
    self:schedule( "quantum_reset", 12.0, "resetQuantum" )
end

function A2Kling05Mission:resetQuantum( )
    self.quantumRunning = false
end

function A2Kling05Mission:quantumCapturedByPlayer( )
    if not valid( self.quantum ) or self.quantum.player.number ~= 1 then return end
    self.quantumCaptured = true
    pcall( function( )
        self.quantum.invincible = false
        self.quantum.player = self.player
        self.quantum.perceivedTeam = self.player
    end )
    self:complete( 2 )
    Media:playSound( "a2_kling05_captured.wav" )
    self:schedule( "quantum_hunt_one", 25.0, "quantumHunt" )
    self:schedule( "quantum_hunt_two", 65.0, "quantumHunt" )
    print( "[UnknownPrize] Quantum Singularity Ship captured" )
end

function A2Kling05Mission:quantumHunt( )
    self:orderCardassiansAt( self.quantum, 4 )
end

function A2Kling05Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 5 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if valid( self.quantum ) then
        Cineractive:lookFrom( self.quantum )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.quantum )
    end
    UI:addTitle( "THE PRIZE IS OURS", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling05_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Kling05Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling05Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling05Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling05Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not valid( self.quantum ) then
        self:startFailure( "THE QUANTUM SINGULARITY SHIP HAS BEEN DESTROYED",
            "a2_kling05_destroyed.wav" )
        return
    end
    if not live( self.base ) then
        self:startFailure( "STARBASE MISLYV'EE-27 HAS BEEN DESTROYED",
            "a2_kling05_destroyed.wav" )
        return
    end
    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( "CHANCELLOR MARTOK HAS BEEN LOST",
            "a2_kling01_defeat.wav" )
        return
    end

    if not self.wormDiscovered and self:playerNearWormhole( ) then
        self:discoverWormhole( )
    end
    if not self.quantumCaptured and self.quantum.player.number == 1 then
        self:quantumCapturedByPlayer( )
    elseif not self.quantumCaptured and self.quantum.underAttack then
        self:quantumRun( )
    end

    if self.quantumCaptured and distanceSquared( self.quantum.position,
        self.base.position ) < 250000 then
        self:complete( 3 )
        self:startSuccess( )
    end
end

function A2Kling05Mission:cineractiveUpdate( ) end

function A2Kling05Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling05Mission( ) )
