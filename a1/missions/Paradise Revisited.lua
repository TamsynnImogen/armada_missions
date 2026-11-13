-- CLEAN-ROOM STAR TREK: ARMADA FEDERATION 2 CONVERSION
--
-- Behaviour source:
--   Federation2S.dsl, Federation2R.drl, fed2.bzn, and the original A1 media.
-- Megadroid Mission Mod examples were used only to learn the public MMM API.
-- No existing Paradise Revisited Lua recreation was used as mission evidence.

class 'A1ParadiseRevisitedMission'

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

local function safePlace( entity, position )
    if not isLive( entity ) then
        return
    end
    local moved = pcall( function( ) entity.position = position end )
    if not moved then
        safeOrder( entity, GameObject.Order.Go, position )
    end
end

local function setInvincible( entity, value )
    if isLive( entity ) then
        pcall( function( ) entity.invincible = value end )
    end
end

local function entityCompromised( entity, owner )
    if not isLive( entity ) then
        return true
    end
    if owner ~= nil and entity.player.number ~= owner then
        return true
    end
    return entity.crew ~= nil and entity.crew <= 0
end

local function allCompromised( entities, owner )
    if entities == nil or #entities == 0 then
        return false
    end
    for _, entity in ipairs( entities ) do
        if not entityCompromised( entity, owner ) then
            return false
        end
    end
    return true
end

local function normalizedOdf( value )
    if value == nil then
        return nil
    end

    local result = string.lower( tostring( value ) )
    result = string.gsub( result, "\\\\", "/" )
    result = string.match( result, "([^/]+)$" ) or result
    if not string.match( result, "%.odf$" ) then
        result = result .. ".odf"
    end
    return result
end

local function findByOdf( odf, playerNumber )
    local wantedOdf = normalizedOdf( odf )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and normalizedOdf( entity.odf ) == wantedOdf
            and ( playerNumber == nil or entity.player.number == playerNumber )
    end ):find( )
end

local function playerCraft( playerNumber )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and entity.player.number == playerNumber
            and entity.crew > 0
    end ):find( )
end

local function nearestCraft( position, ships, maximumDistance )
    local nearest = nil
    local nearestDistance = maximumDistance * maximumDistance
    for _, ship in pairs( ships ) do
        if isLive( ship ) then
            local candidate = distanceSquared( position, ship.position )
            if candidate <= nearestDistance then
                nearest = ship
                nearestDistance = candidate
            end
        end
    end
    return nearest
end

local function claimNearestOrAdd( claimed, odf, playerNumber, position )
    local nearest = nil
    local nearestDistance = 1000000000
    for _, ship in pairs( findByOdf( odf, playerNumber ) ) do
        if isLive( ship ) and not claimed[ ship ] then
            local candidate = distanceSquared( position, ship.position )
            if candidate < nearestDistance then
                nearest = ship
                nearestDistance = candidate
            end
        end
    end

    if not isLive( nearest ) then
        nearest = Entity.add( odf, playerNumber, position )
    end
    if isLive( nearest ) then
        claimed[ nearest ] = true
    end
    return nearest
end

-- A1 stores the gameplay plane around Y=38.5. Every recovered coordinate
-- below has been translated by -38.5 for A2/Fleet Operations.
local POS = {
    STARBASE = Vector( 1200.8801, -14.971, 3292.4343 ),
    TURRET_A = Vector( 1401.32, -17.4199, 3156.92 ),
    TURRET_B = Vector( 1399.72, -19.3931, 3433.96 ),
    TURRET_C = Vector( 1399.25, -20.91, 3299.68 ),
    AKIRA_1 = Vector( 1316.58, -1.2052, 3388.48 ),
    AKIRA_2 = Vector( 1316.99, -2.5299, 3205.15 ),
    RUNABOUT = Vector( 1261.53, 32.3971, 3174.69 ),
    NEBULA = Vector( 1266.16, 32.988, 3408.37 ),
    WORF = Vector( 864.38, 43.8289, 4303.5 ),
    WORF_2 = Vector( 2420.32, 43.4976, 3236.52 ),
    SONA_1 = Vector( 2842.98, 27.1041, 2393.24 ),
    SONA_2 = Vector( 2838.83, 67.0, 2290.7 ),
    SONA_3 = Vector( 2842.76, 27.3315, 2226.52 ),
    WARIN_1 = Vector( 1792.97, 80.145, 3266.06 ),
    WARIN_2 = Vector( 1799.37, 67.07, 3318.18 ),
    WARIN_3 = Vector( 1798.96, 66.648, 3220.7 ),
    WAROUT_1 = Vector( 2315.42, 65.452, 3260.13 ),
    WAROUT_2 = Vector( 2313.14, 32.034, 3325.96 ),
    WAROUT_3 = Vector( 2313.61, 25.034, 3200.32 ),
    WORF_IN = Vector( 1274.67, 17.628, 3285.99 ),
    WORF_STOP_2 = Vector( 1495.87, 26.539, 3299.86 ),
    WORF_STOP_3 = Vector( 1274.81, 11.842, 3290.62 ),
    WORF_CAM_1 = Vector( 2201.06, 53.342, 3200.42 ),
    CAMERA_1 = Vector( 1528.96, 93.833, 3262.84 ),
    CAMERA_3 = Vector( 1601.05, 49.248, 3260.69 ),
    CAMERA_3_TARGET = Vector( 1344.98, 397.855, 2884.2 ),
    PLANET_CAM = Vector( 3025.2, -6.557, 4974.65 ),
    PLANET_TARGET = Vector( 1511.43, 28.488, 3339.15 ),
    BASE_CAM = Vector( 1491.74, 4.903, 3103.15 ),
    BASE_TARGET = Vector( 1701.32, 62.652, 3218.88 ),
    BASE_CAM_2 = Vector( 1870.09, 41.91, 3271.85 ),
    WAVE_1 = Vector( 4210.97, 40.836, 3951.66 ),
    WAVE_2 = Vector( 3613.76, 51.881, 1325.82 ),
    WAVE_3 = Vector( 3202.18, 43.615, 5448.27 ),
    FINAL_1 = Vector( 4256.76, 19.507, 1437.04 ),
    FINAL_2 = Vector( 5613.26, 18.134, 2929.26 ),
    FINAL_3 = Vector( 3963.47, 22.697, 1151.65 ),
    FINAL_4 = Vector( 3041.97, 0, 5006.43 ),
    FINAL_5 = Vector( 5257.71, 28.18, 3327.8 ),
    FINAL_6 = Vector( 3274.28, 4.681, 4346.68 ),
    ENDER = Vector( 1310.68, 44.444, 3789.35 ),
    WARP_SET = Vector( 1758.57, 47.87, 2971.78 ),
    END_CAMERA = Vector( 1818.58, 56.493, 3059.59 ),
    WARP_OUT = Vector( 1399.03, 0, 4061.91 )
}

local ROAM = {
    {
        Vector( 4138.76, 0, 1583.48 ), Vector( 4175.16, 0, 1807.52 ),
        Vector( 4470.94, 0, 1830.95 ), Vector( 4907.84, 0, 1779.05 ),
        Vector( 4879.44, 0, 1311.35 ), Vector( 5095.69, 0, 1049.12 ),
        Vector( 5519.52, 0, 544.724 ), Vector( 5910.55, 0, 150.939 ),
        Vector( 6215.31, 0, 390.174 ), Vector( 6149.65, 0, 742.09 ),
        Vector( 5805.51, 0, 1033.28 ), Vector( 5659.77, 0, 1224.91 ),
        Vector( 5837.74, 0, 1835.98 ), Vector( 5841.67, 0, 2169.81 ),
        Vector( 6252.57, 0, 2304.63 ), Vector( 6241.12, 0, 2548.07 ),
        Vector( 5997.42, 0, 3102.54 ), Vector( 5762.13, 0, 3439.98 ),
        Vector( 5651.22, 0, 3600.66 ), Vector( 5983.69, 0, 3875.8 ),
        Vector( 5745.09, 0, 4223.57 ), Vector( 5257.29, 0, 4371.51 ),
        Vector( 4801.88, 0, 4175.88 ), Vector( 4515.93, 0, 3782.36 ),
        Vector( 4652.14, 0, 3401.94 ), Vector( 4731.35, 0, 3100.27 ),
        Vector( 4783.38, 0, 2690.04 ), Vector( 4470.67, 0, 2394.03 ),
        Vector( 4231.47, 0, 1980.17 ), Vector( 3842.71, 0, 1734.74 ),
        Vector( 3910.43, 0, 1440.0 ), Vector( 4089.43, 0, 1429.47 ),
        Vector( 4138.76, 0, 1583.48 )
    },
    {
        Vector( 5476.39, 0, 2806.23 ), Vector( 5364.65, 0, 2516.98 ),
        Vector( 5054.49, 0, 2430.02 ), Vector( 4767.24, 0, 2613.39 ),
        Vector( 4377.03, 0, 2395.51 ), Vector( 3850.11, 0, 2354.77 ),
        Vector( 3379.58, 0, 2689.63 ), Vector( 3083.29, 0, 3083.89 ),
        Vector( 2699.18, 0, 3119.91 ), Vector( 2557.68, 0, 3323.34 ),
        Vector( 2605.93, 0, 3601.58 ), Vector( 2453.9, 0, 3843.0 ),
        Vector( 2315.98, 0, 4193.34 ), Vector( 2031.53, 0, 4477.39 ),
        Vector( 1814.09, 0, 4753.22 ), Vector( 1938.01, 0, 4989.24 ),
        Vector( 2281.02, 0, 5006.22 ), Vector( 2172.19, 0, 5417.3 ),
        Vector( 2353.99, 0, 5570.09 ), Vector( 2865.0, 0, 5163.44 ),
        Vector( 2886.18, 0, 4595.33 ), Vector( 3647.66, 0, 4213.18 ),
        Vector( 4093.09, 0, 4354.69 ), Vector( 4465.96, 0, 4016.19 ),
        Vector( 4643.58, 0, 3597.59 ), Vector( 5016.35, 0, 3213.38 ),
        Vector( 5428.52, 0, 3075.66 ), Vector( 5476.39, 0, 2806.23 )
    },
    {
        Vector( 3753.72, 0, 1077.34 ), Vector( 3606.71, 0, 876.915 ),
        Vector( 3414.51, 0, 959.399 ), Vector( 3101.66, 0, 1198.74 ),
        Vector( 2793.29, 0, 1058.21 ), Vector( 2689.94, 0, 665.262 ),
        Vector( 2313.68, 0, 584.853 ), Vector( 1899.07, 0, 900.414 ),
        Vector( 1619.0, 0, 851.264 ), Vector( 1608.38, 0, 337.474 ),
        Vector( 1041.59, 0, 430.908 ), Vector( 669.254, 0, 661.312 ),
        Vector( 424.185, 0, 993.483 ), Vector( 260.366, 0, 1353.27 ),
        Vector( 689.451, 0, 1472.6 ), Vector( 1078.65, 0, 1413.78 ),
        Vector( 1623.05, 0, 1232.79 ), Vector( 2154.78, 0, 792.275 ),
        Vector( 2507.72, 0, 663.397 ), Vector( 2832.71, 0, 775.848 ),
        Vector( 2529.87, 0, 1245.88 ), Vector( 2197.68, 0, 1624.6 ),
        Vector( 2107.39, 0, 1386.18 ), Vector( 2729.98, 0, 1186.2 ),
        Vector( 3127.1, 0, 1108.38 ), Vector( 3168.97, 0, 1577.94 ),
        Vector( 3730.77, 0, 1773.37 ), Vector( 4056.39, 0, 1415.98 ),
        Vector( 3753.72, 0, 1077.34 )
    },
    {
        Vector( 2936.86, 0, 5024.13 ), Vector( 2733.22, 0, 5229.23 ),
        Vector( 2531.71, 0, 5592.95 ), Vector( 2737.06, 0, 5854.08 ),
        Vector( 3033.58, 0, 6032.59 ), Vector( 3477.71, 0, 6012.74 ),
        Vector( 3823.04, 0, 6139.25 ), Vector( 4308.36, 0, 5980.55 ),
        Vector( 4771.04, 0, 6043.19 ), Vector( 5202.4, 0, 5870.01 ),
        Vector( 5527.78, 0, 6008.3 ), Vector( 5994.37, 0, 5913.95 ),
        Vector( 6010.01, 0, 5510.38 ), Vector( 5928.35, 0, 4963.31 ),
        Vector( 5842.3, 0, 4356.17 ), Vector( 5945.41, 0, 3909.32 ),
        Vector( 5719.11, 0, 3708.78 ), Vector( 5711.22, 0, 3422.66 ),
        Vector( 6083.28, 0, 3119.15 ), Vector( 6104.19, 0, 2776.32 ),
        Vector( 6180.06, 0, 2361.1 ), Vector( 6010.2, 0, 2015.27 ),
        Vector( 5871.29, 0, 1673.43 ), Vector( 5747.7, 0, 1264.6 ),
        Vector( 5418.24, 0, 1363.91 ), Vector( 5231.45, 0, 1813.98 ),
        Vector( 4907.83, 0, 1933.94 ), Vector( 4579.4, 0, 1842.42 ),
        Vector( 4287.33, 0, 2100.47 ), Vector( 4135.11, 0, 2482.0 ),
        Vector( 3721.96, 0, 2479.35 ), Vector( 3547.2, 0, 2740.62 ),
        Vector( 3773.12, 0, 3171.6 ), Vector( 3595.39, 0, 3547.83 ),
        Vector( 3476.17, 0, 3986.65 ), Vector( 3433.01, 0, 4289.86 ),
        Vector( 3015.25, 0, 4555.85 ), Vector( 2936.86, 0, 5024.13 )
    },
    {
        Vector( 4965.15, 0, 3314.13 ), Vector( 4819.48, 0, 3194.56 ),
        Vector( 4777.54, 0, 2853.55 ), Vector( 4688.4, 0, 2575.8 ),
        Vector( 4386.44, 0, 2367.03 ), Vector( 4294.44, 0, 1934.21 ),
        Vector( 4013.77, 0, 1742.6 ), Vector( 3502.59, 0, 1771.26 ),
        Vector( 3205.83, 0, 1476.15 ), Vector( 3302.52, 0, 1025.14 ),
        Vector( 3629.87, 0, 664.34 ), Vector( 4158.28, 0, 649.272 ),
        Vector( 4583.19, 0, 786.846 ), Vector( 4860.82, 0, 498.688 ),
        Vector( 5157.28, 0, 692.674 ), Vector( 5219.0, 0, 1056.71 ),
        Vector( 5454.62, 0, 1191.41 ), Vector( 5374.09, 0, 1636.11 ),
        Vector( 4965.74, 0, 1879.47 ), Vector( 4450.18, 0, 1949.53 ),
        Vector( 4426.95, 0, 2199.55 ), Vector( 4172.2, 0, 2550.13 ),
        Vector( 3649.96, 0, 2576.79 ), Vector( 3582.57, 0, 2853.18 ),
        Vector( 3830.34, 0, 3136.42 ), Vector( 3541.11, 0, 3508.18 ),
        Vector( 3870.79, 0, 3646.5 ), Vector( 4342.73, 0, 3736.28 ),
        Vector( 4677.33, 0, 3539.13 ), Vector( 4965.15, 0, 3314.13 )
    },
    {
        Vector( 3332.24, 0, 4450.73 ), Vector( 3433.95, 0, 4678.74 ),
        Vector( 3439.86, 0, 4910.41 ), Vector( 3416.15, 0, 5221.7 ),
        Vector( 3621.41, 0, 5428.73 ), Vector( 3953.32, 0, 5387.71 ),
        Vector( 4161.65, 0, 5001.16 ), Vector( 4541.9, 0, 5007.2 ),
        Vector( 4943.04, 0, 5017.55 ), Vector( 4835.85, 0, 5291.87 ),
        Vector( 4713.38, 0, 5503.72 ), Vector( 4746.63, 0, 5835.21 ),
        Vector( 5032.84, 0, 5884.8 ), Vector( 5324.53, 0, 5502.68 ),
        Vector( 5799.85, 0, 5479.85 ), Vector( 6086.24, 0, 5166.07 ),
        Vector( 5836.09, 0, 4880.45 ), Vector( 5888.94, 0, 4574.59 ),
        Vector( 5762.88, 0, 4293.48 ), Vector( 5387.45, 0, 4243.02 ),
        Vector( 5074.32, 0, 4365.34 ), Vector( 4714.55, 0, 4305.62 ),
        Vector( 4503.27, 0, 3999.68 ), Vector( 4408.98, 0, 3738.15 ),
        Vector( 4103.59, 0, 3678.6 ), Vector( 3668.26, 0, 3786.8 ),
        Vector( 3503.89, 0, 4183.2 ), Vector( 3332.24, 0, 4450.73 )
    }
}

function A1ParadiseRevisitedMission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.openingComplete = false
    self.initialWaveCleared = false
    self.buildStage = 0
    self.currentWaveNumber = 1
    self.finalStarted = false
    self.finalForced = false
    self.finalSecondForced = false
    self.victoryPending = false
    self.timers = { }
    self.finalPatrols = { }
end

function A1ParadiseRevisitedMission:schedule( id, seconds, methodName )
    local timerName = "a1paradiserevisited_" .. id
    local timer = Timer( timerName, seconds, Timer.State.Started )
    timer:hook( timerName .. "_hook", nil, function( timerObject, hook )
        if not self.ended then
            self[ methodName ]( self )
        end
    end, nil )
    self.timers[ id ] = timer
end

function A1ParadiseRevisitedMission:addStartingForces( )
    -- A1Compat loads the original A1 map objects directly. Claim those
    -- preplaced craft first and only create a fallback when a map variant is
    -- genuinely missing one; this keeps the raw fed2 map from receiving a
    -- duplicate starting fleet.
    local claimed = { }
    self.starbase = claimNearestOrAdd( claimed, "fbase.odf", 1, POS.STARBASE )
    self.turretA = claimNearestOrAdd( claimed, "fturret.odf", 1, POS.TURRET_A )
    self.turretB = claimNearestOrAdd( claimed, "fturret.odf", 1, POS.TURRET_B )
    self.turretC = claimNearestOrAdd( claimed, "fturret.odf", 1, POS.TURRET_C )
    self.akira1 = claimNearestOrAdd( claimed, "fcruise1.odf", 1, POS.AKIRA_1 )
    self.akira2 = claimNearestOrAdd( claimed, "fcruise1.odf", 1, POS.AKIRA_2 )
    self.runabout = claimNearestOrAdd( claimed, "fscout.odf", 1, POS.RUNABOUT )
    self.nebula = claimNearestOrAdd( claimed, "fscout.odf", 1, POS.NEBULA )
    self.worf = claimNearestOrAdd( claimed, "favenger.odf", 1, POS.WORF )
    self.worf2 = claimNearestOrAdd( claimed, "favenger.odf", 1, POS.WORF_2 )

    self.initialWave = {
        claimNearestOrAdd( claimed, "zsondest.odf", 2, POS.SONA_1 ),
        claimNearestOrAdd( claimed, "zsonbat.odf", 2, POS.SONA_2 ),
        claimNearestOrAdd( claimed, "zsondest.odf", 2, POS.SONA_3 )
    }
    self.currentWave = self.initialWave

    setInvincible( self.starbase, true )
    setInvincible( self.worf, true )
    setInvincible( self.worf2, true )
    for _, ship in ipairs( self.initialWave ) do
        setInvincible( ship, true )
        safeOrder( ship, GameObject.Order.Stop, nil )
    end
end

function A1ParadiseRevisitedMission:setup( )
    print( "[A1ParadiseRevisited] clean-room Federation2 DSL/DRL conversion loaded" )
    self.player = Player( 1 )
    self.sona = Player( 2 )
    self.player:setRelation( self.sona, Player.Relation.Enemy )
    self.sona:setRelation( self.player, Player.Relation.Enemy )
    self.player.resources.dilithium = 3000

    Objectives:load( "A1ParadiseRevisited_1.txt" )
    Objectives.visible = false
    self:addStartingForces( )
    self:startOpeningCineractive( )
end

function A1ParadiseRevisitedMission:startOpeningCineractive( )
    self.phase = "opening"
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 5.0 )
    Cineractive:lookFrom( POS.PLANET_CAM )
    Cineractive:lookAt( POS.PLANET_TARGET )
    Media:playSound( "Mfed115.wav" )
    self:schedule( "opening_first", 5.0, "openingFirstShot" )
end

function A1ParadiseRevisitedMission:openingFirstShot( )
    if self.phase ~= "opening" then return end
    UI:addTitle( "PARADISE REVISITED", 50, 50, 11.0, true )
    safeOrder( self.worf2, GameObject.Order.Go, POS.WORF_STOP_3 )
    self:schedule( "opening_second_a", 5.0, "openingSecondShotA" )
end

function A1ParadiseRevisitedMission:openingSecondShotA( )
    if self.phase ~= "opening" then return end
    Cineractive:lookFrom( POS.WORF_CAM_1 )
    Cineractive:lookAt( self.worf2 )
    safeOrder( self.worf2, GameObject.Order.Go, POS.WORF_STOP_2 )
    self:schedule( "opening_second_b", 8.0, "openingSecondShotB" )
end

function A1ParadiseRevisitedMission:openingSecondShotB( )
    if self.phase ~= "opening" then return end
    Cineractive:lookFrom( POS.BASE_CAM_2 )
    Cineractive:lookAt( self.starbase )
    Media:playSound( "F2WOR1.wav" )
    self:schedule( "opening_second_c", 8.0, "openingSecondShotC" )
    self:schedule( "opening_third", 18.9, "openingThirdShot" )
end

function A1ParadiseRevisitedMission:openingSecondShotC( )
    if self.phase ~= "opening" then return end
    Cineractive:lookFrom( POS.BASE_CAM )
    Cineractive:lookAt( POS.BASE_TARGET )
    safePlace( self.initialWave[ 1 ], POS.WAROUT_1 )
    safePlace( self.initialWave[ 2 ], POS.WAROUT_2 )
    safePlace( self.initialWave[ 3 ], POS.WAROUT_3 )
end

function A1ParadiseRevisitedMission:openingThirdShot( )
    if self.phase ~= "opening" then return end
    safeRemove( self.worf2 )
    safePlace( self.worf, POS.WORF_IN )
    safePlace( self.initialWave[ 1 ], POS.WARIN_1 )
    safePlace( self.initialWave[ 2 ], POS.WARIN_2 )
    safePlace( self.initialWave[ 3 ], POS.WARIN_3 )
    Cineractive:lookFrom( POS.CAMERA_1 )
    Cineractive:lookAt( POS.STARBASE )
    Media:stopSounds( )
    Media:playSound( "Mkli115.wav" )
    self:schedule( "opening_fourth", 11.0, "openingFourthShot" )
end

function A1ParadiseRevisitedMission:openingFourthShot( )
    if self.phase ~= "opening" then return end
    if isLive( self.initialWave[ 2 ] ) then
        Cineractive:lookFrom( self.initialWave[ 2 ] )
        Cineractive:setCameraOffset( Vector( 180, 80, -250 ) )
        Cineractive:lookAt( self.initialWave[ 2 ] )
    end
    Media:playSound( "F2WOR2.wav" )
    self:schedule( "opening_sona_one", 9.95, "openingSonaOne" )
end

function A1ParadiseRevisitedMission:openingSonaOne( )
    if self.phase ~= "opening" then return end
    Media:playSound( "F2SON1.wav" )
    self:schedule( "opening_worf_three", 9.23, "openingWorfThree" )
end

function A1ParadiseRevisitedMission:openingWorfThree( )
    if self.phase ~= "opening" then return end
    Media:playSound( "F2WOR3.wav" )
    self:schedule( "opening_sona_two", 6.52, "openingSonaTwo" )
end

function A1ParadiseRevisitedMission:openingSonaTwo( )
    if self.phase ~= "opening" then return end
    Media:playSound( "F2SON2.wav" )
    self:schedule( "opening_ensign", 3.17, "openingEnsign" )
end

function A1ParadiseRevisitedMission:openingEnsign( )
    if self.phase ~= "opening" then return end
    Media:playSound( "F2ENS1.wav" )
    self:schedule( "opening_eighth", 4.0, "openingEighthShot" )
end

function A1ParadiseRevisitedMission:openingEighthShot( )
    if self.phase ~= "opening" then return end
    Cineractive:lookFrom( POS.CAMERA_3 )
    Cineractive:lookAt( POS.CAMERA_3_TARGET )
    Media:playSound( "F2WOR5.wav" )
    self:schedule( "opening_done", 1.42, "finishOpeningCineractive" )
end

function A1ParadiseRevisitedMission:finishOpeningCineractive( )
    if self.openingComplete then return end
    self.openingComplete = true
    self.phase = "gameplay"
    Cineractive.active = false
    Media:stopSounds( )
    safeRemove( self.worf2 )
    safePlace( self.worf, POS.WORF_IN )
    setInvincible( self.starbase, false )
    setInvincible( self.worf, false )
    for _, ship in ipairs( self.initialWave ) do
        setInvincible( ship, false )
        safeOrder( ship, GameObject.Order.Attack, self.starbase )
    end
    Objectives:load( "A1ParadiseRevisited_1.txt" )
    Objectives.visible = true
end

function A1ParadiseRevisitedMission:showObjective( number )
    if self.finalStarted or self.ending then return end
    Objectives:load( "A1ParadiseRevisited_" .. number .. ".txt" )
    Objectives.visible = true
end

function A1ParadiseRevisitedMission:showBuildConstructor( )
    if self.buildStage == 1 then self:showObjective( 2 ) end
end

function A1ParadiseRevisitedMission:showBuildMining( )
    if self.buildStage == 2 then self:showObjective( 3 ) end
end

function A1ParadiseRevisitedMission:showBuildShipyard( )
    if self.buildStage == 3 then self:showObjective( 4 ) end
end

function A1ParadiseRevisitedMission:showBuildForces( )
    if self.buildStage == 4 then self:showObjective( 5 ) end
end

function A1ParadiseRevisitedMission:startBuildSequence( )
    if self.buildStage ~= 0 then return end
    self.buildStage = 1
    self:schedule( "build_constructor", 3.0, "showBuildConstructor" )
end

function A1ParadiseRevisitedMission:updateBuildSequence( )
    if self.finalStarted or self.buildStage == 0 then return end
    if self.buildStage == 1 and #findByOdf( "fconst.odf", 1 ) > 0 then
        self.buildStage = 2
        self:schedule( "build_mining", 3.0, "showBuildMining" )
    elseif self.buildStage == 2 and #findByOdf( "fmining.odf", 1 ) > 0 then
        self.buildStage = 3
        self:schedule( "build_shipyard", 3.0, "showBuildShipyard" )
    elseif self.buildStage == 3 and #findByOdf( "fyard.odf", 1 ) > 0 then
        self.buildStage = 4
        self:schedule( "build_forces", 3.0, "showBuildForces" )
    end
end

function A1ParadiseRevisitedMission:spawnWave( number )
    local odfs = nil
    if number == 2 then
        odfs = { "zsondest.odf", "zsondest.odf", "zsondest.odf" }
    elseif number == 3 or number == 4 then
        odfs = { "zsonbat.odf", "zsondest.odf", "zsondest.odf" }
    elseif number == 5 then
        odfs = { "zsonbat.odf", "zsonbat.odf", "zsondest.odf" }
    else
        return
    end
    local positions = { POS.WAVE_1, POS.WAVE_2, POS.WAVE_3 }
    self.currentWave = { }
    self.currentWaveNumber = number
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 2, positions[ index ] )
        table.insert( self.currentWave, ship )
        safeOrder( ship, GameObject.Order.Attack, self.worf )
    end
end

function A1ParadiseRevisitedMission:advanceWaves( )
    if not allCompromised( self.currentWave, 2 ) then return end
    if self.currentWaveNumber == 1 then
        self.initialWaveCleared = true
        self:startBuildSequence( )
        self:spawnWave( 2 )
    elseif self.currentWaveNumber < 5 then
        self:spawnWave( self.currentWaveNumber + 1 )
    elseif not self.finalStarted then
        self.currentWave = nil
        self:schedule( "new_objectives", 3.0, "startFinalSearch" )
        self.finalStarted = true
    end
end

function A1ParadiseRevisitedMission:startFinalSearch( )
    if self.ending then return end
    Objectives:load( "A1ParadiseRevisited_6.txt" )
    Objectives.visible = true
    Media:playSound( "F2ENS2.wav" )

    local odfs = {
        "zsondest.odf", "zsondest.odf", "zsondest.odf",
        "zsonbat.odf", "zsondest.odf", "zsondest.odf"
    }
    local positions = {
        POS.FINAL_1, POS.FINAL_2, POS.FINAL_3,
        POS.FINAL_4, POS.FINAL_5, POS.FINAL_6
    }
    self.finalShips = { }
    self.finalPatrols = { }
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 2, positions[ index ] )
        table.insert( self.finalShips, ship )
        table.insert( self.finalPatrols, {
            ship = ship,
            route = ROAM[ index ],
            point = 1,
            attacking = false
        } )
        safeOrder( ship, GameObject.Order.Go, ROAM[ index ][ 1 ] )
    end
    self:schedule( "worf_new_objectives", 5.47, "worfFinalOrders" )
end

function A1ParadiseRevisitedMission:worfFinalOrders( )
    if self.ending then return end
    Media:playSound( "F2WOR6.wav" )
    self:schedule( "last_attack_one", 200.0, "forceFinalAttackOne" )
end

function A1ParadiseRevisitedMission:updateFinalPatrols( )
    if self.finalShips == nil then return end
    local targets = playerCraft( 1 )
    for _, patrol in ipairs( self.finalPatrols ) do
        if isLive( patrol.ship ) and not patrol.attacking then
            local target = nearestCraft( patrol.ship.position, targets, 450.0 )
            if target ~= nil then
                patrol.attacking = true
                safeOrder( patrol.ship, GameObject.Order.Attack, target )
            else
                local point = patrol.route[ patrol.point ]
                if distanceSquared( patrol.ship.position, point ) <= 10000.0 then
                    patrol.point = patrol.point + 1
                    if patrol.point > #patrol.route then patrol.point = 1 end
                    point = patrol.route[ patrol.point ]
                end
                safeOrder( patrol.ship, GameObject.Order.Go, point )
            end
        end
    end
end

function A1ParadiseRevisitedMission:forcePatrols( first, last )
    for index = first, last do
        local patrol = self.finalPatrols[ index ]
        if patrol ~= nil and isLive( patrol.ship ) then
            patrol.attacking = true
            safeOrder( patrol.ship, GameObject.Order.Attack, self.worf )
        end
    end
end

function A1ParadiseRevisitedMission:forceFinalAttackOne( )
    if self.ending then return end
    self.finalForced = true
    self:forcePatrols( 1, 3 )
    self:schedule( "last_attack_two", 20.0, "forceFinalAttackTwo" )
end

function A1ParadiseRevisitedMission:forceFinalAttackTwo( )
    if self.ending then return end
    self.finalSecondForced = true
    self:forcePatrols( 4, 6 )
end

function A1ParadiseRevisitedMission:failMission( message )
    if self.ending or self.ended then return end
    self.ending = true
    self.phase = "loss"
    Cineractive.skippable = false
    Cineractive.active = true
    Cineractive:fadeOut( 1.0 )
    Cineractive:lookFrom( POS.ENDER )
    Cineractive:lookAt( POS.STARBASE )
    Objectives.visible = false
    Media:stopSounds( )
    Media:playSound( "Mfed5.wav" )
    UI:addSubtitle( message, 50, 85, 8.0, true )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A1ParadiseRevisitedMission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A1ParadiseRevisitedMission:startWinCineractive( )
    if self.ending or self.ended then return end
    self.ending = true
    self.phase = "win_ensign"
    Objectives.visible = false
    Cineractive.skippable = true
    Cineractive.active = true
    Cineractive:fadeIn( 1.0 )
    Cineractive:lookFrom( POS.ENDER )
    Cineractive:lookAt( self.worf )
    safeOrder( self.worf, GameObject.Order.Go, POS.ENDER )
    Media:playSound( "F2ENS3.wav" )
    self:schedule( "win_hawthorne", 3.94, "startHawthorneMessage" )
end

function A1ParadiseRevisitedMission:startHawthorneMessage( )
    if self.phase ~= "win_ensign" then return end
    self.phase = "win_hawthorne"
    Cineractive:lookFrom( POS.WARP_SET )
    Cineractive:lookAt( self.worf )
    Media:playSound( "F2HAW1.wav" )
    UI:addSubtitle( "Admiral Hawthorne reports from Starfleet Command.", 50, 85, 18.4, true )
    self:schedule( "win_warp", 19.0, "startWarpOut" )
end

function A1ParadiseRevisitedMission:startWarpOut( )
    if self.phase ~= "win_hawthorne" then return end
    self.phase = "win_warp"
    Media:stopSounds( )
    Media:playSound( "Mfed10.wav" )
    Cineractive:lookFrom( POS.END_CAMERA )
    Cineractive:lookAt( self.worf )
    safeOrder( self.worf, GameObject.Order.Go, POS.WARP_OUT )
    Cineractive:fadeOut( 3.0 )
    self:schedule( "success", 11.5, "finishSuccess" )
end

function A1ParadiseRevisitedMission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A1ParadiseRevisitedMission:tick( )
    if self.ending or self.ended or not self.openingComplete then return end

    if entityCompromised( self.worf, 1 ) then
        self:failMission( "THE U.S.S. AVENGER HAS BEEN DESTROYED" )
        return
    end
    if entityCompromised( self.starbase, 1 ) then
        self:failMission( "STARBASE 40 HAS BEEN DESTROYED" )
        return
    end

    self:updateBuildSequence( )
    if self.finalStarted then
        if self.finalShips ~= nil then
            self:updateFinalPatrols( )
            if allCompromised( self.finalShips, 2 ) and not self.victoryPending then
                self.victoryPending = true
                self:schedule( "win_start", 3.0, "startWinCineractive" )
            end
        end
    else
        self:advanceWaves( )
    end
end

function A1ParadiseRevisitedMission:update( )
    self:tick( )
end

function A1ParadiseRevisitedMission:cineractiveUpdate( )
    -- Recovered timer hooks drive both cinematics. Gameplay rules remain
    -- paused while the cineractive is active, as in the A1 mission.
end

function A1ParadiseRevisitedMission:cineractiveFinish( forced )
    if not forced then return end
    if self.phase == "opening" then
        self:finishOpeningCineractive( )
    elseif self.phase == "win_ensign" or self.phase == "win_hawthorne" or self.phase == "win_warp" then
        self:finishSuccess( )
    end
end

MMM.register( A1ParadiseRevisitedMission( ) )
