-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 2 CONVERSION
-- Behaviour evidence: a2_kling02S.dsl, a2_kling02R.drl, a2_kling02.bzn.

class 'A2Kling02Mission'

local function live( entity )
    return entity ~= nil and entity.valid
        and ( entity.crew == nil or entity.crew > 0 )
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
        print( "[Executioner] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local KLINGON_RESERVES = { "Kbattle_1", "Kbattle_2", "Kbattle_3" }

local CINEMATIC_REMOVE = {
    "Kdestroy_1", "Kdestroy_2", "Kdestroy_3", "Kdestroy_4", "Kdestroy_5",
    "Ccruise1_4", "Cbattle1_1", "Cbattle2_1", "Cfreight_1",
    "Cconst_1", "Cconst_2",
    "cineractive_ccruise1_1", "cineractive_ccruise1_2",
    "cineractive_ccruise1_3", "cineractive_ccruise1_4",
    "cineractive_kcruise1_1", "cineractive_kcruise1_2",
    "cineractive_kcruise1_3", "cineractive_kcruise1_4",
    "cineractive_kcruise1_5", "cineractive_kcruise1_6"
}

local MOBILE_CARDASSIAN_ODFS = {
    [ "cdestroy.odf" ] = true,
    [ "cfrigate.odf" ] = true,
    [ "cscout.odf" ] = true,
    [ "ccruise1.odf" ] = true,
    [ "ccruise2.odf" ] = true,
    [ "ccruise3.odf" ] = true,
    [ "cbattle.odf" ] = true,
    [ "cbattle2.odf" ] = true,
    [ "cassault.odf" ] = true
}

function A2Kling02Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.tradingBuilt = false
    self.gravityMinesResearched = false
    self.tachyonGridResearched = false
    self.cardassiansEliminated = false
end

function A2Kling02Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k02_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling02Mission:setup( )
    print( "[Executioner] clean-room a2_kling02 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.reservePlayer = Player( 8 )

    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.reservePlayer, Player.Relation.Ally )
    self.reservePlayer:setRelation( self.player, Player.Relation.Ally )
    self.cardassian:setRelation( self.reservePlayer, Player.Relation.Enemy )
    self.reservePlayer:setRelation( self.cardassian, Player.Relation.Enemy )

    self:isolateReserves( )
    Objectives:load( "a2_kling02_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling02Mission:isolateReserves( )
    for _, label in ipairs( KLINGON_RESERVES ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.reservePlayer
                ship.perceivedTeam = self.player
            end )
            if not ok then
                print( "[Executioner] could not isolate reserve " .. label
                    .. ": " .. tostring( message ) )
            end
        else
            print( "[Executioner] missing reserve " .. label )
        end
    end
end

function A2Kling02Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.bekta = findLabel( "Kbekta" )
    if live( self.bekta ) then
        Cineractive:lookFrom( self.bekta )
        Cineractive:setCameraOffset( Vector( -380, 170, -520 ) )
        Cineractive:lookAt( self.bekta )
    end
    UI:addTitle( "EXECUTIONER", 50, 50, 8.0, true )
    UI:addSubtitle( "Doltec System", 50, 85, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling02Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling02_intro.wav" ) end
end

function A2Kling02Mission:removeCinematicObjects( )
    for _, label in ipairs( CINEMATIC_REMOVE ) do
        local entity = findLabel( label )
        if live( entity ) then Entity.remove( entity ) end
    end
end

function A2Kling02Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self:removeCinematicObjects( )
    self.phase = "gameplay"
    self.bekta = findLabel( "Kbekta" ) or self.bekta
    self.base = findLabel( "Kbase_1" )
    self.kestian = findLabel( "Kestian" )
    Objectives:load( "a2_kling02_A.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling02_build_list.aip" )

    -- Exact recovered DRL mission timers. The original also contains dormant
    -- test values of 10/15/20/25 seconds; these are replaced by this schedule.
    self:schedule( "siege_one", 240.0, "siegeOne" )
    self:schedule( "siege_two", 480.0, "siegeTwo" )
    self:schedule( "siege_three", 720.0, "siegeThree" )
    self:schedule( "siege_four", 960.0, "siegeFour" )
    self:schedule( "reinforcements", 600.0, "releaseReinforcements" )
    self:schedule( "kamikaze", 600.0, "kamikazeCheck" )
    print( "[Executioner] gameplay started" )
end

function A2Kling02Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling02Mission:checkResearchObjectives( )
    if not self.tradingBuilt and #findCraft( "ktrading.odf", 1 ) > 0 then
        self.tradingBuilt = true
        self:complete( 1 )
        Media:playMovie( "a2_kling02_objective_2.bik" )
    end
    if not self.gravityMinesResearched and #findCraft( "klipod4.odf", 1 ) > 0 then
        self.gravityMinesResearched = true
        self:complete( 2 )
        Media:playMovie( "a2_kling02_generic_objective_1.bik" )
    end
    if not self.tachyonGridResearched and #findCraft( "klipod5.odf", 1 ) > 0 then
        self.tachyonGridResearched = true
        self:complete( 3 )
        Media:playMovie( "a2_kling02_generic_objective_1.bik" )
    end
end

function A2Kling02Mission:orderCardassianAttack( desired )
    if not live( self.base ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if live( ship ) and MOBILE_CARDASSIAN_ODFS[ string.lower( ship.odf or "" ) ] then
            safeOrder( ship, GameObject.Order.Attack, self.base )
            ordered = ordered + 1
            if ordered >= desired then break end
        end
    end
    print( "[Executioner] Cardassian siege group ordered ("
        .. tostring( ordered ) .. "/" .. tostring( desired ) .. ")" )
end

function A2Kling02Mission:siegeOne( ) self:orderCardassianAttack( 5 ) end
function A2Kling02Mission:siegeTwo( ) self:orderCardassianAttack( 5 ) end
function A2Kling02Mission:siegeThree( ) self:orderCardassianAttack( 5 ) end
function A2Kling02Mission:siegeFour( ) self:orderCardassianAttack( 3 ) end

function A2Kling02Mission:releaseReinforcements( )
    if self.phase ~= "gameplay" then return end
    local released = 0
    for _, label in ipairs( KLINGON_RESERVES ) do
        local ship = findLabel( label )
        if live( ship ) then
            local ok = pcall( function( )
                ship.player = self.player
                ship.perceivedTeam = self.player
                ship.forceOntoMap = true
            end )
            if ok then
                safeOrder( ship, GameObject.Order.Move, self.base )
                released = released + 1
            end
        end
    end
    UI:addSubtitle( "Three Klingon battleships have arrived as reinforcements.",
        50, 85, 8.0, true )
    print( "[Executioner] Klingon reinforcements released ("
        .. tostring( released ) .. "/3)" )
end

function A2Kling02Mission:kamikazeCheck( )
    if self.phase ~= "gameplay" then return end
    if #findCraft( nil, 2 ) > 0 then
        self:orderCardassianAttack( 1000 )
    end
end

function A2Kling02Mission:allCardassiansDestroyed( )
    if #findCraft( nil, 2 ) > 0 then return false end
    return not live( self.kestian ) or self.kestian.player.number ~= 2
end

function A2Kling02Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 6 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.kestian ) then
        Cineractive:lookFrom( self.kestian )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.kestian )
    end
    UI:addTitle( "CARDASSIAN REBELLION CRUSHED", 50, 50, 8.0, true )
    Media:playMusic( "mkli15a.wav" )
    Media:playSound( "a2_kling02_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling02Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling02Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli15a.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling02Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling02Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.bekta ) then
        self:startFailure( "CAPTAIN BEK'TA HAS BEEN LOST", "a2_kling02_failure_2.wav" )
        return
    end
    if not live( self.base ) then
        self:startFailure( "STARBASE EJYOWAW-10 HAS BEEN DESTROYED",
            "a2_kling02_failure.wav" )
        return
    end

    self:checkResearchObjectives( )
    if not self.cardassiansEliminated and self:allCardassiansDestroyed( ) then
        self.cardassiansEliminated = true
        self:complete( 4 )
    end

    if self.tradingBuilt and self.gravityMinesResearched
        and self.tachyonGridResearched and self.cardassiansEliminated then
        self:startSuccess( )
    end
end

function A2Kling02Mission:cineractiveUpdate( ) end

function A2Kling02Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling02Mission( ) )
