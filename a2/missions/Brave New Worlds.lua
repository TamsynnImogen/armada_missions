-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 3 CONVERSION
-- Behaviour evidence: a2_kling03S.dsl, a2_kling03R.drl, a2_kling03.bzn.

class 'A2Kling03Mission'

local function valid( entity ) return entity ~= nil and entity.valid end

local function live( entity )
    return valid( entity ) and ( entity.crew == nil or entity.crew > 0 )
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
        print( "[BraveNewWorlds] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local PLANET_LABELS = {
    "pb_clssm1", "pb_clssh2", "pb_clssk3", "pb_clssl4"
}

local PATROL_ONE = { "cbattle2115", "cbattle113" }
local PATROL_TWO = { "cbattle2114", "cbattle112" }
local SCOUTS = { "cscout122", "cscout123", "cscout124" }
local CINEMATIC_REMOVE = { "kblowup", "rchase1", "rchase2" }

function A2Kling03Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.starbaseBuilt = false
    self.shipyardBuilt = false
    self.colonyShipBuilt = false
    self.cardassiansEliminated = false
    self.planetsColonized = false
end

function A2Kling03Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k03_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling03Mission:setup( )
    print( "[BraveNewWorlds] clean-room a2_kling03 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 4 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    Objectives:load( "a2_kling03_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling03Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    local lead = findLabel( "kcruise1130" )
    if live( lead ) then
        Cineractive:lookFrom( lead )
        Cineractive:setCameraOffset( Vector( -400, 180, -540 ) )
        Cineractive:lookAt( lead )
    end
    UI:addTitle( "BRAVE NEW WORLDS", 50, 50, 8.0, true )
    UI:addSubtitle( "Efate System", 50, 85, 8.0, true )
    Media:playMusic( "mkli30.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling03Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling03_intro.wav" ) end
end

function A2Kling03Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    for _, label in ipairs( CINEMATIC_REMOVE ) do
        local entity = findLabel( label )
        if valid( entity ) then Entity.remove( entity ) end
    end

    self.phase = "gameplay"
    self.planets = { }
    for _, label in ipairs( PLANET_LABELS ) do
        self.planets[ #self.planets + 1 ] = findLabel( label )
    end
    Objectives:load( "a2_kling03_main.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling03_build_list.aip" )

    -- Exact recovered DRL setup: colony order immediately, patrols after ten
    -- seconds, Cardassian scouts after three minutes.
    safeOrder( findLabel( "ccolony0" ), GameObject.Order.Colonize,
        findLabel( "pb_clssm1" ) )
    self:schedule( "patrols", 10.0, "beginPatrols" )
    self:schedule( "scouts", 180.0, "beginScouting" )
    self:schedule( "kamikaze", 600.0, "kamikazeCheck" )
    print( "[BraveNewWorlds] gameplay started" )
end

function A2Kling03Mission:beginPatrols( )
    for _, label in ipairs( PATROL_ONE ) do
        safeOrder( findLabel( label ), GameObject.Order.Move,
            Vector( 11200, 0, 9000 ) )
    end
    for _, label in ipairs( PATROL_TWO ) do
        safeOrder( findLabel( label ), GameObject.Order.Move,
            Vector( 9800, 0, 10800 ) )
    end
end

function A2Kling03Mission:beginScouting( )
    for _, label in ipairs( SCOUTS ) do
        safeOrder( findLabel( label ), GameObject.Order.Scout, nil )
    end
end

function A2Kling03Mission:kamikazeCheck( )
    if self.phase ~= "gameplay" then return end
    for _, ship in pairs( findCraft( nil, 4 ) ) do
        if live( ship ) then safeOrder( ship, GameObject.Order.SearchAndDestroy, nil ) end
    end
end

function A2Kling03Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling03Mission:checkBuildObjectives( )
    if not self.starbaseBuilt and #findCraft( "kbase.odf", 1 ) > 0 then
        self.starbaseBuilt = true
        self:complete( 1 )
    end
    if not self.shipyardBuilt and #findCraft( "kyard.odf", 1 ) > 0 then
        self.shipyardBuilt = true
        self:complete( 2 )
    end
    if not self.colonyShipBuilt and #findCraft( "kcolony.odf", 1 ) > 0 then
        self.colonyShipBuilt = true
        self:complete( 3 )
    end
end

function A2Kling03Mission:allPlanetsBelongToPlayer( )
    for index, planet in ipairs( self.planets ) do
        if not valid( planet ) then
            planet = findLabel( PLANET_LABELS[ index ] )
            self.planets[ index ] = planet
        end
        if not valid( planet ) or planet.player.number ~= 1 then return false end
    end
    return true
end

function A2Kling03Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 5 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    local planet = self.planets[ 1 ]
    if valid( planet ) then
        Cineractive:lookFrom( planet )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( planet )
    end
    UI:addTitle( "EFATE SYSTEM SECURED", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling03_sec.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling03Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling03Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE KLINGON FORCE HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling03Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling03Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if #findCraft( nil, 1 ) == 0 then
        self:startFailure( )
        return
    end

    self:checkBuildObjectives( )
    if not self.cardassiansEliminated and #findCraft( nil, 4 ) == 0 then
        self.cardassiansEliminated = true
        self:complete( 4 )
    end
    if not self.planetsColonized and self:allPlanetsBelongToPlayer( ) then
        self.planetsColonized = true
        self:complete( 5 )
    end

    if self.starbaseBuilt and self.shipyardBuilt and self.colonyShipBuilt
        and self.cardassiansEliminated and self.planetsColonized then
        self:startSuccess( )
    end
end

function A2Kling03Mission:cineractiveUpdate( ) end

function A2Kling03Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling03Mission( ) )
