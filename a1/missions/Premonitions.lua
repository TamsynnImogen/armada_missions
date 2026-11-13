-- CLEAN-ROOM STAR TREK: ARMADA FEDERATION 1 CONVERSION
--
-- Behaviour source:
--   Federation1S.dsl, Federation1R.drl, fed1.bzn, and the original A1 media.
-- Megadroid Mission Mod tutorials were used only to learn the MMM Lua API.
-- No existing Premonitions Lua recreation was used as conversion evidence.

class 'A1PremonitionsMission'

local A1_COMBAT_PLANE_Y = 38.5

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

    if target == nil then
        entity:giveOrder( order )
    else
        entity:giveOrder( order, target )
    end
end

local function safeRemove( entity )
    if isLive( entity ) then
        Entity.remove( entity )
    end
end

local function setInvincible( entity, value )
    if isLive( entity ) then
        pcall( function( ) entity.invincible = value end )
    end
end

local function setShields( entity, value )
    if isLive( entity ) then
        pcall( function( ) entity.shields = value end )
    end
end

local function clampToA1CombatPlane( entity )
    if not isLive( entity ) then
        return
    end

    local position = entity.position
    if position ~= nil and math.abs( position.y - A1_COMBAT_PLANE_Y ) > 0.25 then
        -- A1's tactical simulation is planar. Fleet Ops' 3D movement can add
        -- vertical steering even while following a perfectly flat BZN path,
        -- eventually putting ships outside A1-era weapon targeting. Preserve
        -- X/Z movement but pin mission enemies to the authored fed1 plane.
        entity.position = Vector( position.x, A1_COMBAT_PLANE_Y, position.z )
    end
end

local function playA1BridgeMovie( filename )
    -- Fleet Ops routes these A1 bridge BIKs through its embedded Armada movie
    -- renderer. FeaturePack enlarges that renderer's fixed backing texture from
    -- 256x128 to 512x256, which can contain the stock 400x200 bridge frames
    -- without UV wrapping/tiling.
    Media:playMovie( filename )
end

local function stopA1BridgeMovie( )
    pcall( function( ) Media:stopMovie( ) end )
end

local function optionalPath( name )
    -- Path(name) creates an empty native path when the name is missing. Test
    -- first so optional cinematics never mutate the map's path table.
    local exists = false
    local ok = pcall( function( ) exists = Path.exists( name ) end )
    if not ok or not exists then
        return nil
    end

    local pathOk, path = pcall( function( ) return Path( name ) end )
    if not pathOk or path == nil or path.count <= 0 then
        return nil
    end
    return path
end

local function flattenGameplayPath( name, planeY )
    -- Armada 1 gameplay maps are 2D. Fleet Ops gives the converted map a real
    -- Y extent, so old patrol points can otherwise become genuine 3D flight
    -- targets and send ships above/below the practical combat plane.
    --
    -- Deliberately use this only for gameplay paths. Cinematic camera paths
    -- keep their authored vertical offsets.
    local path = optionalPath( name )
    if path == nil then
        return nil
    end

    local y = planeY or 38.5
    local points = path.points
    for index = 1, path.count do
        local point = points[ index ]
        if point ~= nil then
            pcall( function( )
                path:set( index, Vector( point.x, y, point.z ) )
            end )
        end
    end

    return path
end

local function crossedToExitSide( entity )
    if not isLive( entity ) then
        return false
    end

    -- Entrance is around X=5686 and exit around X=1914. Treat crossing the
    -- midpoint as successful native transit; this remains valid even if the
    -- ship immediately continues away from WORMEXIT after emerging.
    return entity.position.x < 3600.0
end

local function setCinematicGameplay( active )
    -- These are stock mission-script operations exposed by the extended MMM
    -- binding. Keep them protected so an older runtime still degrades rather
    -- than aborting the Lua mission during development.
    if active then
        pcall( function( ) Game:disableAllAI( ) end )
        pcall( function( ) Game:setGridVisible( false ) end )
        pcall( function( ) Game:setObstacleAvoidance( false ) end )
    else
        pcall( function( ) Game:setGridVisible( true ) end )
        pcall( function( ) Game:setObstacleAvoidance( true ) end )
        pcall( function( ) Game:enableAllAI( ) end )
    end
end

local function damagePremonitionSystems( entity )
    if not isLive( entity ) then
        return
    end

    -- Federation1S.dsl sets shields to 30%, destroys life support and weapons,
    -- and disables the shield generator before the Premonition reaches the
    -- rescue phase. CraftSystem gives us a close native equivalent in MMM.
    setShields( entity, 0.3 )
    pcall( function( )
        local systems = entity.systems
        if systems ~= nil then
            if systems.lifeSupport ~= nil then
                systems.lifeSupport.health = 0.0
                systems.lifeSupport.permanentDisable = true
            end
            if systems.weapons ~= nil then
                systems.weapons.health = 0.0
                systems.weapons.permanentDisable = true
            end
            if systems.shields ~= nil then
                systems.shields.active = false
            end
        end
    end )
end

local function preparePremonitionRescueState( entity )
    if not isLive( entity ) then
        return
    end

    -- The stock distress transition re-enables the shield generator, raises
    -- shields to 70%, and disables the engines while life support/weapons stay
    -- destroyed. Preserve that distinction instead of simply changing shields.
    setShields( entity, 0.7 )
    pcall( function( )
        local systems = entity.systems
        if systems ~= nil then
            if systems.shields ~= nil then
                systems.shields.active = true
            end
            if systems.engines ~= nil then
                systems.engines.active = false
            end
        end
    end )
end

local function entityCompromised( entity )
    if not isLive( entity ) then
        return true
    end

    return entity.crew ~= nil and entity.crew <= 0
end

local function craftForPlayer( playerNumber )
    return EntityFinder( function( e )
        return e:isType( Entity.Type.Craft )
            and e.player.number == playerNumber
            and e.crew > 0
    end ):find( )
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

local POS = {
    ENTSTART = Vector( 5749.25, -10.1586, 1039.10 ),
    LINCOLNSTART = Vector( 5683.13, 0, 1002.92 ),
    JACKSONSTART = Vector( 5800.15, 0, 1006.40 ),
    FEDCON1START = Vector( 5746.01, 0, 904.276 ),
    CAMERA1 = Vector( 5750.98, 1.4278, 1042.75 ),
    ENTFLYBY = Vector( 5633.34, 26.5194, 341.653 ),
    ZOOMOUT = Vector( 5774.95, 411.5, 677.647 ),
    WORMENTER = Vector( 5685.79, 0, 5591.63 ),
    WORMEXIT = Vector( 1914.39, -15.4729, 5664.03 ),
    PREMOCREATE = Vector( 5682.94, 0, 5788.41 ),
    CREATEBORG1 = Vector( 5580.74, 0, 6165.90 ),
    CREATEBORG2 = Vector( 5842.04, 0, 6173.52 ),
    WORMSHOT = Vector( 1910.87, 39.5563, 5430.06 ),
    PREMOSHOT = Vector( 1830.61, 94.133, 5089.59 ),
    PREMOSTART = Vector( 1920.82, 0, 4856.29 ),
    PREMOATTACK1 = Vector( 1831.03, 0, 4873.65 ),
    PREMOATTACK2 = Vector( 1990.21, 0, 4921.49 ),
    ENTTOPREMO = Vector( 1936.53, 0, 4672.49 ),
    PREMOENTPOINT = Vector( 2111.77, 31.1795, 4629.94 ),
    REINFORCE1 = Vector( 2519.25, 0, 6118.04 ),
    REINFORCE2 = Vector( 2660.74, 0, 6125.03 )
}

local MAP_CRAFT_POS = {
    ENTERPRISE = Vector( 5570.99, 0, 237.532 ),
    CONSTRUCTOR = Vector( 5563.03, -35.05472, 134.278 ),
    LINCOLN = Vector( 5497.75, -9.7259, 194.1 ),
    JACKSON = Vector( 5641.8374, -13.5091, 204.07297 )
}

local MAP_DOMINION_POSITIONS = {
    Vector( 1577.56, 38.5, 3009.6 ),
    Vector( 5188.47, 38.5, 2322.5 ),
    Vector( 1850.77, 38.5, 3846.6 ),
    Vector( 3643.97, 38.5, 3165.9 ),
    Vector( 4569.11, 38.5, 4883 ),
    Vector( 3824.28, 38.5, 6088 )
}

-- Recovered directly from fed1.bzn. Armada 1 gameplay is planar, but this
-- map's authored tactical plane is Y=38.5 rather than zero. Preserve that
-- exact plane for both the native path and any diagnostic fallback points.
local DOMINION_ROUTES = {
    {
        Vector( 1740.78, 38.5, 2485.6 ), Vector( 1795.94, 38.5, 2231.3 ),
        Vector( 2160.51, 38.5, 1951.5 ), Vector( 2602.83, 38.5, 1912.1 ),
        Vector( 2774.81, 38.5, 2221.9 ), Vector( 2528.72, 38.5, 2440.6 ),
        Vector( 2254.35, 38.5, 2666.1 ), Vector( 1897.13, 38.5, 2705.7 )
    },
    {
        Vector( 3509.32, 38.5, 2164.8 ), Vector( 3500.56, 38.5, 2518.5 ),
        Vector( 3846.18, 38.5, 2645.9 ), Vector( 4224.48, 38.5, 2634.3 ),
        Vector( 4585.11, 38.5, 2588.5 ), Vector( 4912.39, 38.5, 2454.9 ),
        Vector( 4998.71, 38.5, 2185.6 ), Vector( 4794.36, 38.5, 2047.8 ),
        Vector( 4507.92, 38.5, 2052.2 ), Vector( 4155.10, 38.5, 2050.3 ),
        Vector( 3738.41, 38.5, 1982.4 )
    },
    {
        Vector( 1882.32, 38.5, 3352.2 ), Vector( 2057.19, 38.5, 3600.8 ),
        Vector( 2348.94, 38.5, 3634.2 ), Vector( 2702.42, 38.5, 3596.4 ),
        Vector( 2958.96, 38.5, 3536.1 ), Vector( 2850.74, 38.5, 3271.2 ),
        Vector( 2574.52, 38.5, 3153.1 ), Vector( 2228.18, 38.5, 3163.7 )
    },
    {
        Vector( 3370.86, 38.5, 3168.21 ), Vector( 3716.03, 38.5, 3173.69 ),
        Vector( 4134.91, 38.5, 3114.27 ), Vector( 4377.67, 38.5, 2925.88 ),
        Vector( 4256.91, 38.5, 2757.03 ), Vector( 3608.09, 38.5, 2804.41 ),
        Vector( 3356.63, 38.5, 2981.32 )
    },
    {
        Vector( 3361.25, 38.5, 4514.96 ), Vector( 3444.64, 38.5, 4816.78 ),
        Vector( 3877.64, 38.5, 4743.20 ), Vector( 4204.82, 38.5, 4606.50 ),
        Vector( 4343.70, 38.5, 4335.83 ), Vector( 3953.05, 38.5, 4319.02 ),
        Vector( 3678.44, 38.5, 4357.00 )
    },
    {
        Vector( 2499.26, 38.5, 5438.61 ), Vector( 2386.26, 38.5, 5601.00 ),
        Vector( 2823.22, 38.5, 5641.15 ), Vector( 3231.40, 38.5, 5616.93 ),
        Vector( 3507.93, 38.5, 5623.40 ), Vector( 3739.07, 38.5, 5552.68 ),
        Vector( 3656.98, 38.5, 5349.38 ), Vector( 3313.82, 38.5, 5418.38 ),
        Vector( 3036.80, 38.5, 5422.12 ), Vector( 2750.28, 38.5, 5427.12 )
    }
}

function A1PremonitionsMission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.openingComplete = false
    self.premonitionCineComplete = false
    self.firstContactPlayed = false
    self.firstWaveStarted = false
    self.secondWaveSent = false
    self.premonitionCountdownStarted = false
    self.premonitionExists = false
    self.rescueActive = false
    self.wormTransit = nil
    self.wormTransitPollSerial = 0
    self.timers = { }
    self.patrols = { }
    self.reinforcements = { }
end

function A1PremonitionsMission:schedule( id, seconds, methodName )
    local timerName = "a1premonitions_" .. id
    local timer = Timer( timerName, seconds, Timer.State.Started )
    timer:hook( timerName .. "_hook", nil, function( timerObject, hook )
        if not self.ended then
            self[ methodName ]( self )
        end
    end, nil )
    self.timers[ id ] = timer
end

function A1PremonitionsMission:refreshStartingFleet( )
    if not isLive( self.enterprise ) then
        self.enterprise = findOneByOdf( "fente.odf", 1 )
    end

    if not isLive( self.constructor ) then
        self.constructor = findOneByOdf( "fconst.odf", 1 )
    end

    local cruisers = findByOdf( "fcruise1.odf", 1 )
    self.lincoln = cruisers[ 1 ]
    self.jackson = cruisers[ 2 ]
end

function A1PremonitionsMission:ensureStartingFleet( )
    self:refreshStartingFleet( )

    if not isLive( self.enterprise ) then
        self.enterprise = Entity.add( "fente.odf", 1, MAP_CRAFT_POS.ENTERPRISE )
    end
    if not isLive( self.constructor ) then
        self.constructor = Entity.add( "fconst.odf", 1, MAP_CRAFT_POS.CONSTRUCTOR )
    end

    local cruisers = findByOdf( "fcruise1.odf", 1 )
    if #cruisers < 1 then
        Entity.add( "fcruise1.odf", 1, MAP_CRAFT_POS.LINCOLN )
    end
    if #cruisers < 2 then
        Entity.add( "fcruise1.odf", 1, MAP_CRAFT_POS.JACKSON )
    end
    self:refreshStartingFleet( )
end

function A1PremonitionsMission:replaceMapDominionShips( )
    local mapDominion = findByOdf( "dcorvette.odf", 2 )
    for _, ship in pairs( mapDominion ) do
        safeRemove( ship )
    end

    local existing = findByOdf( "zjemdest.odf", 2 )
    self.patrols = { }
    for index, route in ipairs( DOMINION_ROUTES ) do
        local ship = takeNearestCraft( MAP_DOMINION_POSITIONS[ index ], existing )
        if not isLive( ship ) then
            ship = Entity.add( "zjemdest.odf", 2, MAP_DOMINION_POSITIONS[ index ] )
        end
        clampToA1CombatPlane( ship )
        local pathName = "DOM" .. index .. "PATROL"
        local hasNativePath = optionalPath( pathName ) ~= nil
        self.patrols[ index ] = {
            ship = ship,
            points = route,
            point = 2,
            nativePathName = hasNativePath and pathName or nil,
            nativePathMode = hasNativePath and "goto" or nil,
            stationaryTicks = 0,
            lastPosition = isLive( ship ) and ship.position or nil,
            attacking = false
        }
        if hasNativePath then
            print( "[A1Premonitions] Dominion " .. index ..
                   " using fed1.bzn path " .. pathName .. " on Y=38.5" )
        else
            print( "[A1Premonitions] Dominion " .. index ..
                   " missing native path; using recovered waypoint fallback" )
        end
    end
end

function A1PremonitionsMission:setup( )
    print( "[A1Premonitions] clean-room Federation1 DSL/DRL conversion loaded" )

    self.player = Player( 1 )
    self.dominion = Player( 2 )
    self.borg = Player( 3 )

    self.player:setRelation( self.dominion, Player.Relation.Enemy )
    self.dominion:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    self.dominion:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.dominion, Player.Relation.Enemy )

    self.player.resources.dilithium = 6000
    -- Prime the first objective set during setup so the mission UI has it as
    -- soon as the opening cineractive ends.  It becomes visible in
    -- finishOpeningCineractive(), matching the original mission timing.
    Objectives:load( "A1Premonitions_1.txt" )
    Objectives.visible = false
    self:ensureStartingFleet( )
    self:replaceMapDominionShips( )
    self:startOpeningCineractive( )
end

function A1PremonitionsMission:startOpeningCineractive( )
    self.phase = "opening"
    setCinematicGameplay( true )
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 7.0 )

    local entFlyby = optionalPath( "ENTFLYBY" )
    if entFlyby ~= nil and isLive( self.enterprise ) then
        -- Stock: CineractiveShot( "ENTFLYBY", 0, Enterprise ).
        Cineractive:shotPathPointObject( entFlyby, 0, self.enterprise )
    else
        Cineractive:lookFrom( POS.ENTFLYBY )
        Cineractive:lookAt( POS.ENTSTART )
    end

    Media:playSound( "Mfed25.wav" )
    safeOrder( self.enterprise, GameObject.Order.Go, POS.ENTSTART )
    safeOrder( self.lincoln, GameObject.Order.Go, POS.LINCOLNSTART )
    safeOrder( self.jackson, GameObject.Order.Go, POS.JACKSONSTART )
    safeOrder( self.constructor, GameObject.Order.Go, POS.FEDCON1START )

    self:schedule( "opening_title", 2.0, "showOpeningTitle" )
    self:schedule( "opening_second_shot", 22.0, "openingSecondShot" )
    self:schedule( "opening_third_shot", 25.0, "openingThirdShot" )
    self:schedule( "opening_done", 33.0, "finishOpeningCineractive" )
end

function A1PremonitionsMission:showOpeningTitle( )
    if self.phase == "opening" then
        UI:addTitle( "PREMONITIONS", 50, 50, 8.0, true )
    end
end

function A1PremonitionsMission:openingSecondShot( )
    if self.phase ~= "opening" then
        return
    end

    Media:playSound( "F1PIC1.wav" )
    Cineractive:fadeOut( 2.0 )
    if isLive( self.enterprise ) then
        -- Stock first-shot camera: Enterprise -> Enterprise, then ENTPAN at 0.2.
        Cineractive:shotObjectObject( self.enterprise, self.enterprise )
        local entPan = optionalPath( "ENTPAN" )
        if entPan ~= nil then
            Cineractive:setCameraPathOffset( entPan, 0.2 )
        else
            Cineractive:setCameraOffset( Vector( 168.0, 48.0, -300.0 ) )
        end
    end
end

function A1PremonitionsMission:openingThirdShot( )
    if self.phase ~= "opening" then
        return
    end

    Cineractive:fadeIn( 3.0 )
    local zoomOut = optionalPath( "ZOOMOUT" )
    local camera1 = optionalPath( "Camera_1" )
    if zoomOut ~= nil and camera1 ~= nil then
        -- Stock: CineractiveShot( "ZOOMOUT", 0.8, "Camera_1", 0 ).
        Cineractive:shotPathPathPoint( zoomOut, 0.8, camera1, 0 )
    else
        Cineractive:lookFrom( POS.ZOOMOUT )
        Cineractive:lookAt( POS.CAMERA1 )
    end
    Media:playSound( "Mfed5.wav" )
end

function A1PremonitionsMission:issuePatrolOrder( patrol )
    if not isLive( patrol.ship ) or patrol.attacking then
        return
    end

    if patrol.nativePathName ~= nil then
        -- Federation1S.dsl sends each Dominion ship to its named BZN path.
        -- These helpers route through the live ScriptInterface vtable instead
        -- of MMM's stock-A2 absolute GameObject::giveOrder addresses.
        local ok = false
        if patrol.nativePathMode == "patrol" then
            ok = pcall( function( )
                patrol.ship:missionPatrolPath( patrol.nativePathName )
            end )
        else
            ok = pcall( function( )
                patrol.ship:missionGotoPath( patrol.nativePathName )
            end )
        end
        if ok then
            patrol.lastPosition = patrol.ship.position
            patrol.stationaryTicks = 0
            return
        end

        patrol.nativePathName = nil
        patrol.nativePathMode = nil
    end

    -- Diagnostic fallback for a map that has lost the named path entirely.
    safeOrder( patrol.ship, GameObject.Order.Go, patrol.points[ patrol.point ] )
end

function A1PremonitionsMission:finishOpeningCineractive( )
    if self.openingComplete then
        return
    end

    self.openingComplete = true
    self.phase = "dominion"
    Cineractive.active = false
    setCinematicGameplay( false )
    self:refreshStartingFleet( )

    safeOrder( self.enterprise, GameObject.Order.Stop, nil )
    safeOrder( self.lincoln, GameObject.Order.Stop, nil )
    safeOrder( self.jackson, GameObject.Order.Stop, nil )
    safeOrder( self.constructor, GameObject.Order.Stop, nil )

    for _, patrol in ipairs( self.patrols ) do
        self:issuePatrolOrder( patrol )
    end

    Objectives:load( "A1Premonitions_1.txt" )
    Objectives.visible = true
end

function A1PremonitionsMission:updateDominionPatrols( playerCraft )
    for _, patrol in ipairs( self.patrols ) do
        if isLive( patrol.ship ) then
            -- Native Fleet Ops movement remains 3D even for an A1 flat path.
            -- Clamp every gameplay tick, including attack mode, so the A1
            -- tactical plane and weapon reach remain faithful.
            clampToA1CombatPlane( patrol.ship )
        end
        if isLive( patrol.ship ) and not patrol.attacking then
            local attackerTarget = nearestCraft( patrol.ship.position, playerCraft, 350.0 )
            if attackerTarget ~= nil then
                patrol.attacking = true
                safeOrder( patrol.ship, GameObject.Order.Stop, nil )
                safeOrder( patrol.ship, GameObject.Order.Attack, attackerTarget )
            elseif patrol.nativePathName ~= nil then
                -- Watch the first live-interface path command. If Goto(path)
                -- remains stationary for several mission ticks, retry the SAME
                -- fed1.bzn route through ScriptInterface::Patrol. This gives us
                -- a useful compatibility fallback without inventing a route.
                local current = patrol.ship.position
                if patrol.lastPosition ~= nil and
                   distanceSquared( current, patrol.lastPosition ) < 25.0 then
                    patrol.stationaryTicks = patrol.stationaryTicks + 1
                else
                    patrol.stationaryTicks = 0
                    patrol.lastPosition = current
                end

                if patrol.stationaryTicks >= 12 and patrol.nativePathMode == "goto" then
                    patrol.nativePathMode = "patrol"
                    print( "[A1Premonitions] " .. patrol.nativePathName ..
                           " Goto stalled; retrying through live Patrol" )
                    self:issuePatrolOrder( patrol )
                end
            else
                local patrolTarget = patrol.points[ patrol.point ]
                if distanceSquared( patrol.ship.position, patrolTarget ) <= 10000.0 then
                    patrol.point = patrol.point + 1
                    if patrol.point > #patrol.points then
                        patrol.point = 1
                    end
                    self:issuePatrolOrder( patrol )
                end
            end
        end
    end
end

function A1PremonitionsMission:checkFirstContact( playerCraft )
    if self.firstContactPlayed then
        return
    end

    for _, patrol in ipairs( self.patrols ) do
        if isLive( patrol.ship ) and nearestCraft( patrol.ship.position, playerCraft, 300.0 ) ~= nil then
            self.firstContactPlayed = true
            Media:playSound( "F1PIC2.wav" )
            return
        end
    end
end

function A1PremonitionsMission:hasStationPair( )
    return #findByOdf( "fbase.odf", 1 ) > 0
        and #findByOdf( "fmining.odf", 1 ) > 0
end

function A1PremonitionsMission:nearestPlayerTarget( ship )
    if not isLive( ship ) then
        return self.enterprise
    end
    return nearestCraft( ship.position, craftForPlayer( 1 ), 100000.0 ) or self.enterprise
end

function A1PremonitionsMission:startDominionWave( )
    if self.firstWaveStarted then
        return
    end

    self.firstWaveStarted = true
    Objectives:load( "A1Premonitions_2.txt" )
    Objectives.visible = true
    Media:playSound( "F1PIC3.wav" )

    local moreJem1 = Entity.add( "zjemdest.odf", 2, POS.REINFORCE1 )
    local moreJem2 = Entity.add( "zjemdest.odf", 2, POS.REINFORCE2 )
    self.reinforcements = { moreJem1, moreJem2 }

    safeOrder( self.patrols[ 1 ].ship, GameObject.Order.Attack, self:nearestPlayerTarget( self.patrols[ 1 ].ship ) )
    safeOrder( self.patrols[ 2 ].ship, GameObject.Order.Attack, self:nearestPlayerTarget( self.patrols[ 2 ].ship ) )
    self.patrols[ 1 ].attacking = true
    self.patrols[ 2 ].attacking = true
    safeOrder( moreJem1, GameObject.Order.Attack, self:nearestPlayerTarget( moreJem1 ) )
    safeOrder( moreJem2, GameObject.Order.Attack, self:nearestPlayerTarget( moreJem2 ) )

    self:schedule( "second_dominion_wave", 120.0, "sendSecondDominionWave" )
end

function A1PremonitionsMission:sendSecondDominionWave( )
    if self.phase ~= "dominion" or self.secondWaveSent then
        return
    end

    self.secondWaveSent = true
    for index = 3, 6 do
        local patrol = self.patrols[ index ]
        if patrol ~= nil then
            patrol.attacking = true
            safeOrder( patrol.ship, GameObject.Order.Attack, self:nearestPlayerTarget( patrol.ship ) )
        end
    end
end

function A1PremonitionsMission:startPremonitionCountdown( )
    if self.premonitionCountdownStarted then
        return
    end

    self.premonitionCountdownStarted = true
    Media:playSound( "F1LIE2.wav" )
    self:schedule( "premonition_delay", 7.0, "startPremonitionCineractive" )
end

function A1PremonitionsMission:startPremonitionCineractive( )
    if self.phase ~= "dominion" or self.ending then
        return
    end

    self.phase = "premonition_cine"
    setCinematicGameplay( true )
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:lookFrom( POS.WORMSHOT )
    Cineractive:lookAt( POS.WORMEXIT )

    self.wormIn = Entity.add( "mprmgate.odf", 0, POS.WORMENTER )
    self.wormOut = Entity.add( "mprmgate.odf", 0, POS.WORMEXIT )
    self.premonition = Entity.add( "fprem.odf", 1, POS.PREMOCREATE )
    self.borg1 = Entity.add( "bcruise1.odf", 3, POS.CREATEBORG1 )
    self.borg2 = Entity.add( "bcruise1.odf", 3, POS.CREATEBORG2 )
    self.premonitionExists = true

    setInvincible( self.premonition, true )
    setInvincible( self.borg1, true )
    setInvincible( self.borg2, true )

    if isLive( self.wormIn ) and isLive( self.wormOut ) then
        pcall( function( ) self.wormIn.link = self.wormOut end )
        pcall( function( ) self.wormIn.deleteOnTransport = false end )
        pcall( function( ) self.wormOut.deleteOnTransport = false end )
    end

    -- Megadroid's original Premonitions implementation lets Armada perform
    -- ordinary wormhole navigation: order the craft TO the entrance and let
    -- the linked wormholes take over. Forcing CMD_WORMHOLE on all three craft
    -- at once made FO and the mission script fight over their movement.
    self.wormTransit = {
        premonition = false,
        borg1 = false,
        borg2 = false,
        premonitionSettled = false,
        borg1Settled = false,
        borg2Settled = false
    }

    local wormTarget = isLive( self.wormIn ) and self.wormIn or POS.WORMENTER
    safeOrder( self.premonition, GameObject.Order.Go, wormTarget )

    -- Stagger the pursuing Borg so they do not enter/exit on top of the
    -- Premonition or one another.
    self:schedule( "borg1_worm_entry", 0.8, "startBorg1WormTransit" )
    self:schedule( "borg2_worm_entry", 1.6, "startBorg2WormTransit" )

    Media:playSound( "Mkli45a.wav" )

    self:scheduleWormTransitPoll( 0.25 )
    -- Emergency recovery only. Unlike the previous eight-second fallback this
    -- never touches craft which have already crossed naturally.
    self:schedule( "worm_transit_failsafe", 14.0, "forceWormTransitFallback" )
end

function A1PremonitionsMission:startBorg1WormTransit( )
    if self.phase ~= "premonition_cine" or not isLive( self.borg1 ) then
        return
    end

    local target = isLive( self.wormIn ) and self.wormIn or POS.WORMENTER
    safeOrder( self.borg1, GameObject.Order.Go, target )
end

function A1PremonitionsMission:startBorg2WormTransit( )
    if self.phase ~= "premonition_cine" or not isLive( self.borg2 ) then
        return
    end

    local target = isLive( self.wormIn ) and self.wormIn or POS.WORMENTER
    safeOrder( self.borg2, GameObject.Order.Go, target )
end

function A1PremonitionsMission:scheduleWormTransitPoll( delay )
    if self.phase ~= "premonition_cine" then
        return
    end

    self.wormTransitPollSerial = self.wormTransitPollSerial + 1
    self:schedule( "worm_poll_" .. self.wormTransitPollSerial, delay or 0.25, "pollWormTransit" )
end

function A1PremonitionsMission:pollWormTransit( )
    if self.phase ~= "premonition_cine" or self.wormTransit == nil then
        return
    end

    if not self.wormTransit.premonition and crossedToExitSide( self.premonition ) then
        self.wormTransit.premonition = true
        self:schedule( "premonition_exit_settle", 0.75, "finishPremonitionTransit" )
    end

    if not self.wormTransit.borg1 and crossedToExitSide( self.borg1 ) then
        self.wormTransit.borg1 = true
        self:schedule( "borg1_exit_settle", 0.65, "finishBorg1Transit" )
    end

    if not self.wormTransit.borg2 and crossedToExitSide( self.borg2 ) then
        self.wormTransit.borg2 = true
        self:schedule( "borg2_exit_settle", 0.65, "finishBorg2Transit" )
    end

    if not ( self.wormTransit.premonition and self.wormTransit.borg1 and self.wormTransit.borg2 ) then
        self:scheduleWormTransitPoll( 0.25 )
    end
end

function A1PremonitionsMission:finishPremonitionTransit( )
    if self.phase ~= "premonition_cine" or self.wormTransit == nil
        or self.wormTransit.premonitionSettled then
        return
    end

    self.wormTransit.premonitionSettled = true
    setInvincible( self.premonition, true )
    damagePremonitionSystems( self.premonition )
    safeOrder( self.premonition, GameObject.Order.Go, POS.PREMOSTART )

    -- Start the exterior rescue shot only after the real Premonition has
    -- emerged and had a fraction of a second for FO's physics to settle.
    self:schedule( "premonition_wide_shot", 0.5, "premonitionWideShot" )
end

function A1PremonitionsMission:finishBorg1Transit( )
    if self.phase ~= "premonition_cine" or self.wormTransit == nil
        or self.wormTransit.borg1Settled then
        return
    end

    self.wormTransit.borg1Settled = true
    setInvincible( self.borg1, true )
    safeOrder( self.borg1, GameObject.Order.Go, POS.PREMOATTACK1 )
end

function A1PremonitionsMission:finishBorg2Transit( )
    if self.phase ~= "premonition_cine" or self.wormTransit == nil
        or self.wormTransit.borg2Settled then
        return
    end

    self.wormTransit.borg2Settled = true
    setInvincible( self.borg2, true )
    safeOrder( self.borg2, GameObject.Order.Go, POS.PREMOATTACK2 )
end

function A1PremonitionsMission:moveThroughFallback( entity, odf, playerNumber, destination )
    if crossedToExitSide( entity ) then
        return entity
    end

    safeRemove( entity )
    return Entity.add( odf, playerNumber, destination )
end

function A1PremonitionsMission:forceWormTransitFallback( )
    if self.phase ~= "premonition_cine" or self.wormTransit == nil then
        return
    end

    -- This is now a genuine last-resort recovery rather than part of the
    -- normal choreography. Natural transit is left completely untouched.
    if not self.wormTransit.premonition then
        self.premonition = self:moveThroughFallback(
            self.premonition, "fprem.odf", 1, POS.PREMOSTART )
        self.wormTransit.premonition = true
        self:finishPremonitionTransit( )
    end

    if not self.wormTransit.borg1 then
        self.borg1 = self:moveThroughFallback(
            self.borg1, "bcruise1.odf", 3, POS.PREMOATTACK1 )
        self.wormTransit.borg1 = true
        self:finishBorg1Transit( )
    end

    if not self.wormTransit.borg2 then
        self.borg2 = self:moveThroughFallback(
            self.borg2, "bcruise1.odf", 3, POS.PREMOATTACK2 )
        self.wormTransit.borg2 = true
        self:finishBorg2Transit( )
    end
end

function A1PremonitionsMission:premonitionWideShot( )
    if self.phase ~= "premonition_cine" then
        return
    end

    Media:playSound( "F1PIC4.wav" )
    local premoShot = optionalPath( "PREMOSHOT" )
    local wormExit = optionalPath( "WORMEXIT" )
    if premoShot ~= nil and wormExit ~= nil then
        -- Stock: CineractiveShot( "PREMOSHOT", 0, "WORMEXIT", 0 ).
        Cineractive:shotPathPointPathPoint( premoShot, 0, wormExit, 0 )
    else
        Cineractive:lookFrom( POS.PREMOSHOT )
        Cineractive:lookAt( POS.WORMEXIT )
    end
    self:schedule( "premonition_bridge", 10.0, "premonitionBridgeDistress" )
end

function A1PremonitionsMission:premonitionBridgeDistress( )
    if self.phase ~= "premonition_cine" then
        return
    end

    if isLive( self.enterprise ) then
        Cineractive:shotObjectObject( self.enterprise, self.enterprise )
        local entPan = optionalPath( "ENTPAN" )
        if entPan ~= nil then
            -- Stock Premonition bridge lead-in uses ENTPAN at 0.6.
            Cineractive:setCameraPathOffset( entPan, 0.6 )
        else
            Cineractive:setCameraOffset( Vector( 168.0, 48.0, -300.0 ) )
        end
    end

    -- Prefer Armada's original exported bridge-movie route. Generic
    -- PlayCinematicMovie uses a different embedded texture path in Fleet Ops
    -- and wraps 400x200 A1 bridge videos, producing the visible tiling.
    playA1BridgeMovie( "F1DEM1.bik" )
    self:schedule( "premonition_cine_done", 10.0, "finishPremonitionCineractive" )
end

function A1PremonitionsMission:finishPremonitionCineractive( )
    if self.premonitionCineComplete then
        return
    end

    self.premonitionCineComplete = true
    self.phase = "rescue"
    self.rescueActive = true
    stopA1BridgeMovie( )
    Cineractive.active = false
    setCinematicGameplay( false )
    Media:playSound( "F1LIE4.wav" )

    safeRemove( self.wormIn )
    safeRemove( self.wormOut )
    setInvincible( self.premonition, false )
    setInvincible( self.borg1, false )
    setInvincible( self.borg2, false )
    preparePremonitionRescueState( self.premonition )

    safeOrder( self.borg1, GameObject.Order.Attack, self.premonition )
    safeOrder( self.borg2, GameObject.Order.Attack, self.premonition )
    Objectives:load( "A1Premonitions_3.txt" )
    Objectives.visible = true
    self:startPremonitionIndicator( )
end

function A1PremonitionsMission:startPremonitionIndicator( )
    if not isLive( self.premonition ) then
        return
    end

    pcall( function( ) UI:addMinimapObjectMark( self.premonition, 5, 0.2 ) end )

    local timer = Timer( "a1premonitions_indicator", 2.0, Timer.State.Started )
    timer.repeats = true
    timer:hook( "a1premonitions_indicator_hook", nil, function( timerObject, hook )
        if self.ended or self.ending or not self.rescueActive or not isLive( self.premonition ) then
            timerObject:stop( )
            return
        end
        pcall( function( ) UI:addMinimapObjectMark( self.premonition, 5, 0.2 ) end )
    end, nil )
    self.timers.premonition_indicator = timer
end

function A1PremonitionsMission:quiesceMissionTimers( )
    -- Mission:finish() can cause MMM/Lua teardown immediately. If that happens
    -- while a Timer hook is still unwinding, luabind can touch a dead Lua VM.
    -- Stop and release every mission timer first while the VM is unquestionably
    -- alive, then let the native mission result happen on a short delay.
    for _, timer in pairs( self.timers ) do
        if timer ~= nil then
            pcall( function( ) timer:stop( ) end )
        end
    end
    self.timers = { }

    -- MMM's Timer::stop() historically forgets to erase stopped timers from
    -- its global vector. stopAll() does clear that vector, which is important
    -- before mission teardown.
    pcall( function( ) Timer.stopAll( ) end )
end

function A1PremonitionsMission:failMission( message )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "loss"
    setCinematicGameplay( true )
    Cineractive.skippable = false
    Cineractive.active = true
    Cineractive:fadeIn( 1.0 )
    UI:addSubtitle( message, 50, 85, 11.5, true )
    Media:playSound( "Mfed10.wav" )

    local focus = self.enterprise
    if message == "THE PREMONITION HAS BEEN DESTROYED" then
        focus = self.premonition
    elseif message == "THE CONSTRUCTION SHIP HAS BEEN DESTROYED" then
        focus = self.constructor
    end
    if isLive( focus ) then
        Cineractive:shotObjectObject( focus, focus )
        local pan = nil
        if message == "THE PREMONITION HAS BEEN DESTROYED" then
            pan = optionalPath( "PREMOPAN" )
        elseif message == "THE ENTERPRISE HAS BEEN DESTROYED" then
            pan = optionalPath( "ENTPAN" )
        end
        if pan ~= nil then
            Cineractive:setCameraPathOffset( pan, 0.2 )
        else
            Cineractive:setCameraOffset( Vector( 200, 100, -250 ) )
        end
        Cineractive:lookAt( focus )
    end

    self:schedule( "mission_failure", 11.5, "finishFailure" )
end

function A1PremonitionsMission:finishFailure( )
    if self.ended then
        return
    end
    self.ended = true
    Cineractive.active = false
    self:quiesceMissionTimers( )

    -- Do not tear the mission down inside the Lua Timer callback that invoked
    -- this function. A short native delay lets luabind unwind cleanly first.
    Mission:finish( false, 0.5 )
end

function A1PremonitionsMission:startWinSequence( )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "win_pending"
    Media:playSound( "F1LIE5.wav" )
    self:schedule( "win_cine_delay", 6.0, "startWinCineractive" )
end

function A1PremonitionsMission:startWinCineractive( )
    if self.phase ~= "win_pending" then
        return
    end

    self.phase = "win_cine"
    setCinematicGameplay( true )
    Cineractive.skippable = true
    Cineractive.active = true

    safeOrder( self.lincoln, GameObject.Order.Go, POS.LINCOLNSTART )
    safeOrder( self.jackson, GameObject.Order.Go, POS.JACKSONSTART )

    -- Stock timer_for_win_cin displays the Federation bridge and plays this
    -- through PlayBridgeMovie. Use the original exported bridge route when
    -- ArmadaL retains it, with the generic cinematic path only as fallback.
    playA1BridgeMovie( "F1DEM2.bik" )
    self:schedule( "premonition_information", 53.0, "toTheRescue" )
end

function A1PremonitionsMission:toTheRescue( )
    if self.phase ~= "win_cine" then
        return
    end

    self.phase = "win_rescue"
    stopA1BridgeMovie( )
    Media:stopSounds( )
    Media:playSound( "F1PIC5.wav" )

    if isLive( self.enterprise ) then
        local entToPremo = optionalPath( "ENTTOPREMO" )
        if entToPremo ~= nil then
            -- Stock win_cin teleports the Enterprise onto this path before the shot.
            self.enterprise:setPositionOnPath( entToPremo )
        else
            self.enterprise.position = POS.ENTTOPREMO
        end
        if isLive( self.premonition ) then
            self.enterprise:pointAt( self.premonition )
        end
    end

    local premoEntPoint = optionalPath( "PREMOENTPOINT" )
    if premoEntPoint ~= nil and isLive( self.enterprise ) then
        -- Stock: CineractiveShot( "PREMOENTPOINT", 0, Enterprise ).
        Cineractive:shotPathPointObject( premoEntPoint, 0, self.enterprise )
    else
        Cineractive:lookFrom( POS.PREMOENTPOINT )
        if isLive( self.enterprise ) then
            Cineractive:lookAt( self.enterprise )
        else
            Cineractive:lookAt( POS.ENTTOPREMO )
        end
    end
    Cineractive:fadeOut( 3.0 )
    self:schedule( "mission_success", 12.0, "finishSuccess" )
end

function A1PremonitionsMission:finishSuccess( )
    if self.ended then
        return
    end
    self.ended = true
    stopA1BridgeMovie( )
    Cineractive.active = false
    self:quiesceMissionTimers( )

    -- As with failure, finish outside the active MMM Timer callback.
    Mission:finish( true, 0.5 )
end

function A1PremonitionsMission:tick( )
    if self.ending or self.ended then
        return
    end

    self:refreshStartingFleet( )

    if self.openingComplete and entityCompromised( self.enterprise ) then
        self:failMission( "THE ENTERPRISE HAS BEEN DESTROYED" )
        return
    end

    if self.premonitionExists and entityCompromised( self.premonition ) then
        self:failMission( "THE PREMONITION HAS BEEN DESTROYED" )
        return
    end

    if self.openingComplete
        and #findByOdf( "fconst.odf", 1 ) == 0
        and #findByOdf( "fbase.odf", 1 ) == 0
        and #findByOdf( "fmining.odf", 1 ) == 0 then
        self:failMission( "THE CONSTRUCTION SHIP HAS BEEN DESTROYED" )
        return
    end

    if self.phase == "dominion" then
        local playerCraft = craftForPlayer( 1 )
        self:checkFirstContact( playerCraft )
        self:updateDominionPatrols( playerCraft )

        local dominionCount = #findByOdf( "zjemdest.odf", 2 )
        if self:hasStationPair( ) and dominionCount > 0 and not self.firstWaveStarted then
            self:startDominionWave( )
        elseif self:hasStationPair( ) and dominionCount == 0 then
            self:startPremonitionCountdown( )
        end
    elseif self.phase == "rescue" then
        if self:hasStationPair( )
            and #findByOdf( "zjemdest.odf", 2 ) == 0
            and #findByOdf( "bcruise1.odf", 3 ) == 0 then
            self:startWinSequence( )
        end
    end
end

function A1PremonitionsMission:update( )
    self:tick( )
end

function A1PremonitionsMission:cineractiveUpdate( )
    -- Timer hooks drive the original cinematic action sequence. Gameplay rules
    -- remain paused while a cineractive is active, matching the A1 mission.
end

function A1PremonitionsMission:cineractiveFinish( forced )
    if not forced then
        return
    end

    if self.phase == "opening" then
        self:finishOpeningCineractive( )
    elseif self.phase == "premonition_cine" then
        stopA1BridgeMovie( )
        self:forceWormTransitFallback( )
        self:finishPremonitionCineractive( )
    elseif self.phase == "win_cine" then
        stopA1BridgeMovie( )
        self:toTheRescue( )
    end
end

MMM.register( A1PremonitionsMission( ) )
