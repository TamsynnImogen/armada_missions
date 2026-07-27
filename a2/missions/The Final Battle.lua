-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 10 CONVERSION
-- Behaviour evidence: a2_kling10S.dsl, a2_kling10R.drl, a2_kling10.bzn.

class 'A2Kling10Mission'

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

local function findCraft( team )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
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
        print( "[FinalBattle] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local function odfBase( entity )
    local name = string.lower( entity.odf or "" )
    return string.gsub( name, "%.odf$", "" )
end

local MOBILE_CARDASSIAN_ODFS = {
    cdestroy = true, cdestroy2 = true, cfrigate = true, cscout = true,
    ccruise = true, ccruise1 = true, ccruise2 = true, ccruise3 = true,
    cbattle = true, cbattle2 = true, cassault = true, cspecial = true,
    csuper = true
}

local CINEMATIC_REMOVE = {
    "cineractive_cbase_1", "cineractive_cassault_1",
    "cineractive_cbattle1_1", "cineractive_cbattle2_1",
    "cineractive_cbattle2_2", "cineractive_ccruise1_1",
    "cineractive_ccruise2_1", "cineractive_ccruise3_1",
    "cineractive_cfrigate_1", "cineractive_cspecial_1",
    "cineractive_kfrigate_1", "cineractive_kfrigate_2",
    "cineractive_kfrigate_3", "cineractive_cbattle1_2",
    "cineractive_cbattle1_3", "cineractive_cbattle2_3",
    "cineractive_cbattle2_4", "cineractive_cbattle2_5",
    "cineractive_cbattle2_7", "cineractive_cbattle2_8",
    "cineractive_ccruise3_2", "cineractive_cfrigate_2",
    "cineractive_cdestroy_1", "cineractive_cdestroy_2",
    "cineractive_kbattle1_1", "cineractive_kbattle1_2",
    "cineractive_kbattle1_4", "cineractive_kbattle1_5",
    "cineractive_kbattle2_1", "cineractive_kcruise1_1",
    "cineractive_kcruise1_2", "cineractive_cquantum"
}

local WAVE_ORIGINS = {
    Vector( 24, 0, 14105 ),
    Vector( 5292, 0, 19102 ),
    Vector( 19000, 0, 11500 ),
    Vector( 19098, 0, 10638 )
}

local KENTAR_ESCAPE = Vector( 18000, 0, 9000 )

function A2Kling10Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.kentarEngaged = false
    self.kentarEliminated = false
    self.facilityDestroyed = false
    self.martokWarningPlayed = false
end

function A2Kling10Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k10_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self, timerObject, hook ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling10Mission:setup( )
    print( "[FinalBattle] clean-room a2_kling10 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.species = Player( 3 )
    self.scriptedCardassian = Player( 8 )

    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedCardassian, Player.Relation.Enemy )
    self.scriptedCardassian:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedCardassian, Player.Relation.Ally )
    self.scriptedCardassian:setRelation( self.cardassian, Player.Relation.Ally )

    self.martok = findLabel( "martok" )
    self.kentar = findLabel( "kentar" )
    self.facility = findLabel( "cquantum" )
    self:isolateKentar( )

    Objectives:load( "a2_kling10_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling10Mission:isolateKentar( )
    if not live( self.kentar ) then return end
    safeOrder( self.kentar, GameObject.Order.Stop, nil )
    pcall( function( )
        self.kentar.forceOntoMap = false
        self.kentar.player = self.scriptedCardassian
        self.kentar.perceivedTeam = self.cardassian
    end )
end

function A2Kling10Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )

    local subject = findLabel( "cineractive_cquantum" ) or self.facility
    if live( subject ) then
        Cineractive:lookFrom( subject )
        Cineractive:setCameraOffset( Vector( -600, 260, -760 ) )
        Cineractive:lookAt( subject )
    end
    Media:playMusic( "mkli30.wav" )
    self:schedule( "second_shot", 15.0, "openingSecondShot" )
    self:schedule( "third_shot", 41.0, "openingThirdShot" )
    self:schedule( "fourth_shot", 63.0, "openingFourthShot" )
    self:schedule( "opening_done", 71.0, "finishOpening" )
end

function A2Kling10Mission:openingSecondShot( )
    if self.phase ~= "opening" then return end
    local subject = findLabel( "cineractive_cbattle2_3" ) or self.facility
    if live( subject ) then
        Cineractive:fadeIn( 1.0 )
        Cineractive:lookFrom( subject )
        Cineractive:setCameraOffset( Vector( -420, 170, -620 ) )
        Cineractive:lookAt( subject )
    end
end

function A2Kling10Mission:openingThirdShot( )
    if self.phase ~= "opening" then return end
    local subject = self.martok or findLabel( "cineractive_kbattle1_1" )
    if live( subject ) then
        Cineractive:fadeIn( 1.0 )
        Cineractive:lookFrom( subject )
        Cineractive:setCameraOffset( Vector( -460, 210, -680 ) )
        Cineractive:lookAt( subject )
    end
    UI:addSubtitle( "The Final Battle", 50, 85, 10.0, true )
end

function A2Kling10Mission:openingFourthShot( )
    if self.phase ~= "opening" then return end
    Cineractive:fadeIn( 1.0 )
    Media:playSound( "mkli15a.wav" )
    UI:addTitle( "THE FINAL BATTLE", 50, 50, 8.0, true )
    Media:playSound( "a2_kling10_intro.wav" )
end

function A2Kling10Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false

    for _, label in ipairs( CINEMATIC_REMOVE ) do
        local entity = findLabel( label )
        if valid( entity ) then Entity.remove( entity ) end
    end

    self.martok = findLabel( "martok" ) or self.martok
    self.kentar = findLabel( "kentar" ) or self.kentar
    self.facility = findLabel( "cquantum" ) or self.facility
    self:isolateKentar( )

    Objectives:load( "a2_kling10_main.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling10_build_list.aip" )
    self.phase = "gameplay"

    self:schedule( "martok_wave_1", 240.0, "martokWaveOne" )
    self:schedule( "martok_wave_2", 520.0, "martokWaveTwo" )
    self:schedule( "martok_wave_3", 820.0, "martokWaveThree" )
    self:schedule( "martok_wave_4", 950.0, "martokWaveFour" )
    self:schedule( "kulinor_1", 1800.0, "kulinorOne" )
    print( "[FinalBattle] gameplay started" )
end

function A2Kling10Mission:cardassianMobiles( origin )
    local ships = { }
    for _, entity in pairs( findCraft( 2 ) ) do
        if live( entity ) and MOBILE_CARDASSIAN_ODFS[ odfBase( entity ) ] then
            ships[ #ships + 1 ] = entity
        end
    end
    table.sort( ships, function( a, b )
        return distanceSquared( a.position, origin )
            < distanceSquared( b.position, origin )
    end )
    return ships
end

function A2Kling10Mission:orderCardassianAttack( wave, count )
    if self.phase ~= "gameplay" or not live( self.martok ) then return end
    local ordered = 0
    for _, ship in ipairs( self:cardassianMobiles( WAVE_ORIGINS[ wave ] ) ) do
        safeOrder( ship, GameObject.Order.Attack, self.martok )
        ordered = ordered + 1
        if ordered >= count then break end
    end
    print( "[FinalBattle] Martok wave " .. tostring( wave ) .. " ordered ("
        .. tostring( ordered ) .. "/" .. tostring( count ) .. ")" )
end

function A2Kling10Mission:martokWaveOne( ) self:orderCardassianAttack( 1, 2 ) end
function A2Kling10Mission:martokWaveTwo( ) self:orderCardassianAttack( 2, 3 ) end
function A2Kling10Mission:martokWaveThree( ) self:orderCardassianAttack( 3, 2 ) end
function A2Kling10Mission:martokWaveFour( ) self:orderCardassianAttack( 4, 8 ) end

function A2Kling10Mission:engageKentar( )
    if self.kentarEngaged or not live( self.kentar ) then return end
    self.kentarEngaged = true
    Media:playMovie( "a2_kling09_head_klingon_6.bik" )
    pcall( function( ) self.kentar.forceOntoMap = true end )
    safeOrder( self.kentar, GameObject.Order.Move, KENTAR_ESCAPE )

    local defenders = self:cardassianMobiles( self.kentar.position )
    for index = 1, math.min( 5, #defenders ) do
        safeOrder( defenders[ index ], GameObject.Order.Attack, self.martok )
    end
    print( "[FinalBattle] Gul Kentar escape and guard response triggered" )
end

function A2Kling10Mission:releaseLateAssault( stage )
    if self.phase ~= "gameplay" or not live( self.martok ) then return end
    local origin = WAVE_ORIGINS[ ( ( stage - 1 ) % #WAVE_ORIGINS ) + 1 ]
    local ordered = 0
    for _, ship in ipairs( self:cardassianMobiles( origin ) ) do
        safeOrder( ship, GameObject.Order.SearchAndDestroy, nil )
        ordered = ordered + 1
        if ordered >= 6 then break end
    end
    print( "[FinalBattle] late assault stage " .. tostring( stage )
        .. " released (" .. tostring( ordered ) .. "/6)" )
end

function A2Kling10Mission:kulinorOne( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling_detects_8472_01.wav" )
    self:releaseLateAssault( 1 )
    self:schedule( "species_1", 6.0, "speciesOne" )
    self:schedule( "kulinor_2", 600.0, "kulinorTwo" )
end

function A2Kling10Mission:speciesOne( )
    if self.phase == "gameplay" then
        self.cardassian:setRelation( self.species, Player.Relation.Enemy )
        self.species:setRelation( self.cardassian, Player.Relation.Enemy )
    end
end

function A2Kling10Mission:kulinorTwo( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling_detects_8472_02.wav" )
    self:releaseLateAssault( 2 )
    self:schedule( "species_2", 14.0, "speciesTwo" )
    self:schedule( "kulinor_3", 600.0, "kulinorThree" )
end

function A2Kling10Mission:speciesTwo( ) self:releaseLateAssault( 2 ) end

function A2Kling10Mission:kulinorThree( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling_detects_8472_02.wav" )
    self:releaseLateAssault( 3 )
    self:schedule( "species_3", 14.0, "speciesThree" )
    self:schedule( "kulinor_4", 600.0, "kulinorFour" )
end

function A2Kling10Mission:speciesThree( ) self:releaseLateAssault( 3 ) end

function A2Kling10Mission:kulinorFour( )
    if self.phase ~= "gameplay" then return end
    Media:playSound( "a2_kling_detects_8472_02.wav" )
    self:releaseLateAssault( 4 )
    self:schedule( "species_4", 15.0, "speciesFour" )
    self:schedule( "kulinor_5", 600.0, "kulinorFive" )
end

function A2Kling10Mission:speciesFour( ) self:releaseLateAssault( 4 ) end

function A2Kling10Mission:kulinorFive( )
    if self.phase == "gameplay" then self:releaseLateAssault( 5 ) end
end

function A2Kling10Mission:setObjectiveState( index, state )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = state
    end
    Objectives.visible = true
end

function A2Kling10Mission:markKentarEliminated( )
    if self.kentarEliminated then return end
    self.kentarEliminated = true
    self:setObjectiveState( 2, true )
    if self.facilityDestroyed then
        self:startSuccess( )
    else
        Media:playMovie( "a2_kling10_objective_2.bik" )
    end
end

function A2Kling10Mission:markFacilityDestroyed( )
    if self.facilityDestroyed then return end
    self.facilityDestroyed = true
    self:setObjectiveState( 1, true )
    if self.kentarEliminated then
        self:startSuccess( )
    else
        Media:playMovie( "a2_kling10_objective_1.bik" )
    end
end

function A2Kling10Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 3 do self:setObjectiveState( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    local subject = self.facility or self.kentar
    if valid( subject ) then
        Cineractive:lookFrom( subject )
        Cineractive:setCameraOffset( Vector( -520, 230, -720 ) )
        Cineractive:lookAt( subject )
    end
    UI:addTitle( "VICTORY", 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( "a2_kling10_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling10Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling10Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    if valid( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -400, 180, -620 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "CHANCELLOR MARTOK HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "mfed10.wav" )
    Media:playSound( "a2_kling10_failure.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling10Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling10Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( )
        return
    end

    if not self.martokWarningPlayed and self.martok.underAttack then
        self.martokWarningPlayed = true
        Media:playSound( "a2_kling10_failure.wav" )
    end

    if not self.kentarEngaged and live( self.kentar ) and self.kentar.underAttack then
        self:engageKentar( )
    end

    if not self.kentarEliminated then
        local eliminated = not live( self.kentar )
        if not eliminated and self.kentar.player.number ~= 2
            and self.kentar.player.number ~= 8 then eliminated = true end
        if eliminated then self:markKentarEliminated( ) end
    end

    if not self.facilityDestroyed and not live( self.facility ) then
        self:markFacilityDestroyed( )
    end
end

function A2Kling10Mission:cineractiveUpdate( ) end

function A2Kling10Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling10Mission( ) )
