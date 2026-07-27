-- CLEAN-ROOM STAR TREK: ARMADA FEDERATION 1 CONVERSION TEST
--
-- Behaviour source:
--   Federation1S.dsl, Federation1R.drl, fed1.bzn, and the original A1 media.
-- Megadroid Mission Mod tutorials were used only to learn the MMM Lua API.
-- No existing Premonitions Lua recreation was used as conversion evidence.

class 'A1PremonTestMission'

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
    Vector( 1577.56, 0, 3009.6 ),
    Vector( 5188.47, 0, 2322.5 ),
    Vector( 1850.77, 0, 3846.6 ),
    Vector( 3643.97, 0, 3165.9 ),
    Vector( 4569.11, 0, 4883 ),
    Vector( 3824.28, 0, 6088 )
}

-- A1 stores the map plane around Y=38.5. These coordinates are the recovered
-- A1 patrol points translated by -38.5 into the A2/FO vertical coordinate.
local DOMINION_ROUTES = {
    {
        Vector( 1740.78, 0, 2485.6 ), Vector( 1795.94, 0, 2231.3 ),
        Vector( 2160.51, 0, 1951.5 ), Vector( 2602.83, 0, 1912.1 ),
        Vector( 2774.81, 0, 2221.9 ), Vector( 2528.72, 0, 2440.6 ),
        Vector( 2254.35, 0, 2666.1 ), Vector( 1897.13, 0, 2705.7 )
    },
    {
        Vector( 3509.32, 0, 2164.8 ), Vector( 3500.56, 0, 2518.5 ),
        Vector( 3846.18, 0, 2645.9 ), Vector( 4224.48, 0, 2634.3 ),
        Vector( 4585.11, 0, 2588.5 ), Vector( 4912.39, 0, 2454.9 ),
        Vector( 4998.71, 0, 2185.6 ), Vector( 4794.36, 0, 2047.8 ),
        Vector( 4507.92, 0, 2052.2 ), Vector( 4155.10, 0, 2050.3 ),
        Vector( 3738.41, 0, 1982.4 )
    },
    {
        Vector( 1882.32, 0, 3352.2 ), Vector( 2057.19, 0, 3600.8 ),
        Vector( 2348.94, 0, 3634.2 ), Vector( 2702.42, 0, 3596.4 ),
        Vector( 2958.96, 0, 3536.1 ), Vector( 2850.74, 0, 3271.2 ),
        Vector( 2574.52, 0, 3153.1 ), Vector( 2228.18, 0, 3163.7 )
    },
    {
        Vector( 3370.86, 0, 3168.21 ), Vector( 3716.03, 0, 3173.69 ),
        Vector( 4134.91, 0, 3114.27 ), Vector( 4377.67, 0, 2925.88 ),
        Vector( 4256.91, 0, 2757.03 ), Vector( 3608.09, 0, 2804.41 ),
        Vector( 3356.63, 0, 2981.32 )
    },
    {
        Vector( 3361.25, 0, 4514.96 ), Vector( 3444.64, 0, 4816.78 ),
        Vector( 3877.64, 0, 4743.20 ), Vector( 4204.82, 0, 4606.50 ),
        Vector( 4343.70, 0, 4335.83 ), Vector( 3953.05, 0, 4319.02 ),
        Vector( 3678.44, 0, 4357.00 )
    },
    {
        Vector( 2499.26, 0, 5438.61 ), Vector( 2386.26, 0, 5601.00 ),
        Vector( 2823.22, 0, 5641.15 ), Vector( 3231.40, 0, 5616.93 ),
        Vector( 3507.93, 0, 5623.40 ), Vector( 3739.07, 0, 5552.68 ),
        Vector( 3656.98, 0, 5349.38 ), Vector( 3313.82, 0, 5418.38 ),
        Vector( 3036.80, 0, 5422.12 ), Vector( 2750.28, 0, 5427.12 )
    }
}

function A1PremonTestMission:__init( )
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
    self.timers = { }
    self.patrols = { }
    self.reinforcements = { }
end

function A1PremonTestMission:schedule( id, seconds, methodName )
    local timerName = "a1pt_" .. id
    local timer = Timer( timerName, seconds, Timer.State.Started )
    timer:hook( timerName .. "_hook", nil, function( timerObject, hook )
        if not self.ended then
            self[ methodName ]( self )
        end
    end, nil )
    self.timers[ id ] = timer
end

function A1PremonTestMission:refreshStartingFleet( )
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

function A1PremonTestMission:ensureStartingFleet( )
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

function A1PremonTestMission:replaceMapDominionShips( )
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
        self.patrols[ index ] = {
            ship = ship,
            points = route,
            point = 2,
            attacking = false
        }
    end
end

function A1PremonTestMission:setup( )
    print( "[A1PremonTest] clean-room Federation1 DSL/DRL conversion loaded" )

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
    Objectives:load( "A1PremonTest_1.txt" )
    Objectives.visible = false
    self:ensureStartingFleet( )
    self:replaceMapDominionShips( )
    self:startOpeningCineractive( )
end

function A1PremonTestMission:startOpeningCineractive( )
    self.phase = "opening"
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 7.0 )
    Cineractive:lookFrom( POS.ENTFLYBY )
    Cineractive:lookAt( POS.ENTSTART )

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

function A1PremonTestMission:showOpeningTitle( )
    if self.phase == "opening" then
        UI:addTitle( "PREMONITIONS", 50, 50, 8.0, true )
    end
end

function A1PremonTestMission:openingSecondShot( )
    if self.phase ~= "opening" then
        return
    end

    Media:playSound( "F1PIC1.wav" )
    Cineractive:fadeOut( 2.0 )
    if isLive( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( 168.0, 48.0, -300.0 ) )
    end
end

function A1PremonTestMission:openingThirdShot( )
    if self.phase ~= "opening" then
        return
    end

    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( POS.ZOOMOUT )
    Cineractive:lookAt( POS.CAMERA1 )
    Media:playSound( "Mfed5.wav" )
end

function A1PremonTestMission:issuePatrolOrder( patrol )
    if isLive( patrol.ship ) and not patrol.attacking then
        safeOrder( patrol.ship, GameObject.Order.Go, patrol.points[ patrol.point ] )
    end
end

function A1PremonTestMission:finishOpeningCineractive( )
    if self.openingComplete then
        return
    end

    self.openingComplete = true
    self.phase = "dominion"
    Cineractive.active = false
    self:refreshStartingFleet( )

    safeOrder( self.enterprise, GameObject.Order.Stop, nil )
    safeOrder( self.lincoln, GameObject.Order.Stop, nil )
    safeOrder( self.jackson, GameObject.Order.Stop, nil )
    safeOrder( self.constructor, GameObject.Order.Stop, nil )

    for _, patrol in ipairs( self.patrols ) do
        self:issuePatrolOrder( patrol )
    end

    Objectives:load( "A1PremonTest_1.txt" )
    Objectives.visible = true
end

function A1PremonTestMission:updateDominionPatrols( playerCraft )
    for _, patrol in ipairs( self.patrols ) do
        if isLive( patrol.ship ) and not patrol.attacking then
            local attackerTarget = nearestCraft( patrol.ship.position, playerCraft, 350.0 )
            if attackerTarget ~= nil then
                patrol.attacking = true
                safeOrder( patrol.ship, GameObject.Order.Stop, nil )
                safeOrder( patrol.ship, GameObject.Order.Attack, attackerTarget )
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

function A1PremonTestMission:checkFirstContact( playerCraft )
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

function A1PremonTestMission:hasStationPair( )
    return #findByOdf( "fbase.odf", 1 ) > 0
        and #findByOdf( "fmining.odf", 1 ) > 0
end

function A1PremonTestMission:startDominionWave( )
    if self.firstWaveStarted then
        return
    end

    self.firstWaveStarted = true
    Objectives:load( "A1PremonTest_2.txt" )
    Objectives.visible = true
    Media:playSound( "F1PIC3.wav" )

    local moreJem1 = Entity.add( "zjemdest.odf", 2, POS.REINFORCE1 )
    local moreJem2 = Entity.add( "zjemdest.odf", 2, POS.REINFORCE2 )
    self.reinforcements = { moreJem1, moreJem2 }

    safeOrder( self.patrols[ 1 ].ship, GameObject.Order.Attack, self.enterprise )
    safeOrder( self.patrols[ 2 ].ship, GameObject.Order.Attack, self.enterprise )
    self.patrols[ 1 ].attacking = true
    self.patrols[ 2 ].attacking = true
    safeOrder( moreJem1, GameObject.Order.Attack, self.enterprise )
    safeOrder( moreJem2, GameObject.Order.Attack, self.enterprise )

    self:schedule( "second_dominion_wave", 120.0, "sendSecondDominionWave" )
end

function A1PremonTestMission:sendSecondDominionWave( )
    if self.phase ~= "dominion" or self.secondWaveSent then
        return
    end

    self.secondWaveSent = true
    for index = 3, 6 do
        local patrol = self.patrols[ index ]
        if patrol ~= nil then
            patrol.attacking = true
            safeOrder( patrol.ship, GameObject.Order.Attack, self.enterprise )
        end
    end
end

function A1PremonTestMission:startPremonitionCountdown( )
    if self.premonitionCountdownStarted then
        return
    end

    self.premonitionCountdownStarted = true
    Media:playSound( "F1LIE2.wav" )
    self:schedule( "premonition_delay", 7.0, "startPremonitionCineractive" )
end

function A1PremonTestMission:startPremonitionCineractive( )
    if self.phase ~= "dominion" or self.ending then
        return
    end

    self.phase = "premonition_cine"
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

    local wormTarget = POS.WORMENTER
    if isLive( self.wormIn ) then
        wormTarget = self.wormIn
    end
    safeOrder( self.premonition, GameObject.Order.Go, wormTarget )
    safeOrder( self.borg1, GameObject.Order.Go, wormTarget )
    safeOrder( self.borg2, GameObject.Order.Go, wormTarget )
    Media:playSound( "Mkli45a.wav" )

    self:schedule( "worm_transit_fallback", 8.0, "completeWormTransit" )
    self:schedule( "premonition_wide_shot", 10.0, "premonitionWideShot" )
end

function A1PremonTestMission:moveThroughFallback( entity, odf, playerNumber, destination )
    if isLive( entity ) and distanceSquared( entity.position, POS.WORMEXIT ) <= 160000.0 then
        return entity
    end

    safeRemove( entity )
    return Entity.add( odf, playerNumber, destination )
end

function A1PremonTestMission:completeWormTransit( )
    if self.phase ~= "premonition_cine" then
        return
    end

    -- MMM does not document how two dynamically-created A1 wormhole_obj
    -- instances are paired. Preserve natural transit if it worked; otherwise
    -- recreate the ships at the recovered A1 exit positions so the rule graph
    -- can continue instead of hanging here.
    self.premonition = self:moveThroughFallback( self.premonition, "fprem.odf", 1, POS.PREMOSTART )
    self.borg1 = self:moveThroughFallback( self.borg1, "bcruise1.odf", 3, POS.PREMOATTACK1 )
    self.borg2 = self:moveThroughFallback( self.borg2, "bcruise1.odf", 3, POS.PREMOATTACK2 )

    setInvincible( self.premonition, true )
    setInvincible( self.borg1, true )
    setInvincible( self.borg2, true )
    setShields( self.premonition, 0.3 )
    safeOrder( self.premonition, GameObject.Order.Go, POS.PREMOSTART )
    safeOrder( self.borg1, GameObject.Order.Go, POS.PREMOATTACK1 )
    safeOrder( self.borg2, GameObject.Order.Go, POS.PREMOATTACK2 )
end

function A1PremonTestMission:premonitionWideShot( )
    if self.phase ~= "premonition_cine" then
        return
    end

    Media:playSound( "F1PIC4.wav" )
    Cineractive:lookFrom( POS.PREMOSHOT )
    Cineractive:lookAt( POS.WORMEXIT )
    self:schedule( "premonition_bridge", 10.0, "premonitionBridgeDistress" )
end

function A1PremonTestMission:premonitionBridgeDistress( )
    if self.phase ~= "premonition_cine" then
        return
    end

    if isLive( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( 168.0, 48.0, -300.0 ) )
    end
    Media:playSound( "F1DEM1.wav" )
    UI:addSubtitle( "Distress call received from the USS Premonition.", 50, 85, 10.0, true )
    self:schedule( "premonition_cine_done", 10.0, "finishPremonitionCineractive" )
end

function A1PremonTestMission:finishPremonitionCineractive( )
    if self.premonitionCineComplete then
        return
    end

    self.premonitionCineComplete = true
    self.phase = "rescue"
    self.rescueActive = true
    Cineractive.active = false
    Media:playSound( "F1LIE4.wav" )

    safeRemove( self.wormIn )
    safeRemove( self.wormOut )
    setInvincible( self.premonition, false )
    setInvincible( self.borg1, false )
    setInvincible( self.borg2, false )
    setShields( self.premonition, 0.7 )

    safeOrder( self.borg1, GameObject.Order.Attack, self.premonition )
    safeOrder( self.borg2, GameObject.Order.Attack, self.premonition )
    Objectives:load( "A1PremonTest_3.txt" )
    Objectives.visible = true
end

function A1PremonTestMission:failMission( message )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "loss"
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
        Cineractive:lookFrom( focus )
        Cineractive:setCameraOffset( Vector( 200, 100, -250 ) )
        Cineractive:lookAt( focus )
    end

    self:schedule( "mission_failure", 11.5, "finishFailure" )
end

function A1PremonTestMission:finishFailure( )
    if self.ended then
        return
    end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A1PremonTestMission:startWinSequence( )
    if self.ending or self.ended then
        return
    end

    self.ending = true
    self.phase = "win_pending"
    Media:playSound( "F1LIE5.wav" )
    self:schedule( "win_cine_delay", 6.0, "startWinCineractive" )
end

function A1PremonTestMission:startWinCineractive( )
    if self.phase ~= "win_pending" then
        return
    end

    self.phase = "win_cine"
    Cineractive.skippable = true
    Cineractive.active = true
    if isLive( self.premonition ) then
        Cineractive:lookFrom( self.premonition )
        Cineractive:setCameraOffset( Vector( 200, 100, -250 ) )
        Cineractive:lookAt( self.premonition )
    end
    Media:playSound( "F1DEM2.wav" )
    UI:addSubtitle( "Captain Deming reports from the USS Premonition.", 50, 85, 12.0, true )
    self:schedule( "premonition_information", 53.0, "toTheRescue" )
end

function A1PremonTestMission:toTheRescue( )
    if self.phase ~= "win_cine" then
        return
    end

    self.phase = "win_rescue"
    Media:stopSounds( )
    Media:playSound( "F1PIC5.wav" )
    safeOrder( self.lincoln, GameObject.Order.Go, POS.LINCOLNSTART )
    safeOrder( self.jackson, GameObject.Order.Go, POS.JACKSONSTART )
    safeOrder( self.enterprise, GameObject.Order.Go, POS.ENTTOPREMO )

    Cineractive:lookFrom( POS.PREMOENTPOINT )
    if isLive( self.enterprise ) then
        Cineractive:lookAt( self.enterprise )
    else
        Cineractive:lookAt( POS.ENTTOPREMO )
    end
    Cineractive:fadeOut( 3.0 )
    self:schedule( "mission_success", 12.0, "finishSuccess" )
end

function A1PremonTestMission:finishSuccess( )
    if self.ended then
        return
    end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A1PremonTestMission:tick( )
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

function A1PremonTestMission:update( )
    self:tick( )
end

function A1PremonTestMission:cineractiveUpdate( )
    -- Timer hooks drive the original cinematic action sequence. Gameplay rules
    -- remain paused while a cineractive is active, matching the A1 mission.
end

function A1PremonTestMission:cineractiveFinish( forced )
    if not forced then
        return
    end

    if self.phase == "opening" then
        self:finishOpeningCineractive( )
    elseif self.phase == "premonition_cine" then
        self:completeWormTransit( )
        self:finishPremonitionCineractive( )
    elseif self.phase == "win_cine" then
        self:toTheRescue( )
    end
end

MMM.register( A1PremonTestMission( ) )
