-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 1 CONVERSION
--
-- Behaviour source:
--   a2_fed01S.dsl, a2_fed01R.drl, a2_fed01.bzn, and the original A2 media.
-- Megadroid Mission Mod examples were used only to learn the MMM Lua API.

class 'A2Federation01Mission'

local function isLive( entity )
    return entity ~= nil and entity.valid
end

local function distanceSquared( a, b )
    if a == nil or b == nil then
        return 1000000000
    end

    local dx = a.x - b.x
    local dy = a.y - b.y
    local dz = a.z - b.z
    return dx * dx + dy * dy + dz * dz
end

local function safeOrder( entity, order, target )
    if not isLive( entity ) then
        return
    end

    pcall( function( )
        if target == nil then
            entity:giveOrder( order )
        else
            entity:giveOrder( order, target )
        end
    end )
end

local function safeRemove( entity )
    if isLive( entity ) then
        Entity.remove( entity )
    end
end

local function findByOdf( odf, playerNumber )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.odf == odf
            and ( playerNumber == nil or e.player.number == playerNumber )
    end ):find( )
end

local function findOneByOdf( odf, playerNumber )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.odf == odf
            and ( playerNumber == nil or e.player.number == playerNumber )
    end ):findOne( )
end

local function findGameObjectsByOdf( odf )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and e.odf == odf
    end ):find( )
end

local function allCraftForPlayer( playerNumber )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.player.number == playerNumber
            and ( e.crew == nil or e.crew > 0 )
    end ):find( )
end

local function takeNearestCraft( position, ships )
    local bestIndex = nil
    local bestDistance = 1000000000

    for index, ship in ipairs( ships ) do
        if isLive( ship ) then
            local candidateDistance = distanceSquared( position, ship.position )
            if candidateDistance < bestDistance then
                bestIndex = index
                bestDistance = candidateDistance
            end
        end
    end

    if bestIndex == nil then
        return nil
    end

    return table.remove( ships, bestIndex )
end

local function nearestCraft( position, ships, maximumDistance )
    local best = nil
    local bestDistance = maximumDistance * maximumDistance

    for _, ship in pairs( ships ) do
        if isLive( ship ) then
            local candidateDistance = distanceSquared( position, ship.position )
            if candidateDistance <= bestDistance then
                best = ship
                bestDistance = candidateDistance
            end
        end
    end

    return best
end

local function startsWith( text, prefix )
    return text ~= nil and string.sub( text, 1, string.len( prefix ) ) == prefix
end

local POS = {
    ENTERPRISE = Vector( 904.8057, 12.3004, 538.1632 ),
    GALAXY = Vector( 675.5134, 0, 539.2114 ),
    CRUISER_1 = Vector( 788.3301, 0, 698.6263 ),
    CRUISER_2 = Vector( 790.5694, 0, 652.9666 ),
    SCOUT = Vector( 925.5540, 0, 712.0067 ),
    CONSTRUCTOR_1 = Vector( 789.6471, 0, 495.3276 ),
    CONSTRUCTOR_2 = Vector( 794.3093, 0, 396.4229 ),

    REGULA_II = Vector( 3426.5916, -100, 2868.1484 ),
    REGULA_III = Vector( 9498.6490, 0, 11006.3000 ),

    BORG_YARD_2 = Vector( 12158.2170, 0, 880.3464 ),
    BORG_MINING_2 = Vector( 10734.4960, -25, 1393.4166 ),
    BORG_MOON_1 = Vector( 10196.7930, -100, 1201.4183 ),
    BORG_BASE_1 = Vector( 10273.3990, 0, 11255.5000 ),
    BORG_BASE_2 = Vector( 1672.6000, 0, 11999.8000 ),

    BCRUISE1_1 = Vector( 8698.5220, 0, 12484.7010 ),
    BCRUISE1_2 = Vector( 8700.3180, 0, 12651.4310 ),
    BCRUISE1_3 = Vector( 8937.2900, 0, 12264.6770 ),
    BCRUISE2_1 = Vector( 8808.6490, 0, 12263.5690 ),
    BCRUISE2_2 = Vector( 9069.6350, 0, 12280.1900 )
}

local TURRET_POSITIONS = {
    Vector( 9704.6455, 0, 1574.4326 ),
    Vector( 9742.2490, 0, 2643.2615 ),
    Vector( 12431.9270, 0, 1765.4731 ),
    Vector( 10047.8350, 0, 1699.8805 ),
    Vector( 12104.7480, 0, 1506.6295 )
}

local BORG_PATROL_PATH = {
    Vector( 7941.7500, 0, 12344.6520 ),
    Vector( 8234.5060, 0, 11155.9030 ),
    Vector( 8456.7650, 0, 10435.3400 ),
    Vector( 8687.7280, 0, 9650.9810 ),
    Vector( 9133.5510, 0, 9017.9560 ),
    Vector( 9722.8070, 0, 8283.7230 ),
    Vector( 10353.1030, 0, 7714.1240 ),
    Vector( 10914.7310, 0, 8358.8180 ),
    Vector( 11342.6045, 0, 9066.1420 ),
    Vector( 11857.2680, 0, 9758.6000 ),
    Vector( 12334.3830, 0, 10472.3650 ),
    Vector( 12367.8190, 0, 11130.2250 ),
    Vector( 12121.9960, 0, 11372.4560 )
}

local BORG_BUILD_POINT_1 = {
    Vector( 1198.2708, 0, 12824.9860 ),
    Vector( 1393.4559, 0, 12833.5510 ),
    Vector( 1588.3984, 0, 12829.8650 ),
    Vector( 1792.1504, 0, 12829.8650 )
}

local BORG_BUILD_POINT_2 = {
    Vector( 11396.5220, 0, 12833.0580 ),
    Vector( 11202.2510, 0, 12835.4760 ),
    Vector( 10999.0550, 0, 12829.4790 ),
    Vector( 10799.2340, 0, 12831.8890 )
}

local BORG_BUILD_POINT_3 = {
    Vector( 12857.2290, 0, 2554.5313 ),
    Vector( 12854.4560, 0, 2342.5056 ),
    Vector( 12848.7860, 0, 2140.8923 ),
    Vector( 12845.3090, 0, 1948.9194 )
}

local PLAYER_STATION_ODFS = {
    [ "fbase.odf" ] = true,
    [ "fyard.odf" ] = true,
    [ "fmining.odf" ] = true,
    [ "fresear.odf" ] = true,
    [ "forbital.odf" ] = true
}

function A2Federation01Mission:__init( )
    self.phase = "loading"
    self.openingComplete = false
    self.firstContactPlayed = false
    self.firstAttackSent = false
    self.objectiveComplete = { false, false, false, false }
    self.borgWasPresent = false
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.patrols = { }
end

function A2Federation01Mission:schedule( id, seconds, methodName )
    self.timerSerial = self.timerSerial + 1
    local timerName = "a2f01_" .. id .. "_" .. tostring( self.timerSerial )
    local timer = Timer( timerName, seconds, Timer.State.Started )
    timer:hook( timerName .. "_hook", nil, function( timerObject, hook )
        if not self.ended then
            self[ methodName ]( self )
        end
    end, nil )
    self.timers[ timerName ] = timer
end

function A2Federation01Mission:setup( )
    print( "[Invasion] clean-room a2_fed01 conversion loaded" )

    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )

    Objectives:load( "a2_fed01_A.txt" )
    Objectives.visible = false
    self.enterprise = findOneByOdf( "fente.odf", 1 )
    self:startOpeningCineractive( )
end

function A2Federation01Mission:startOpeningCineractive( )
    self.phase = "opening"
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 3.0 )

    if isLive( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( -350, 120, -500 ) )
        Cineractive:lookAt( self.enterprise )
    else
        Cineractive:lookFrom( Vector( 0, 150, 6200 ) )
        Cineractive:lookAt( Vector( 400, 0, 6650 ) )
    end

    Media:playSound( "Mfed300.wav" )
    self:schedule( "opening_title", 1.5, "showOpeningTitle" )
    self:schedule( "opening_intro", 5.0, "playOpeningVoice" )
    self:schedule( "opening_text_1", 5.0, "showIntroText1" )
    self:schedule( "opening_text_2", 12.0, "showIntroText2" )
    self:schedule( "opening_shot_2", 15.0, "openingShot2" )
    self:schedule( "opening_text_3", 19.0, "showIntroText3" )
    self:schedule( "opening_text_4", 26.0, "showIntroText4" )
    self:schedule( "opening_shot_3", 30.0, "openingShot3" )
    self:schedule( "opening_text_5", 33.0, "showIntroText5" )
    self:schedule( "opening_done", 48.0, "finishOpeningCineractive" )
end

function A2Federation01Mission:showOpeningTitle( )
    if self.phase == "opening" then
        UI:addTitle( "INVASION", 50, 50, 7.0, true )
        UI:addSubtitle( "USS Enterprise\nStardate 54522.2\nLocation: Alpha Quadrant", 50, 85, 8.0, true )
    end
end

function A2Federation01Mission:playOpeningVoice( )
    if self.phase == "opening" then
        Media:playSound( "a2_fed01_intro.wav" )
    end
end

function A2Federation01Mission:showIntroText1( )
    if self.phase == "opening" then
        UI:addSubtitle( "Space... the final frontier", 50, 85, 6.0, true )
    end
end

function A2Federation01Mission:showIntroText2( )
    if self.phase == "opening" then
        UI:addSubtitle( "These are the voyages of the starship Enterprise...", 50, 85, 6.0, true )
    end
end

function A2Federation01Mission:showIntroText3( )
    if self.phase == "opening" then
        UI:addSubtitle( "Its continuing mission: to explore strange new worlds", 50, 85, 6.0, true )
    end
end

function A2Federation01Mission:showIntroText4( )
    if self.phase == "opening" then
        UI:addSubtitle( "To seek out new life and new civilizations", 50, 85, 6.0, true )
    end
end

function A2Federation01Mission:showIntroText5( )
    if self.phase == "opening" then
        UI:addSubtitle( "To boldly go where no one has gone before.", 50, 85, 8.0, true )
    end
end

function A2Federation01Mission:openingShot2( )
    if self.phase ~= "opening" then
        return
    end

    Cineractive:lookFrom( Vector( 12500, 240, 2100 ) )
    Cineractive:lookAt( Vector( 11200, 0, 900 ) )
end

function A2Federation01Mission:openingShot3( )
    if self.phase ~= "opening" then
        return
    end

    Cineractive:lookFrom( Vector( 8700, 400, 11700 ) )
    Cineractive:lookAt( POS.REGULA_III )
end

function A2Federation01Mission:removeNamedCineractiveObjects( )
    local names = {
        "Cineractive_Starbase", "Cineractive_Shipyard",
        "Cineractive_Dilithium_Moon", "Cineractive_Basic_Research",
        "cineractive_freighter_1", "cineractive_freighter_2",
        "cineractive_planet_1", "cineractive_planet_2", "cineractive_planet_3",
        "cineractive_mining_station", "cineractive_enterprise",
        "cineractive_enterprise_2", "cineractive_enterprise_3"
    }

    for _, name in ipairs( names ) do
        local objects = EntityFinder( function( e )
            return e:isType( Entity.Type.GameObject ) and e.name == name
        end ):find( )
        for _, object in pairs( objects ) do
            safeRemove( object )
        end
    end

    -- The stock BZN contains a few cinematic objects whose unique names are
    -- not always exposed as Entity.name by MMM.  Their ODF and remote staging
    -- positions distinguish them from the actual player base at map start.
    local remoteOdfs = {
        "fbattle.odf", "fbase.odf", "fyard.odf",
        "fresear.odf", "fmining.odf", "ffreight.odf"
    }
    for _, odf in ipairs( remoteOdfs ) do
        local objects = findByOdf( odf, nil )
        for _, object in pairs( objects ) do
            if odf == "fbattle.odf" or object.position.z > 3000 then
                safeRemove( object )
            end
        end
    end
end

function A2Federation01Mission:relocateStartingFleet( )
    local startingOdfs = {
        "fente.odf", "fgalaxy.odf", "fcruise1.odf", "fscout.odf", "fconst.odf"
    }
    for _, odf in ipairs( startingOdfs ) do
        local ships = findByOdf( odf, 1 )
        for _, ship in pairs( ships ) do
            safeRemove( ship )
        end
    end

    self.enterprise = Entity.add( "fente.odf", 1, POS.ENTERPRISE )
    self.galaxy = Entity.add( "fgalaxy.odf", 1, POS.GALAXY )
    self.cruiser1 = Entity.add( "fcruise1.odf", 1, POS.CRUISER_1 )
    self.cruiser2 = Entity.add( "fcruise1.odf", 1, POS.CRUISER_2 )
    self.scout = Entity.add( "fscout.odf", 1, POS.SCOUT )
    self.constructor1 = Entity.add( "fconst.odf", 1, POS.CONSTRUCTOR_1 )
    self.constructor2 = Entity.add( "fconst.odf", 1, POS.CONSTRUCTOR_2 )

    if isLive( self.enterprise ) then
        pcall( function( ) self.enterprise.name = "USS Enterprise-E" end )
    end

    safeOrder( self.enterprise, GameObject.Order.Stop, nil )
    safeOrder( self.galaxy, GameObject.Order.Stop, nil )
    safeOrder( self.cruiser1, GameObject.Order.Stop, nil )
    safeOrder( self.cruiser2, GameObject.Order.Stop, nil )
    safeOrder( self.scout, GameObject.Order.Stop, nil )
    safeOrder( self.constructor1, GameObject.Order.Stop, nil )
    safeOrder( self.constructor2, GameObject.Order.Stop, nil )
end

function A2Federation01Mission:ensureObjectNear( odf, playerNumber, position, radius )
    local existing = findByOdf( odf, playerNumber )
    local object = nearestCraft( position, existing, radius )
    if object == nil then
        object = Entity.add( odf, playerNumber, position )
    end
    return object
end

function A2Federation01Mission:setupBorgForces( )
    self.borg.resources.dilithium = 5000
    self.borg.resources.metal = 5000

    -- ScriptInit in the stock mission explicitly makes Regula III a Borg
    -- colony with a 20-person military garrison before gameplay begins.
    local regulaIII = self:findRegulaIII( )
    if isLive( regulaIII ) then
        pcall( function( ) regulaIII.player = self.borg end )
        pcall( function( ) regulaIII.crew = 20 end )
        pcall( function( ) regulaIII.race = Race.find( "borg" ) end )
    end

    self.byard2 = self:ensureObjectNear( "byard.odf", 2, POS.BORG_YARD_2, 300 )
    self.bmining2 = self:ensureObjectNear( "bmining.odf", 2, POS.BORG_MINING_2, 300 )
    self.mdmoon1 = self:ensureObjectNear( "mdmoon.odf", 0, POS.BORG_MOON_1, 300 )

    self.turrets = { }
    for _, position in ipairs( TURRET_POSITIONS ) do
        table.insert( self.turrets,
            self:ensureObjectNear( "bturret.odf", 2, position, 160 ) )
    end

    local cruise1 = findByOdf( "bcruise1.odf", 2 )
    self.bcruise1_1 = takeNearestCraft( POS.BCRUISE1_1, cruise1 )
    self.bcruise1_2 = takeNearestCraft( POS.BCRUISE1_2, cruise1 )
    self.bcruise1_3 = takeNearestCraft( POS.BCRUISE1_3, cruise1 )

    local cruise2 = findByOdf( "bcruise2.odf", 2 )
    self.bcruise2_1 = takeNearestCraft( POS.BCRUISE2_1, cruise2 )
    self.bcruise2_2 = takeNearestCraft( POS.BCRUISE2_2, cruise2 )

    self.patrols = {
        { ship = self.bcruise1_1, point = 1, active = true },
        { ship = self.bcruise1_2, point = 3, active = true },
        { ship = self.bcruise1_3, point = 5, active = true },
        { ship = self.bcruise2_1, point = 7, active = true },
        { ship = self.bcruise2_2, point = 9, active = true }
    }
    for _, patrol in ipairs( self.patrols ) do
        if isLive( patrol.ship ) then
            safeOrder( patrol.ship, GameObject.Order.Go, BORG_PATROL_PATH[ patrol.point ] )
        end
    end

    local freighters = findByOdf( "bfreight.odf", 2 )
    for _, freighter in pairs( freighters ) do
        safeOrder( freighter, GameObject.Order.Mine, nil )
    end

    self.borgWasPresent = #self:borgCombatCraft( ) > 0
end

function A2Federation01Mission:finishOpeningCineractive( )
    if self.openingComplete then
        return
    end

    self.openingComplete = true
    self.phase = "gameplay"
    Media:stopSounds( )
    self:removeNamedCineractiveObjects( )
    self:relocateStartingFleet( )
    self:setupBorgForces( )

    Cineractive.active = false
    Objectives:load( "a2_fed01_A.txt" )
    Objectives.visible = true
    self.borg:loadAIP( "a2_fed01_build_list.aip" )

    self:schedule( "borg_resources", 60.0, "injectBorgResources" )
    self:schedule( "siege_1", 480.0, "borgSiegeWave1" )
    self:schedule( "siege_2", 840.0, "borgSiegeWave2" )
    self:schedule( "siege_3", 1200.0, "borgSiegeWave3" )
    self:schedule( "kamikaze", 600.0, "enemyKamikaze" )
    print( "[Invasion] gameplay started" )
end

function A2Federation01Mission:injectBorgResources( )
    if self.phase ~= "gameplay" then
        return
    end

    self.borg.resources.dilithium = self.borg.resources.dilithium + 1000
    self.borg.resources.metal = self.borg.resources.metal + 1000
    self:schedule( "borg_resources", 60.0, "injectBorgResources" )
end

function A2Federation01Mission:playerStations( )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.player.number == 1
            and PLAYER_STATION_ODFS[ e.odf ] == true
            and ( e.crew == nil or e.crew > 0 )
    end ):find( )
end

function A2Federation01Mission:nearestPlayerTarget( position )
    local stations = self:playerStations( )
    local target = nearestCraft( position, stations, 20000 )
    if target ~= nil then
        return target
    end

    local craft = allCraftForPlayer( 1 )
    return nearestCraft( position, craft, 20000 )
end

function A2Federation01Mission:spawnSiegeFleet( odfs, positions )
    local fleet = { }
    for index, odf in ipairs( odfs ) do
        local position = positions[ index ]
        local ship = Entity.add( odf, 2, position )
        table.insert( fleet, ship )
    end

    local target = self:nearestPlayerTarget( positions[ 1 ] )
    for _, ship in pairs( fleet ) do
        if target ~= nil then
            safeOrder( ship, GameObject.Order.Attack, target )
        else
            safeOrder( ship, GameObject.Order.Attack, POS.ENTERPRISE )
        end
    end
end

function A2Federation01Mission:anchorAlive( odf, position )
    return nearestCraft( position, findByOdf( odf, 2 ), 900 ) ~= nil
end

function A2Federation01Mission:borgSiegeWave1( )
    if self.phase == "gameplay" and self:anchorAlive( "byard.odf", POS.BORG_YARD_2 ) then
        self:spawnSiegeFleet( {
            "bdestroy.odf", "bdestroy.odf", "bdestroy.odf", "bdestroy.odf"
        }, BORG_BUILD_POINT_3 )
        print( "[Invasion] Borg siege fleet 1 launched" )
    end
    if self.phase == "gameplay" then
        self:schedule( "siege_1", 240.0, "borgSiegeWave1" )
    end
end

function A2Federation01Mission:borgSiegeWave2( )
    if self.phase == "gameplay" and self:anchorAlive( "bbase.odf", POS.BORG_BASE_2 ) then
        self:spawnSiegeFleet( {
            "bcruise1.odf", "bcruise1.odf", "bcruise1.odf", "bcruise2.odf"
        }, BORG_BUILD_POINT_1 )
        print( "[Invasion] Borg siege fleet 2 launched" )
    end
    if self.phase == "gameplay" then
        self:schedule( "siege_2", 420.0, "borgSiegeWave2" )
    end
end

function A2Federation01Mission:borgSiegeWave3( )
    if self.phase == "gameplay" and self:anchorAlive( "bbase.odf", POS.BORG_BASE_1 ) then
        self:spawnSiegeFleet( {
            "bcruise1.odf", "bcruise1.odf", "bcruise2.odf", "bcruise2.odf"
        }, BORG_BUILD_POINT_2 )
        print( "[Invasion] Borg siege fleet 3 launched" )
    end
    if self.phase == "gameplay" then
        self:schedule( "siege_3", 600.0, "borgSiegeWave3" )
    end
end

function A2Federation01Mission:enemyKamikaze( )
    if self.phase ~= "gameplay" then
        return
    end

    if #self:playerStations( ) == 0 then
        local target = findOneByOdf( "fente.odf", 1 )
        if target == nil then
            target = allCraftForPlayer( 1 )[ 1 ]
        end
        if target ~= nil then
            for _, ship in pairs( self:borgCombatCraft( ) ) do
                safeOrder( ship, GameObject.Order.Attack, target )
            end
        end
    end
    self:schedule( "kamikaze", 600.0, "enemyKamikaze" )
end

function A2Federation01Mission:updatePatrols( )
    for _, patrol in ipairs( self.patrols ) do
        if patrol.active and isLive( patrol.ship ) then
            local destination = BORG_PATROL_PATH[ patrol.point ]
            if distanceSquared( patrol.ship.position, destination ) < 22500 then
                patrol.point = patrol.point + 1
                if patrol.point > #BORG_PATROL_PATH then
                    patrol.point = 1
                end
                safeOrder( patrol.ship, GameObject.Order.Go, BORG_PATROL_PATH[ patrol.point ] )
            end
        end
    end
end

function A2Federation01Mission:borgCombatCraft( )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.player.number == 2
            and startsWith( e.odf, "b" )
            and ( e.crew == nil or e.crew > 0 )
    end ):find( )
end

function A2Federation01Mission:checkFirstBorgContact( )
    if self.firstContactPlayed then
        return
    end

    local playerCraft = allCraftForPlayer( 1 )
    for _, borgCraft in pairs( self:borgCombatCraft( ) ) do
        if nearestCraft( borgCraft.position, playerCraft, 1800 ) ~= nil then
            self.firstContactPlayed = true
            Media:playSound( "a2_fed01_meet_the_borg.wav" )
            print( "[Invasion] first Borg contact" )
            return
        end
    end
end

function A2Federation01Mission:checkEnterpriseSpotted( )
    if self.firstAttackSent or not isLive( self.enterprise ) then
        return
    end

    local attackers = { self.bcruise1_3, self.bcruise2_1, self.bcruise2_2 }
    for _, attacker in pairs( attackers ) do
        if isLive( attacker )
            and distanceSquared( attacker.position, self.enterprise.position ) <= 2250000 then
            self.firstAttackSent = true
            for _, attackShip in pairs( attackers ) do
                safeOrder( attackShip, GameObject.Order.Attack, self.enterprise )
            end
            for index = 3, 5 do
                if self.patrols[ index ] ~= nil then
                    self.patrols[ index ].active = false
                end
            end
            print( "[Invasion] Enterprise spotted by Borg patrol" )
            return
        end
    end
end

function A2Federation01Mission:completeObjective( index, sound )
    if self.objectiveComplete[ index ] then
        return
    end

    self.objectiveComplete[ index ] = true
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
    Media:playSound( sound )
    print( "[Invasion] objective " .. tostring( index ) .. " complete" )
end

function A2Federation01Mission:findRegulaII( )
    return nearestCraft( POS.REGULA_II,
        findGameObjectsByOdf( "pb_clssl.odf" ), 600 )
end

function A2Federation01Mission:findRegulaIII( )
    return nearestCraft( POS.REGULA_III,
        findGameObjectsByOdf( "pb_clssh.odf" ), 600 )
end

function A2Federation01Mission:removeRemainingBorgCraft( )
    local remaining = allCraftForPlayer( 2 )
    for _, craft in pairs( remaining ) do
        safeRemove( craft )
    end
end

function A2Federation01Mission:updateObjectives( )
    if not self.objectiveComplete[ 1 ] and #findByOdf( "fresear.odf", 1 ) > 0 then
        self:completeObjective( 1, "a2_fed01_generic_objective_1.wav" )
    end

    if not self.objectiveComplete[ 2 ] then
        local regulaII = self:findRegulaII( )
        if isLive( regulaII ) and regulaII.player.number == 1 then
            self:completeObjective( 2, "a2_fed01_generic_objective_1.wav" )
        end
    end

    if not self.objectiveComplete[ 3 ] and #findByOdf( "forbital.odf", 1 ) > 0 then
        self:completeObjective( 3, "a2_fed01_generic_objective_1.wav" )
    end

    if not self.objectiveComplete[ 4 ]
        and self.borgWasPresent
        and #self:borgCombatCraft( ) == 0 then
        local regulaIII = self:findRegulaIII( )
        if isLive( regulaIII ) then
            pcall( function( ) regulaIII.player = self.player end )
        end
        self:removeRemainingBorgCraft( )
        self:completeObjective( 4, "a2_fed01_generic_objective_2.wav" )
    end
end

function A2Federation01Mission:hasPlayerCapitalShip( )
    local craft = allCraftForPlayer( 1 )
    for _, ship in pairs( craft ) do
        if startsWith( ship.odf, "f" ) and PLAYER_STATION_ODFS[ ship.odf ] ~= true
            and ship.odf ~= "fconst.odf" and ship.odf ~= "ffreight.odf" then
            return true
        end
    end
    return false
end

function A2Federation01Mission:allObjectivesComplete( )
    for index = 1, 4 do
        if not self.objectiveComplete[ index ] then
            return false
        end
    end

    local regulaIII = self:findRegulaIII( )
    return #self:playerStations( ) > 0
        and self:hasPlayerCapitalShip( )
        and isLive( regulaIII )
        and regulaIII.player.number ~= 2
end

function A2Federation01Mission:startSuccess( )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "success"
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 2.0 )
    local regulaIII = self:findRegulaIII( )
    if isLive( regulaIII ) then
        Cineractive:lookFrom( regulaIII )
        Cineractive:setCameraOffset( Vector( -700, 350, -700 ) )
        Cineractive:lookAt( regulaIII )
    end
    UI:addTitle( "MISSION ACCOMPLISHED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed01_success.wav" )
    print( "[Invasion] victory accepted; recording mission success" )

    -- Give the finish request to MMM immediately and let the engine own the
    -- delay while the 41-second stock success voice-over plays.  A Lua timer
    -- here could leave the campaign unrecorded if its callback was lost.
    Mission:finish( true, 42.0 )
end

function A2Federation01Mission:finishSuccess( )
    if self.ended then
        return
    end
    self.ended = true
    Cineractive.active = false
    print( "[Invasion] success cineractive skipped; finishing immediately" )
    Mission:finish( true, 0 )
end

function A2Federation01Mission:startFailure( )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "failure"
    Cineractive.skippable = false
    Cineractive.active = true
    Cineractive:fadeIn( 1.0 )
    UI:addTitle( "THE ENTERPRISE HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed01_failure.wav" )
    self:schedule( "mission_failure", 8.0, "finishFailure" )
end

function A2Federation01Mission:finishFailure( )
    if self.ended then
        return
    end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation01Mission:update( )
    if self.phase ~= "gameplay" or self.ending or self.ended then
        return
    end

    self.enterprise = findOneByOdf( "fente.odf", 1 )
    if not isLive( self.enterprise ) or ( self.enterprise.crew ~= nil and self.enterprise.crew <= 0 ) then
        self:startFailure( )
        return
    end

    self:updatePatrols( )
    self:checkFirstBorgContact( )
    self:checkEnterpriseSpotted( )
    self:updateObjectives( )

    if self:allObjectivesComplete( ) then
        self:startSuccess( )
    end
end

function A2Federation01Mission:cineractiveUpdate( )
    -- Timer hooks drive the recovered opening and ending sequences.
end

function A2Federation01Mission:cineractiveFinish( forced )
    if not forced then
        return
    end

    if self.phase == "opening" then
        self:finishOpeningCineractive( )
    elseif self.phase == "success" then
        self:finishSuccess( )
    end
end

MMM.register( A2Federation01Mission( ) )
