-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 3 CONVERSION
-- Behaviour evidence: a2_fed03S.dsl, a2_fed03R.drl, a2_fed03.bzn.

class 'A2Federation03Mission'

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

local function findLabel( label )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft ) and entity.label == label
    end ):findOne( )
end

local function nearest( position, entities )
    local result, best = nil, 1000000000
    for _, entity in pairs( entities ) do
        if live( entity ) then
            local candidate = distanceSquared( position, entity.position )
            if candidate < best then result, best = entity, candidate end
        end
    end
    return result
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
        print( "[Recovery] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local BASE_POSITION = Vector( 4701.918, 96.14789, 6723.8584 )
local DOUGLASS_POSITION = Vector( 13434.3, -2.9034, 5082.2 )
local WAVE_DESTINATIONS = {
    path_4 = Vector( -696.11835, -11.279142, 8486.362 ),
    path_5 = Vector( -633.9581, 0, 8218.98 ),
    path_6 = Vector( -712.3268, 0, 9166.991 ),
    path_7 = Vector( -700.26324, 0, 9633.557 ),
    path_8 = Vector( -625.8863, 0, 10168.126 )
}
local WAVE_ONE = {
    { "bbattle10_waveone", "path_4" },
    { "bbattle116_waveone", "path_5" },
    { "bscout25_waveone", "path_6" },
    { "bcruise133_waveone", "path_7" },
    { "bfrigate0_waveone", "path_4" },
    { "bfrigate1_waveone", "path_5" },
    { "bscout26_waveone", "path_7" },
    { "bscout27_waveone", "path_4" },
    { "bscout28_waveone", "path_5" }
}

local WAVE_TWO = {
    { "bbattle118_wavetwo", "path_5" },
    { "bdestroy30_wavetwo", "path_6" },
    { "bdestroy31_wavetwo", "path_7" },
    { "bdestroy32_wavetwo", "path_8" },
    { "bcruise134_wavetwo", "path_4" },
    { "bfrigate2_wavetwo", "path_5" },
    { "bfrigate3_wavetwo", "path_6" },
    { "bdestroy29_wavetwo", "path_6" }
}

local WAVE_THREE = {
    { "bcruise135_wavethree", "path_5" },
    { "bcruise237_wavethree", "path_7" },
    { "bfreight40_wavethree", "path_8" },
    { "bfreight41_wavethree", "path_4" },
    { "bcolony42_wavethree", "path_5" },
    { "Douglass", "path_6" },
    { "bassault6_wavethree", "path_7" },
    { "bassault5_wavethree", "path_8" },
    { "bassault4_wavethree", "path_4" },
    { "bbattle120_wavethree", "path_6" },
    { "bbattle11004", "path_6" },
    { "wave_three_add_1", "path_5" },
    { "wave_three_add_2", "path_6" },
    { "wave_three_add_3", "path_5" },
    { "wave_three_add_4", "path_6" },
    { "wave_three_add_5", "path_5" }
}

local WAVE_THREE_FAST = {
    "bcruise135_wavethree", "bcolony42_wavethree", "Douglass",
    "bbattle11004", "wave_three_add_1", "wave_three_add_2",
    "wave_three_add_3", "wave_three_add_4", "wave_three_add_5"
}

-- The original ScriptInit marks these Borg craft as AI special forces.  That
-- keeps the Borg AIP from recruiting pre-placed mission waves before their
-- script orders are issued.  MMM does not expose SetSpecialForcesFlag, so an
-- allied, AIP-less holding player provides the same separation.
local BORG_SPECIAL_FORCES = {
    "t_attack_5", "t_attack_4", "t_attack_3", "t_attack_2", "t_attack_1",
    "s_attack_7", "s_attack_6", "s_attack_5", "s_attack_4", "s_attack_3",
    "s_attack_2", "s_attack_1",
    "wave_three_add_5", "wave_three_add_2", "wave_three_add_1",
    "wave_three_add_4", "wave_three_add_3",
    "bscout1013", "bscout1012", "bscout1011", "bscout1010",
    "bdestroy1009", "bdestroy1008", "bdestroy1007", "bdestroy1006",
    "sen_kill_3", "bbattle11004",
    "bcruise11003", "bcruise11002", "bcruise11001", "bcruise11000",
    "bassault7_wavetwo", "bassault6_wavethree", "bassault5_wavethree",
    "bassault4_wavethree",
    "bfrigate3_wavetwo", "bfrigate2_wavetwo", "bfrigate1_waveone",
    "bfrigate0_waveone", "bbattle13_basekiller", "bbattle10_waveone",
    "bbattle116_waveone", "bbattle117_wavetwo", "bbattle118_wavetwo",
    "sen_kill_2", "bbattle120_wavethree",
    "bscout25_waveone", "bscout26_waveone", "bscout27_waveone",
    "bscout28_waveone",
    "bdestroy29_wavetwo", "bdestroy30_wavetwo", "bdestroy31_wavetwo",
    "bdestroy32_wavetwo",
    "bcruise133_waveone", "bcruise134_wavetwo", "bcruise135_wavethree",
    "sen_kill_1", "bcruise237_wavethree", "bfreight40_wavethree",
    "bfreight41_wavethree", "bcolony42_wavethree", "sbasekiller"
}

function A2Federation03Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.baseSecured = false
    self.scienceBuilt = false
    self.thirdWaveScheduled = false
    self.douglassReleased = false
    self.waveThreeActive = false
    self.waveThreeReserve = nil
    self.timerSerial = 0
    self.timers = { }
end

function A2Federation03Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f03_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation03Mission:setup( )
    print( "[Recovery] clean-room a2_fed03 conversion loaded" )
    self.player = Player( 1 )
    self.douglassTeam = Player( 3 )
    self.borg = Player( 4 )
    self.scriptedBorg = Player( 8 )
    self.player:setRelation( self.douglassTeam, Player.Relation.Enemy )
    self.douglassTeam:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.douglassTeam:setRelation( self.borg, Player.Relation.Ally )
    self.borg:setRelation( self.douglassTeam, Player.Relation.Ally )
    self.player:setRelation( self.scriptedBorg, Player.Relation.Enemy )
    self.scriptedBorg:setRelation( self.player, Player.Relation.Enemy )
    self.borg:setRelation( self.scriptedBorg, Player.Relation.Ally )
    self.scriptedBorg:setRelation( self.borg, Player.Relation.Ally )
    self.douglassTeam:setRelation( self.scriptedBorg, Player.Relation.Ally )
    self.scriptedBorg:setRelation( self.douglassTeam, Player.Relation.Ally )
    self:isolateBorgSpecialForces( )
    self:isolateDouglass( )
    Objectives:load( "a2_fed03_main_objectives.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation03Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ]
    if live( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( -350, 150, -500 ) )
        Cineractive:lookAt( self.enterprise )
    else
        Cineractive:lookFrom( Vector( 2800, 300, 3600 ) )
        Cineractive:lookAt( Vector( 2800, 0, 4100 ) )
    end
    UI:addTitle( "RECOVERY", 50, 50, 7.0, true )
    UI:addSubtitle( "Starbase 176", 50, 85, 7.0, true )
    Media:playMusic( "Mfed30.wav" )
    self:schedule( "voice", 2.0, "playIntro" )
    self:schedule( "done", 20.0, "finishOpening" )
end

function A2Federation03Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed03_intro.wav" ) end
end

function A2Federation03Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed03_main_objectives.txt" )
    Objectives.visible = true
    self.base = findLabel( "fbase62" )
        or nearest( BASE_POSITION, findCraft( "fbase.odf", nil ) )
    self.douglass = findLabel( "Douglass" )
        or nearest( DOUGLASS_POSITION, findCraft( "fspecial.odf", nil ) )
    self.enterprise = findCraft( "fente.odf", 1 )[ 1 ]
    if not live( self.enterprise ) then
        self.enterprise = nearest( Vector( 2800, 0, 4000 ), findCraft( "fgalaxy.odf", 1 ) )
    end
    self:prepareWaveThreeReserve( )
    self.borg:loadAIP( "a2_fed03_build_list.aip" )
    self:startInitialAttacks( )
    self:schedule( "wave_one", 120.0, "waveOne" )
    self:schedule( "wave_two", 300.0, "waveTwo" )
    print( "[Recovery] gameplay started" )
end

function A2Federation03Mission:isolateBorgSpecialForces( )
    local isolated = 0
    for _, label in ipairs( BORG_SPECIAL_FORCES ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            local ok, message = pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedBorg
                ship.perceivedTeam = self.borg
            end )
            if ok and ship.player.number == self.scriptedBorg.number then
                isolated = isolated + 1
            else
                print( "[Recovery] could not isolate special force " .. label
                    .. ": " .. tostring( message ) )
            end
        else
            print( "[Recovery] missing Borg special force " .. label )
        end
    end
    print( "[Recovery] Borg special forces isolated from AIP ("
        .. tostring( isolated ) .. "/" .. tostring( #BORG_SPECIAL_FORCES ) .. ")" )
end

function A2Federation03Mission:isolateDouglass( )
    local douglass = findLabel( "Douglass" )
    if not live( douglass ) then
        print( "[Recovery] missing Douglass special force" )
        return
    end
    safeOrder( douglass, GameObject.Order.Stop, nil )
    local ok, message = pcall( function( )
        douglass.forceOntoMap = false
        douglass.player = self.scriptedBorg
        douglass.perceivedTeam = self.douglassTeam
        -- Recovered DRL: CraftCannotDie followed by ButItCanBeDerelicted.
        douglass.invincible = true
    end )
    if not ok or douglass.player.number ~= self.scriptedBorg.number then
        print( "[Recovery] could not isolate Douglass: " .. tostring( message ) )
        return
    end
    print( "[Recovery] Douglass isolated from team AI until wave three" )
end

function A2Federation03Mission:releaseWave( assignments, leaveDouglassOnMap )
    local released = 0
    for _, assignment in ipairs( assignments ) do
        local ship = findLabel( assignment[ 1 ] )
        if live( ship ) then
            local destination = WAVE_DESTINATIONS[ assignment[ 2 ] ]
            if destination ~= nil then
                safeOrder( ship, GameObject.Order.Go, destination )
            else
                print( "[Recovery] missing wave destination " .. assignment[ 2 ] )
            end
            if leaveDouglassOnMap or assignment[ 1 ] ~= "Douglass" then
                pcall( function( ) ship.forceOntoMap = false end )
            end
            released = released + 1
        else
            print( "[Recovery] missing pre-placed map object " .. assignment[ 1 ] )
        end
    end
    return released
end

function A2Federation03Mission:prepareWaveThreeReserve( )
    self.waveThreeReserve = { }
    local reserved = 0
    for _, assignment in ipairs( WAVE_THREE ) do
        local label = assignment[ 1 ]
        local ship = findLabel( label )
        if live( ship ) then
            self.waveThreeReserve[ label ] = {
                entity = ship,
                impulseSpeed = ship.impulseSpeed
            }
            safeOrder( ship, GameObject.Order.Stop, nil )
            -- These ships begin beyond x=12800.  They must be allowed to stay
            -- outside the map until their recovered DRL wave timer expires.
            pcall( function( ) ship.forceOntoMap = false end )
            pcall( function( ) ship.invincible = label == "Douglass" end )
            reserved = reserved + 1
        else
            print( "[Recovery] missing third-wave reserve at mission start: " .. label )
        end
    end
    print( "[Recovery] third-wave reserve secured (" .. tostring( reserved ) .. "/16)" )
end

function A2Federation03Mission:activateWaveThreeReserve( )
    self.waveThreeActive = true
    if self.waveThreeReserve == nil then return end
    for label, reserve in pairs( self.waveThreeReserve ) do
        local ship = reserve.entity
        if live( ship ) then
            pcall( function( ) ship.forceOntoMap = false end )
            pcall( function( ) ship.invincible = label == "Douglass" end )
            if reserve.impulseSpeed ~= nil then
                pcall( function( ) ship.impulseSpeed = reserve.impulseSpeed end )
            end
        end
    end
end

function A2Federation03Mission:startInitialAttacks( )
    safeOrder( findLabel( "sbasekiller" ), GameObject.Order.Attack,
        findLabel( "fresear0_target" ) )
    safeOrder( findLabel( "bbattle13_basekiller" ), GameObject.Order.Attack,
        self.base )
end

function A2Federation03Mission:starbaseAttackOne( )
    if self.phase ~= "gameplay" then return end
    for _, label in ipairs( {
        "s_attack_4", "s_attack_5", "s_attack_3", "s_attack_2",
        "s_attack_1", "s_attack_6", "s_attack_7"
    } ) do
        safeOrder( findLabel( label ), GameObject.Order.Attack, self.base )
    end
    print( "[Recovery] first reserve group attacking Starbase 176" )
end

function A2Federation03Mission:starbaseAttackTwo( )
    if self.phase ~= "gameplay" then return end
    for _, label in ipairs( {
        "t_attack_4", "t_attack_5", "t_attack_3", "t_attack_2", "t_attack_1"
    } ) do
        safeOrder( findLabel( label ), GameObject.Order.Attack, self.base )
    end
    print( "[Recovery] second reserve group attacking Starbase 176" )
end

function A2Federation03Mission:distressOne( )
    if self.phase == "gameplay" then Media:playSound( "a2_fed03_distress1.wav" ) end
end

function A2Federation03Mission:distressTwo( )
    if self.phase == "gameplay" then Media:playSound( "a2_fed03_distress2.wav" ) end
end

function A2Federation03Mission:waveOne( )
    if self.phase ~= "gameplay" then return end
    local released = self:releaseWave( WAVE_ONE, false )
    safeOrder( findLabel( "bbattle116_waveone" ), GameObject.Order.Attack, self.base )
    print( "[Recovery] Borg wave one released (" .. tostring( released ) .. "/9)" )
end

function A2Federation03Mission:waveTwo( )
    if self.phase ~= "gameplay" then return end
    local released = self:releaseWave( WAVE_TWO, false )
    safeOrder( findLabel( "bbattle117_wavetwo" ), GameObject.Order.Attack, self.base )
    safeOrder( findLabel( "bassault7_wavetwo" ), GameObject.Order.Attack,
        findLabel( "fyard63" ) )
    print( "[Recovery] Borg wave two released (" .. tostring( released ) .. "/8)" )
end

function A2Federation03Mission:waveThree( )
    if self.phase ~= "gameplay" then return end
    self:activateWaveThreeReserve( )
    Media:playSound( "a2_fed03_douglass.wav" )
    Objectives:load( "a2_fed03_fourth_objectives.txt" )
    Objectives.visible = true
    self:complete( 1 )
    self:complete( 2 )
    local released = self:releaseWave( WAVE_THREE, false )
    for _, label in ipairs( WAVE_THREE_FAST ) do
        local ship = findLabel( label )
        if live( ship ) then pcall( function( ) ship.impulseSpeed = 45.0 end ) end
    end
    safeOrder( findLabel( "sen_kill_1" ), GameObject.Order.Attack,
        findLabel( "fsensor1023" ) )
    safeOrder( findLabel( "sen_kill_2" ), GameObject.Order.Attack,
        findLabel( "fsensor1022" ) )
    safeOrder( findLabel( "sen_kill_3" ), GameObject.Order.Attack,
        findLabel( "fsensor1024" ) )
    self.douglass = findLabel( "Douglass" ) or self.douglass
    self.douglassReleased = live( self.douglass )
    print( "[Recovery] Douglass wave released (" .. tostring( released ) .. "/16)" )
end

function A2Federation03Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Federation03Mission:checkBaseSecured( )
    if self.baseSecured or not live( self.base ) then return end
    if not live( findLabel( "sbasekiller" ) )
        and not live( findLabel( "bbattle13_basekiller" ) ) then
        self.baseSecured = true
        Media:playSound( "a2_fed03_second.wav" )
        Objectives:load( "a2_fed03_second_objectives.txt" )
        Objectives.visible = true
        self:complete( 1 )
        if self.scienceBuilt then self:complete( 2 ) end
        self:schedule( "distress_one", 3.5, "distressOne" )
        self:schedule( "distress_two", 6.5, "distressTwo" )
        print( "[Recovery] Starbase 176 secured" )
    end
end

function A2Federation03Mission:checkScienceStation( )
    if self.scienceBuilt or #findCraft( "fresear2.odf", 1 ) == 0 then return end
    self.scienceBuilt = true
    Objectives:load( "a2_fed03_second_objectives.txt" )
    Objectives.visible = true
    if self.baseSecured then self:complete( 1 ) end
    self:complete( 2 )
    if not self.thirdWaveScheduled then
        self.thirdWaveScheduled = true
        self:schedule( "wave_three", 600.0, "waveThree" )
        self:schedule( "starbase_attack_one", 180.0, "starbaseAttackOne" )
        self:schedule( "starbase_attack_two", 300.0, "starbaseAttackTwo" )
    end
    print( "[Recovery] science station constructed" )
end

function A2Federation03Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 3 )
    self:complete( 4 )
    self:complete( 5 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.douglass ) then
        Cineractive:lookFrom( self.douglass )
        Cineractive:setCameraOffset( Vector( -350, 150, -500 ) )
        Cineractive:lookAt( self.douglass )
    end
    UI:addTitle( "USS DOUGLASS RECOVERED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed03_success.wav" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Federation03Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation03Mission:startFailure( title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( "a2_fed04_lose.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation03Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation03Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if not live( self.enterprise ) or ( self.enterprise.crew ~= nil and self.enterprise.crew <= 0 ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED" ); return
    end
    if not live( self.base ) or ( self.base.crew ~= nil and self.base.crew <= 0 ) then
        self:startFailure( "STARBASE 176 HAS BEEN DESTROYED" ); return
    end
    self:checkBaseSecured( )
    self:checkScienceStation( )
    if self.douglassReleased and self.baseSecured and self.scienceBuilt
        and live( self.douglass ) and self.douglass.player.number == 1 then
        self:startSuccess( ); return
    end
    if self.douglassReleased and ( not live( self.douglass )
        or distanceSquared( self.douglass.position, WAVE_DESTINATIONS.path_6 ) < 90000 ) then
        self:startFailure( "THE DOUGLASS HAS LEFT THE SYSTEM" )
    end
end

function A2Federation03Mission:cineractiveUpdate( ) end

function A2Federation03Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation03Mission( ) )
