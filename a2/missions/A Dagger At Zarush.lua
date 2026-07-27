-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 1 CONVERSION
-- Behaviour evidence: a2_kling01S.dsl, a2_kling01R.drl, a2_kling01.bzn.

class 'A2Kling01Mission'

local function live( entity ) return entity ~= nil and entity.valid end

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
        print( "[DaggerAtZarush] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local FEDERATION_BASE = Vector( 2300, 0, 2200 )
local CARDASSIAN_BASE = Vector( 6000, 0, 6800 )

local BASE_ATTACK_ONE = {
    "BASE0 ccruise11307", "BASE0 cdestroy1315", "BASE0 cscout1323"
}

local BASE_ATTACK_TWO = {
    "BASE1 cbattle1302", "BASE1 cbattle21305", "BASE1 ccruise21310",
    "BASE1 cdestroy1316", "BASE1 cfrigate1319", "BASE1 cscout1324"
}

local ZARUSH_ATTACK_ONE = {
    "ZARUSH1 cbattle1303", "ZARUSH1 ccruise11308",
    "ZARUSH1 cdestroy1314", "ZARUSH1 cdestroy1317",
    "ZarushBat2", "ZarushBat1", "ZARUSH1 cassault1322"
}

local ZARUSH_ATTACK_TWO = {
    "ZARUSH2 csrepair1301", "ZARUSH2 cbattle1304",
    "ZARUSH2 cbattle21306", "ZARUSH2 ccruise11309",
    "ZARUSH2 ccruise21311", "ZARUSH2 ccruise21312",
    "ZARUSH2 cdestroy1313", "ZARUSH2 cfrigate1318",
    "ZARUSH2 cfrigate1320", "ZARUSH2"
}

local CARDASSIAN_SPECIAL_FORCES = {
    "ZarushBat2", "ZarushBat1",
    "cbase1278", "cmining1279", "cmining1280", "cyard1281",
    "cyard1282", "cyard21283", "csensor1284", "csensor1285",
    "csensor1286", "ctrading1291",
    "ZARUSH2 ccolony1293", "ZARUSH1 ccolony1294",
    "ZARUSH2 csrepair1301", "BASE1 cbattle1302",
    "ZARUSH1 cbattle1303", "ZARUSH2 cbattle1304",
    "BASE1 cbattle21305", "ZARUSH2 cbattle21306",
    "BASE0 ccruise11307", "ZARUSH1 ccruise11308",
    "ZARUSH2 ccruise11309", "BASE1 ccruise21310",
    "ZARUSH2 ccruise21311", "ZARUSH2 ccruise21312",
    "ZARUSH2 cdestroy1313", "ZARUSH1 cdestroy1314",
    "BASE0 cdestroy1315", "BASE1 cdestroy1316",
    "ZARUSH1 cdestroy1317", "ZARUSH2 cfrigate1318",
    "BASE1 cfrigate1319", "ZARUSH2 cfrigate1320", "ZARUSH2",
    "ZARUSH1 cassault1322", "BASE0 cscout1323",
    "BASE1 cscout1324", "ZARUSH2 cassault1328"
}

local CINEMATIC_CARDASSIANS = {
    "DAWN cbattle1047", "DAWN cbattle1048", "DAWN cbattle1049",
    "DAWN cbattle1050", "DAWN cbattle1051", "DAWN cbattle21052",
    "DAWN cbattle21053", "DAWN cbattle21054", "DAWN cbattle21055",
    "DAWN cbattle21056", "DAWN ccruise11057", "DAWN ccruise11058",
    "DAWN ccruise11059", "DAWN ccruise21060", "DAWN ccruise21061",
    "DAWN ccruise21062", "DAWN cdestroy1063", "DAWN cdestroy1064"
}

local CINEMATIC_REMOVE = {
    "DAWN ccruise11057", "DAWN cbattle21055", "DAWN ccruise21060",
    "DAWN ccruise11058", "DAWN cdestroy1063", "DAWN ccruise21062",
    "fdestroy1006", "fdestroy1007", "fdestroy1015",
    "DAWN cbattle21056", "DAWN cbattle1047", "DAWN cbattle21054",
    "DAWN ccruise11059", "DAWN ccruise21061", "DAWN cdestroy1064",
    "fcruise11010", "fcruise11011", "fcruise21012", "fcruise21013",
    "fcruise21014", "NEWCRUISE", "DAWN cbattle1048",
    "DAWN cbattle1049", "DAWN cbattle1050", "DAWN cbattle21052",
    "Arizona", "Oklahoma", "DAWN cbattle21053", "DAWN cbattle1051",
    "escaping nebula", "fyard1019", "fyard21020", "fyard1021",
    "fsuperbl1024", "fresear21027", "fupgrade1028", "ffrigate1029",
    "fsrepair1080", "fconst1082", "ffreight1083", "ftrading1078",
    "fspecial1804", "Nevada", "fodder1", "fodder2"
}

local FEDERATION_SURVIVORS = {
    "SURVIVOR Tennessee", "SURVIVOR fdestroy1008",
    "SURVIVOR fcruise11009", "SURVIVOR fbase1017",
    "SURVIVOR fyard1018", "SURVIVOR fmining1079"
}

function A2Kling01Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.specialForcesReleased = false
    self.survivorsRecovered = false
    self.timerSerial = 0
    self.timers = { }
end

function A2Kling01Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k01_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling01Mission:setup( )
    print( "[DaggerAtZarush] clean-room a2_kling01 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.scriptedCardassian = Player( 8 )

    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedCardassian, Player.Relation.Enemy )
    self.scriptedCardassian:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedCardassian, Player.Relation.Ally )
    self.scriptedCardassian:setRelation( self.cardassian, Player.Relation.Ally )

    self:isolateCardassianSpecialForces( CARDASSIAN_SPECIAL_FORCES )
    self:isolateCardassianSpecialForces( CINEMATIC_CARDASSIANS )
    Objectives:load( "a2_kling01_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling01Mission:isolateCardassianSpecialForces( labels )
    for _, label in ipairs( labels ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedCardassian
                ship.perceivedTeam = self.cardassian
            end )
            if not ok then
                print( "[DaggerAtZarush] could not isolate " .. label
                    .. ": " .. tostring( message ) )
            end
        else
            print( "[DaggerAtZarush] missing special force " .. label )
        end
    end
end

function A2Kling01Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.martok = findLabel( "martok" )
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -350, 160, -500 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "A DAGGER AT ZARUSH", 50, 50, 8.0, true )
    UI:addSubtitle( "Pearl Nebula", 50, 85, 8.0, true )
    Media:playMusic( "Mkli10.wav" )
    self:schedule( "intro_voice", 2.0, "playIntroVoice" )
    self:schedule( "opening_done", 20.0, "finishOpening" )
end

function A2Kling01Mission:playIntroVoice( )
    if self.phase == "opening" then
        Media:playSound( "a2_kling01_Martoks_Rant_1.wav" )
    end
end

function A2Kling01Mission:removeCinematicObjects( )
    for _, label in ipairs( CINEMATIC_REMOVE ) do
        local entity = findLabel( label )
        if live( entity ) then Entity.remove( entity ) end
    end
end

function A2Kling01Mission:prepareSurvivors( )
    for _, label in ipairs( FEDERATION_SURVIVORS ) do
        local survivor = findLabel( label )
        if live( survivor ) then
            pcall( function( ) survivor.invincible = false end )
            pcall( function( ) survivor.crew = 0 end )
        else
            print( "[DaggerAtZarush] missing Federation survivor " .. label )
        end
    end
end

function A2Kling01Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self:removeCinematicObjects( )
    self:prepareSurvivors( )
    self.phase = "gameplay"
    self.martok = findLabel( "martok" ) or self.martok
    self.zarush = findLabel( "Zarush" )
    self.vanoshan = findLabel( "Vanoshan" )
    Objectives:load( "a2_kling01_A.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling01_build_list.aip" )

    -- Exact recovered DRL mission timers.
    self:schedule( "base_attack_one", 120.0, "baseAttackOne" )
    self:schedule( "base_attack_two", 360.0, "baseAttackTwo" )
    self:schedule( "zarush_attack_one", 720.0, "zarushAttackOne" )
    self:schedule( "zarush_attack_two", 980.0, "zarushAttackTwo" )
    self:schedule( "scout", 30.0, "recruitScouts" )
    print( "[DaggerAtZarush] gameplay started" )
end

function A2Kling01Mission:orderGroup( labels, order, target )
    local ordered = 0
    for _, label in ipairs( labels ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, order, target )
            ordered = ordered + 1
        else
            print( "[DaggerAtZarush] missing attack-group ship " .. label )
        end
    end
    return ordered
end

function A2Kling01Mission:baseAttackOne( )
    if self.phase ~= "gameplay" then return end
    local count = self:orderGroup( BASE_ATTACK_ONE,
        GameObject.Order.SearchAndDestroy, FEDERATION_BASE )
    print( "[DaggerAtZarush] first base attack released ("
        .. tostring( count ) .. "/3)" )
end

function A2Kling01Mission:baseAttackTwo( )
    if self.phase ~= "gameplay" then return end
    local count = self:orderGroup( BASE_ATTACK_TWO,
        GameObject.Order.SearchAndDestroy, FEDERATION_BASE )
    print( "[DaggerAtZarush] second base attack released ("
        .. tostring( count ) .. "/6)" )
end

function A2Kling01Mission:zarushAttackOne( )
    if self.phase ~= "gameplay" or not live( self.zarush ) then return end
    local count = self:orderGroup( ZARUSH_ATTACK_ONE,
        GameObject.Order.Attack, self.zarush )
    safeOrder( findLabel( "ZARUSH1 ccolony1294" ),
        GameObject.Order.Colonize, self.zarush )
    print( "[DaggerAtZarush] first Zarush attack released ("
        .. tostring( count ) .. "/7)" )
end

function A2Kling01Mission:zarushAttackTwo( )
    if self.phase ~= "gameplay" or not live( self.zarush ) then return end
    local count = self:orderGroup( ZARUSH_ATTACK_TWO,
        GameObject.Order.Attack, self.zarush )
    safeOrder( findLabel( "ZARUSH2 ccolony1293" ),
        GameObject.Order.Colonize, self.zarush )
    print( "[DaggerAtZarush] second Zarush attack released ("
        .. tostring( count ) .. "/10)" )
end

function A2Kling01Mission:recruitScouts( )
    if self.phase ~= "gameplay" then return end
    for _, label in ipairs( { "cscout1325", "cscout1326", "cscout1327" } ) do
        safeOrder( findLabel( label ), GameObject.Order.Scout, nil )
    end
    self:schedule( "scout", 30.0, "recruitScouts" )
end

function A2Kling01Mission:playerNearCardassianBase( )
    for _, entity in pairs( findCraft( 1 ) ) do
        if live( entity )
            and distanceSquared( entity.position, CARDASSIAN_BASE ) < 6250000 then
            return true
        end
    end
    for _, label in ipairs( {
        "cbase1278", "cmining1279", "cmining1280", "cyard1281",
        "cyard1282", "cyard21283", "ctrading1291"
    } ) do
        local entity = findLabel( label )
        if live( entity ) and entity.underAttack then return true end
    end
    return false
end

function A2Kling01Mission:releaseCardassianSpecialForces( )
    if self.specialForcesReleased then return end
    self.specialForcesReleased = true
    local released = 0
    for _, label in ipairs( CARDASSIAN_SPECIAL_FORCES ) do
        local entity = findLabel( label )
        if live( entity ) then
            local ok = pcall( function( )
                entity.player = self.cardassian
                entity.perceivedTeam = self.cardassian
            end )
            if ok then released = released + 1 end
        end
    end
    print( "[DaggerAtZarush] Cardassian base special forces released ("
        .. tostring( released ) .. "/" .. tostring( #CARDASSIAN_SPECIAL_FORCES ) .. ")" )
end

function A2Kling01Mission:checkFederationSurvivors( )
    if self.survivorsRecovered then return end
    for _, label in ipairs( FEDERATION_SURVIVORS ) do
        local survivor = findLabel( label )
        if not live( survivor ) or survivor.crew == nil or survivor.crew <= 0 then return end
    end
    self.survivorsRecovered = true
    Media:playMovie( "a2_kling01_recovered_ships.bik" )
    print( "[DaggerAtZarush] all Federation survivors recovered" )
end

function A2Kling01Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling01Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 1 )
    self:complete( 2 )
    self:complete( 3 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.vanoshan ) then
        Cineractive:lookFrom( self.vanoshan )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.vanoshan )
    end
    UI:addTitle( "VANOSHAN CAPTURED", 50, 50, 8.0, true )
    Media:playMusic( "mkli15a.wav" )
    Media:playSound( "a2_kling01_victory.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Kling01Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling01Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli15a.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling01Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling01Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.martok )
        or ( self.martok.crew ~= nil and self.martok.crew <= 0 ) then
        self:startFailure( "MARTOK HAS BEEN LOST", "a2_kling01_defeat.wav" )
        return
    end

    if not live( self.zarush ) or self.zarush.player.number ~= 1 then
        self:startFailure( "ZARUSH HAS FALLEN", "a2_kling01_defeat2.wav" )
        return
    end

    if live( self.vanoshan ) and self.vanoshan.player.number == 1 then
        self:startSuccess( )
        return
    end

    if not self.specialForcesReleased and self:playerNearCardassianBase( ) then
        self:releaseCardassianSpecialForces( )
    end
    self:checkFederationSurvivors( )
end

function A2Kling01Mission:cineractiveUpdate( ) end

function A2Kling01Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling01Mission( ) )
