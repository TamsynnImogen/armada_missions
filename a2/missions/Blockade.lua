-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 4 CONVERSION
-- Behaviour evidence: a2_kling04S.dsl, a2_kling04R.drl, a2_kling04.bzn.

class 'A2Kling04Mission'

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
        print( "[Blockade] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local PATROL_ONE = { "ccruise231", "ccruise232" }
local PATROL_TWO = { "cbattle225", "cbattle226" }
local PATROL_THREE = { "cbattle29", "cbattle30" }

local ESCORT_ONE = {
    "cdestroy33", "cdestroy35", "ccruise237", "Kul_1", "Kul_2",
    "cscout41", "rcruise260", "rcruise261"
}

local ESCORT_TWO = {
    "cdestroy34", "cdestroy36", "ccruise238", "cbattle40", "cscout42",
    "rcruise258", "rcruise259"
}

local CARGO_ONE = {
    "ccargo43", "ccargo44", "ccargo45", "ccargo46",
    "ccargo47", "ccargo48", "ccargo55"
}

local CARGO_TWO = {
    "ccargo49", "ccargo50", "ccargo51", "ccargo52",
    "ccargo53", "ccargo54", "ccargo56"
}

local CONVOY = {
    "cdestroy33", "cdestroy35", "ccruise237", "Kul_1", "Kul_2", "cscout41",
    "cdestroy34", "cdestroy36", "ccruise238", "cbattle40", "cscout42",
    "ccargo43", "ccargo44", "ccargo45", "ccargo46", "ccargo47", "ccargo48",
    "ccargo55", "ccargo49", "ccargo50", "ccargo51", "ccargo52", "ccargo53",
    "ccargo54", "ccargo56"
}

local ROMULAN_ESCORTS = {
    "rcruise258", "rcruise259", "rcruise260", "rcruise261"
}

local SCRIPTED_ENEMIES = {
    "cbattle225", "cbattle226", "cbattle29", "cbattle30",
    "ccruise231", "ccruise232", "ccolony1010",
    "cdestroy33", "cdestroy34", "cdestroy35", "cdestroy36",
    "ccruise237", "ccruise238", "Kul_1", "Kul_2", "cbattle40",
    "cscout41", "cscout42",
    "ccargo43", "ccargo44", "ccargo45", "ccargo46", "ccargo47", "ccargo48",
    "ccargo49", "ccargo50", "ccargo51", "ccargo52", "ccargo53", "ccargo54",
    "ccargo55", "ccargo56",
    "rcruise258", "rcruise259", "rcruise260", "rcruise261"
}

local CINEMATIC_REMOVE = { "rscout1018", "kdestroy1020", "kdestroy1019" }

local CARGO_DESTINATION_ONE = Vector( 714.6613, 0, 6747.453 )
local CARGO_DESTINATION_TWO = Vector( 733.669, 0, 6432.9063 )
local ESCORT_DESTINATION_ONE = Vector( 1548.4257, 130.07565, 7185.0156 )
local ESCORT_DESTINATION_TWO = Vector( 935.11383, -87.67857, 7242.125 )

function A2Kling04Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.planetFound = false
    self.tachyonResearched = false
    self.convoyStarted = false
    self.convoyDestroyed = false
    self.romulansReleased = false
end

function A2Kling04Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k04_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling04Mission:setup( )
    print( "[Blockade] clean-room a2_kling04 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 4 )
    self.scriptedEnemy = Player( 8 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedEnemy, Player.Relation.Enemy )
    self.scriptedEnemy:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedEnemy, Player.Relation.Ally )
    self.scriptedEnemy:setRelation( self.cardassian, Player.Relation.Ally )

    self:isolateScriptedEnemies( )
    Objectives:load( "a2_kling04_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling04Mission:isolateScriptedEnemies( )
    for _, label in ipairs( SCRIPTED_ENEMIES ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedEnemy
                ship.perceivedTeam = self.cardassian
            end )
            if not ok then
                print( "[Blockade] could not isolate " .. label
                    .. ": " .. tostring( message ) )
            end
        else
            print( "[Blockade] missing scripted enemy " .. label )
        end
    end
end

function A2Kling04Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    local lead = findLabel( "kcruise11007" )
    if live( lead ) then
        Cineractive:lookFrom( lead )
        Cineractive:setCameraOffset( Vector( -400, 180, -540 ) )
        Cineractive:lookAt( lead )
    end
    UI:addTitle( "BLOCKADE", 50, 50, 8.0, true )
    UI:addSubtitle( "Mornaur System", 50, 85, 8.0, true )
    Media:playMusic( "mkli30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling04Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling04_intro.wav" ) end
end

function A2Kling04Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    for _, label in ipairs( CINEMATIC_REMOVE ) do
        local entity = findLabel( label )
        if valid( entity ) then Entity.remove( entity ) end
    end

    self.phase = "gameplay"
    self.mornaur = findLabel( "pb_clssl1" )
    self.victoryPlanet = findLabel( "pb_clssd1012" )
    Objectives:load( "a2_kling04_main.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling04_build_list.aip" )

    local colony = findLabel( "ccolony1010" )
    if live( colony ) then
        colony.forceOntoMap = true
        safeOrder( colony, GameObject.Order.Colonize, self.mornaur )
    end

    -- Exact recovered DRL schedule.
    self:schedule( "patrols", 10.0, "beginPatrols" )
    self:schedule( "romulan_cloak", 15.0, "cloakRomulans" )
    self:schedule( "convoy_warning", 795.0, "announceConvoy" )
    self:schedule( "convoy_start", 800.0, "sendConvoy" )
    print( "[Blockade] gameplay started; convoy held until 800 seconds" )
end

function A2Kling04Mission:beginPatrols( )
    for _, label in ipairs( PATROL_ONE ) do
        local ship = findLabel( label )
        if live( ship ) then ship.forceOntoMap = true end
        safeOrder( ship, GameObject.Order.Move, Vector( 3300, 0, 7000 ) )
    end
    for _, label in ipairs( PATROL_TWO ) do
        local ship = findLabel( label )
        if live( ship ) then ship.forceOntoMap = true end
        safeOrder( ship, GameObject.Order.Move, Vector( 2100, 0, 7200 ) )
    end
    for _, label in ipairs( PATROL_THREE ) do
        local ship = findLabel( label )
        if live( ship ) then ship.forceOntoMap = true end
        safeOrder( ship, GameObject.Order.Move, Vector( 1800, 0, 5600 ) )
    end
end

function A2Kling04Mission:cloakRomulans( )
    for _, label in ipairs( ROMULAN_ESCORTS ) do
        local ship = findLabel( label )
        if live( ship ) then
            pcall( function( ) ship:immediateCloak( ) end )
        end
    end
end

function A2Kling04Mission:announceConvoy( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling04_convoy.wav" )
    UI:addSubtitle( "Long range sensors have detected a large fleet entering the sector.",
        50, 85, 8.0, true )
end

function A2Kling04Mission:sendGroup( labels, destination )
    local ordered = 0
    for _, label in ipairs( labels ) do
        local ship = findLabel( label )
        if live( ship ) then
            pcall( function( ) ship.forceOntoMap = true end )
            safeOrder( ship, GameObject.Order.Move, destination )
            ordered = ordered + 1
        end
    end
    return ordered
end

function A2Kling04Mission:sendConvoy( )
    if self.phase ~= "gameplay" then return end
    self.convoyStarted = true
    local ordered = 0
    ordered = ordered + self:sendGroup( ESCORT_ONE, ESCORT_DESTINATION_ONE )
    ordered = ordered + self:sendGroup( ESCORT_TWO, ESCORT_DESTINATION_TWO )
    ordered = ordered + self:sendGroup( CARGO_ONE, CARGO_DESTINATION_ONE )
    ordered = ordered + self:sendGroup( CARGO_TWO, CARGO_DESTINATION_TWO )
    print( "[Blockade] convoy released (" .. tostring( ordered ) .. "/29 ships)" )
end

function A2Kling04Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling04Mission:playerHasFoundMornaur( )
    if not valid( self.mornaur ) then return false end
    for _, ship in pairs( findCraft( nil, 1 ) ) do
        if live( ship )
            and distanceSquared( ship.position, self.mornaur.position ) <= 2250000 then
            return true
        end
    end
    return false
end

function A2Kling04Mission:anyConvoyShipUnderAttack( )
    for _, label in ipairs( CONVOY ) do
        local ship = findLabel( label )
        if live( ship ) and ship.underAttack then return true end
    end
    return false
end

function A2Kling04Mission:releaseRomulanEscorts( )
    if self.romulansReleased then return end
    self.romulansReleased = true
    for _, label in ipairs( ROMULAN_ESCORTS ) do
        local ship = findLabel( label )
        if live( ship ) then
            pcall( function( ) ship:decloak( ) end )
            safeOrder( ship, GameObject.Order.SearchAndDestroy, nil )
        end
    end
    print( "[Blockade] cloaked Romulan escorts revealed" )
end

function A2Kling04Mission:allConvoyShipsDestroyed( )
    for _, label in ipairs( CONVOY ) do
        if live( findLabel( label ) ) then return false end
    end
    return true
end

function A2Kling04Mission:cargoReachedMornaur( )
    if not self.convoyStarted or not valid( self.mornaur ) then return false end
    for _, labels in ipairs( { CARGO_ONE, CARGO_TWO } ) do
        for _, label in ipairs( labels ) do
            local cargo = findLabel( label )
            if live( cargo ) and distanceSquared( cargo.position,
                self.mornaur.position ) <= 640000 then
                return true
            end
        end
    end
    return false
end

function A2Kling04Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 4 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if valid( self.victoryPlanet ) then
        Cineractive:lookFrom( self.victoryPlanet )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.victoryPlanet )
    end
    UI:addTitle( "THE BLOCKADE HOLDS", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling05_generic_Martok.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling04Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling04Mission:startFailure( title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling06_fail.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling04Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling04Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if #findCraft( nil, 1 ) == 0 then
        self:startFailure( "THE KLINGON FLEET HAS BEEN DESTROYED" )
        return
    end
    if self:cargoReachedMornaur( ) then
        self:startFailure( "A CONVOY SHIP HAS REACHED MORNAUR II" )
        return
    end

    if not self.planetFound and self:playerHasFoundMornaur( ) then
        self.planetFound = true
        self:complete( 1 )
        Media:playSound( "a2_kling04_mornaur.wav" )
    end
    if not self.tachyonResearched and #findCraft( "klipod5.odf", 1 ) > 0 then
        self.tachyonResearched = true
        self:complete( 2 )
    end
    if self.convoyStarted and not self.convoyDestroyed
        and self:allConvoyShipsDestroyed( ) then
        self.convoyDestroyed = true
        self:complete( 4 )
    end
    if self.convoyStarted and not self.romulansReleased
        and self:anyConvoyShipUnderAttack( ) then
        self:releaseRomulanEscorts( )
    end

    if self.planetFound and self.tachyonResearched and self.convoyDestroyed then
        self:startSuccess( )
    end
end

function A2Kling04Mission:cineractiveUpdate( ) end

function A2Kling04Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling04Mission( ) )
