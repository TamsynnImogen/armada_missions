-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 6 CONVERSION
-- Behaviour evidence: a2_kling06S.dsl, a2_kling06R.drl, a2_kling06.bzn.

class 'A2Kling06Mission'

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
        if live( entity ) then
            local distance = distanceSquared( position, entity.position )
            if best == nil or distance < best then
                answer, best = entity, distance
            end
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
        print( "[RomulanConnection] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local KENTAR_FORCE = {
    "Sela", "kb_attack_1", "kb_attack_2", "kb_attack_3",
    "kb_attack_4", "kb_attack_5", "kb_attack_6"
}

local SCRIPTED_ROMULANS = {
    "Sela", "kb_attack_1", "kb_attack_2", "kb_attack_3",
    "kb_attack_4", "kb_attack_5", "kb_attack_6",
    "central_patrol_1", "central_patrol_2", "central_patrol_3",
    "central_patrol_4", "3_scout_1", "3_scout_2", "3_scout_3",
    "sad_1", "sad_2", "sad_3", "target"
}

local ROAMERS = { "sad_1", "sad_2", "sad_3", "target" }
local CENTRAL_PATROL = {
    "central_patrol_1", "central_patrol_2", "central_patrol_3", "central_patrol_4"
}
local OUTER_SCOUTS = { "3_scout_1", "3_scout_2", "3_scout_3" }

local MOBILE_ROMULAN_ODFS = {
    [ "rdestroy.odf" ] = true, [ "rfrigate.odf" ] = true,
    [ "rscout.odf" ] = true, [ "rcruise1.odf" ] = true,
    [ "rcruise2.odf" ] = true, [ "rcruise3.odf" ] = true,
    [ "rbattle.odf" ] = true, [ "rbattle2.odf" ] = true,
    [ "rassault.odf" ] = true
}

function A2Kling06Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.baseDestroyed = false
    self.planetsTaken = { false, false, false }
    self.kentarAttackScheduled = false
    self.kentarAttackStarted = false
    self.selaGone = false
end

function A2Kling06Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k06_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling06Mission:setup( )
    print( "[RomulanConnection] clean-room a2_kling06 conversion loaded" )
    self.player = Player( 1 )
    self.romulan = Player( 2 )
    self.scriptedRomulan = Player( 8 )
    self.player:setRelation( self.romulan, Player.Relation.Enemy )
    self.romulan:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedRomulan, Player.Relation.Enemy )
    self.scriptedRomulan:setRelation( self.player, Player.Relation.Enemy )
    self.romulan:setRelation( self.scriptedRomulan, Player.Relation.Ally )
    self.scriptedRomulan:setRelation( self.romulan, Player.Relation.Ally )
    self:isolateScriptedRomulans( )
    Objectives:load( "a2_kling06_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling06Mission:isolateScriptedRomulans( )
    for _, label in ipairs( SCRIPTED_ROMULANS ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedRomulan
                ship.perceivedTeam = self.romulan
            end )
            if not ok then
                print( "[RomulanConnection] could not isolate " .. label
                    .. ": " .. tostring( message ) )
            end
        end
    end
end

function A2Kling06Mission:startOpening( )
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
    UI:addTitle( "THE ROMULAN CONNECTION", 50, 50, 8.0, true )
    UI:addSubtitle( "Romulan Border", 50, 85, 8.0, true )
    Media:playMusic( "Mkli30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling06Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling06_intro.wav" ) end
end

function A2Kling06Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self.phase = "gameplay"
    self.base = findLabel( "Klingbase" ) or self.base
    self.romulanBase = findLabel( "Rombase" )
    self.planets = {
        findLabel( "Rom_planet_1" ),
        findLabel( "Rom_planet_2" ),
        findLabel( "Rom_planet_3" )
    }
    self.martok = findLabel( "Martok's Negh'Var" )
        or nearest( self.base.position, findCraft( "kbattle2.odf", 1 ) )
    self.sela = findLabel( "Sela" )
    Objectives:load( "a2_kling06_A.txt" )
    Objectives.visible = true
    self.romulan:loadAIP( "a2_kling06_build.aip" )

    for _, label in ipairs( SCRIPTED_ROMULANS ) do
        local ship = findLabel( label )
        if live( ship ) and label ~= "Sela" and string.sub( label, 1, 10 ) ~= "kb_attack_" then
            pcall( function( ) ship.forceOntoMap = true end )
        end
    end
    for _, label in ipairs( ROAMERS ) do
        safeOrder( findLabel( label ), GameObject.Order.SearchAndDestroy, nil )
    end
    for _, label in ipairs( CENTRAL_PATROL ) do
        safeOrder( findLabel( label ), GameObject.Order.Move, Vector( 6700, 0, 760 ) )
    end
    for _, label in ipairs( OUTER_SCOUTS ) do
        safeOrder( findLabel( label ), GameObject.Order.Scout, nil )
    end

    -- Exact recovered initial siege timing. Its follow-up attack occurs 740
    -- seconds after this one in the original script.
    self:schedule( "dilithium_siege", 560.0, "dilithiumSiege" )
    print( "[RomulanConnection] gameplay started" )
end

function A2Kling06Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling06Mission:orderRomulanAttack( target, desired )
    if not live( target ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if live( ship ) and MOBILE_ROMULAN_ODFS[ string.lower( ship.odf or "" ) ] then
            safeOrder( ship, GameObject.Order.Attack, target )
            ordered = ordered + 1
            if ordered >= desired then break end
        end
    end
    print( "[RomulanConnection] Romulan attack ordered ("
        .. tostring( ordered ) .. "/" .. tostring( desired ) .. ")" )
end

function A2Kling06Mission:dilithiumSiege( )
    local mining = findCraft( "kmining.odf", 1 )
    local target = nearest( Vector( 2528, -109, 9931 ), mining ) or self.base
    self:orderRomulanAttack( target, 6 )
    self:schedule( "base_attack", 740.0, "baseAttack" )
end

function A2Kling06Mission:baseAttack( )
    self:orderRomulanAttack( self.base, 8 )
end

function A2Kling06Mission:scheduleKentarAttack( )
    if self.kentarAttackScheduled then return end
    self.kentarAttackScheduled = true
    self:schedule( "kentar_warning", 140.0, "announceKentarAttack" )
end

function A2Kling06Mission:announceKentarAttack( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling06_attack.wav" )
    UI:addSubtitle( "A large Romulan attack force is approaching the Klingon base.",
        50, 85, 8.0, true )
    self:schedule( "kentar_attack", 5.0, "releaseKentarForce" )
end

function A2Kling06Mission:releaseKentarForce( )
    if self.kentarAttackStarted then return end
    self.kentarAttackStarted = true
    for _, label in ipairs( KENTAR_FORCE ) do
        local ship = findLabel( label )
        if live( ship ) then
            pcall( function( ) ship.forceOntoMap = true end )
            safeOrder( ship, GameObject.Order.Attack, self.base )
        end
    end
    if live( self.sela ) then pcall( function( ) self.sela.invincible = true end ) end
    self:orderRomulanAttack( self.base, 7 )
    self:schedule( "sela_escape", 25.0, "selaEscape" )
end

function A2Kling06Mission:selaEscape( )
    if self.selaGone then return end
    self.selaGone = true
    if valid( self.sela ) then
        Media:playMovie( "a2_kling06_cloak.bik" )
        Entity.remove( self.sela )
    end
end

function A2Kling06Mission:planetCaptured( index )
    self.planetsTaken[ index ] = true
    local objectiveIndex = ( index == 3 and 2 ) or ( index == 1 and 3 ) or 4
    local sound = ( index == 3 and "a2_kling05_generic_Martok_3.wav" )
        or ( index == 1 and "gvomar01.wav" )
        or "a2_kling05_generic_Martok_2.wav"
    self:complete( objectiveIndex )
    Media:playSound( sound )
    self:orderRomulanAttack( self.base, 8 )
    self:scheduleKentarAttack( )
    print( "[RomulanConnection] Romulan planet " .. tostring( index ) .. " captured" )
end

function A2Kling06Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 6 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if valid( self.romulanBase ) then
        Cineractive:lookFrom( self.romulanBase )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.romulanBase )
    end
    UI:addTitle( "THE ROMULAN BASE HAS FALLEN", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling06_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Kling06Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling06Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling06Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling06Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.base ) then
        self:startFailure( "THE KLINGON STARBASE HAS BEEN DESTROYED",
            "a2_kling06_fail.wav" )
        return
    end
    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( "CHANCELLOR MARTOK HAS BEEN LOST",
            "a2_kling01_defeat.wav" )
        return
    end

    if not self.baseDestroyed and not live( self.romulanBase ) then
        self.baseDestroyed = true
        self:complete( 1 )
        Media:playSound( "a2_kling05_generic_Martok.wav" )
    end
    for index, planet in ipairs( self.planets ) do
        if not self.planetsTaken[ index ] and valid( planet )
            and planet.player.number == 1 then
            self:planetCaptured( index )
        end
    end

    if self.baseDestroyed and self.planetsTaken[ 1 ]
        and self.planetsTaken[ 2 ] and self.planetsTaken[ 3 ] then
        self:startSuccess( )
    end
end

function A2Kling06Mission:cineractiveUpdate( ) end

function A2Kling06Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling06Mission( ) )
