-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 8 CONVERSION
-- Behaviour evidence: a2_kling08S.dsl, a2_kling08R.drl, a2_kling08.bzn.

class 'A2Kling08Mission'

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
        print( "[TrojanHorse] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local CANNON_FODDER = {
    "CannonFodder1", "CannonFodder2", "CannonFodder3",
    "CannonFodder4", "CannonFodder5"
}

local CARD_PATROLS = {
    "CardPatrol1", "CardPatrol2", "CardPatrol3",
    "CardPatrol4", "CardPatrol5", "CardPatrol6"
}

local SHIPYARD_LABELS = {
    "CardShipyard1", "CardShipyard2", "CardShipyard3", "CardShipyard4"
}

local SENSOR_LABELS = { "CardSensor2", "CardSensor3", "CardSensor4" }

local MOBILE_CARDASSIAN_ODFS = {
    [ "cdestroy.odf" ] = true, [ "cfrigate.odf" ] = true,
    [ "cscout.odf" ] = true, [ "ccruise1.odf" ] = true,
    [ "ccruise2.odf" ] = true, [ "ccruise3.odf" ] = true,
    [ "cbattle.odf" ] = true, [ "cbattle2.odf" ] = true,
    [ "cassault.odf" ] = true, [ "cspecial.odf" ] = true
}

function A2Kling08Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.captured = { }
    self.loaded = { }
    self.reporters = { }
    self.turretsDeactivated = false
    self.cardBaseAnnounced = false
end

function A2Kling08Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k08_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling08Mission:setup( )
    print( "[TrojanHorse] clean-room a2_kling08 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.scriptedCardassian = Player( 8 )
    self.disabledTurrets = Player( 7 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.scriptedCardassian, Player.Relation.Enemy )
    self.scriptedCardassian:setRelation( self.player, Player.Relation.Enemy )
    self.cardassian:setRelation( self.scriptedCardassian, Player.Relation.Ally )
    self.scriptedCardassian:setRelation( self.cardassian, Player.Relation.Ally )
    self.player:setRelation( self.disabledTurrets, Player.Relation.Ally )
    self.disabledTurrets:setRelation( self.player, Player.Relation.Ally )
    self.cardassian:setRelation( self.disabledTurrets, Player.Relation.Ally )
    self.disabledTurrets:setRelation( self.cardassian, Player.Relation.Ally )
    self:isolatePatrols( )
    Objectives:load( "a2_kling08_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling08Mission:isolatePatrols( )
    for _, label in ipairs( CARD_PATROLS ) do
        local ship = findLabel( label )
        if live( ship ) then
            safeOrder( ship, GameObject.Order.Stop, nil )
            pcall( function( )
                ship.forceOntoMap = false
                ship.player = self.scriptedCardassian
                ship.perceivedTeam = self.cardassian
            end )
        end
    end
end

function A2Kling08Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 5.0 )
    self.martok = findLabel( "Martok" )
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -420, 190, -560 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "TROJAN HORSE", 50, 50, 10.0, true )
    UI:addSubtitle( "Cardassian Territory", 50, 85, 10.0, true )
    Media:playMusic( "mkli30.wav" )
    self:schedule( "intro_voice", 4.0, "playIntroVoice" )
    self:schedule( "fodder", 10.0, "moveCannonFodder" )
    self:schedule( "opening_done", 71.0, "finishOpening" )
end

function A2Kling08Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling08_intro.wav" ) end
end

function A2Kling08Mission:moveCannonFodder( )
    if self.phase ~= "opening" then return end
    for _, label in ipairs( CANNON_FODDER ) do
        safeOrder( findLabel( label ), GameObject.Order.Move,
            Vector( 6500, 0, 5200 ) )
    end
end

function A2Kling08Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    for _, label in ipairs( CANNON_FODDER ) do
        local ship = findLabel( label )
        if valid( ship ) then Entity.remove( ship ) end
    end

    self.phase = "gameplay"
    self.martok = findLabel( "Martok" ) or self.martok
    self.klingBase = findLabel( "KlingBase1" )
    self.cardBase = findLabel( "CardBase" )
    self.shipyards = { }
    self.sensors = { }
    for _, label in ipairs( SHIPYARD_LABELS ) do
        self.shipyards[ #self.shipyards + 1 ] = findLabel( label )
    end
    for _, label in ipairs( SENSOR_LABELS ) do
        self.sensors[ #self.sensors + 1 ] = findLabel( label )
    end
    Objectives:load( "a2_kling08_A.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling08_basic.aip" )

    for index, label in ipairs( CARD_PATROLS ) do
        local ship = findLabel( label )
        if live( ship ) then
            pcall( function( ) ship.forceOntoMap = true end )
            local destination = ( index <= 2 and Vector( 4650, 0, 4720 ) )
                or ( index <= 4 and Vector( 7405, 0, 946 ) )
                or Vector( 1646, 0, 1526 )
            safeOrder( ship, GameObject.Order.Move, destination )
        end
    end

    self:schedule( "base_attack", 400.0, "attackKlingBase" )
    print( "[TrojanHorse] gameplay started" )
end

function A2Kling08Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling08Mission:isCardassianHull( ship )
    if not live( ship ) then return false end
    return MOBILE_CARDASSIAN_ODFS[ string.lower( ship.odf or "" ) ] == true
end

function A2Kling08Mission:playerBases( )
    return findCraft( "kbase.odf", 1 )
end

function A2Kling08Mission:checkCapturedShips( )
    local bases = self:playerBases( )
    for _, ship in pairs( findCraft( nil, 1 ) ) do
        if self:isCardassianHull( ship ) then
            if not self.captured[ ship ] then
                self.captured[ ship ] = true
                self:complete( 1 )
                Media:playMovie( "a2_kling08_taken.bik" )
                print( "[TrojanHorse] Cardassian ship captured: "
                    .. tostring( ship.label ) )
            end

            if not self.loaded[ ship ] then
                for _, base in pairs( bases ) do
                    if live( base ) and distanceSquared( ship.position,
                        base.position ) <= 422500 then
                        self.loaded[ ship ] = true
                        self:complete( 2 )
                        Media:playSound( "a2_kling08_load.wav" )
                        print( "[TrojanHorse] deactivation codes loaded" )
                        break
                    end
                end
            end

            if self.loaded[ ship ] and valid( self.cardBase )
                and distanceSquared( ship.position,
                    self.cardBase.position ) <= 360000 then
                self:deactivateTurrets( )
            end
        end
    end
end

function A2Kling08Mission:deactivateTurrets( )
    if self.turretsDeactivated then return end
    self.turretsDeactivated = true
    self.cardassian:loadAIP( "a2_kling08_end.aip" )
    local disabled = 0
    for _, odf in ipairs( { "cturret.odf", "cturret2.odf" } ) do
        for _, turret in pairs( findCraft( odf, 2 ) ) do
            if valid( turret ) then
                local ok = pcall( function( )
                    turret.player = self.disabledTurrets
                    turret.perceivedTeam = self.cardassian
                end )
                if ok then disabled = disabled + 1 end
            end
        end
    end
    self:complete( 3 )
    self:complete( 5 )
    self:complete( 6 )
    Media:playMovie( "a2_kling08_turrets.bik" )
    print( "[TrojanHorse] Cardassian turrets deactivated: "
        .. tostring( disabled ) )
end

function A2Kling08Mission:stationDetectedKlingon( )
    local stations = { }
    if valid( self.cardBase ) then
        stations[ #stations + 1 ] = { self.cardBase, 360000 }
    end
    for _, station in ipairs( self.shipyards ) do
        if valid( station ) then stations[ #stations + 1 ] = { station, 360000 } end
    end
    for _, station in ipairs( self.sensors ) do
        if valid( station ) then stations[ #stations + 1 ] = { station, 810000 } end
    end

    for _, ship in pairs( findCraft( nil, 1 ) ) do
        if live( ship ) and not self:isCardassianHull( ship ) and not ship.cloaked then
            for _, check in ipairs( stations ) do
                if distanceSquared( ship.position, check[ 1 ].position ) <= check[ 2 ] then
                    return ship
                end
            end
        end
    end
    return nil
end

function A2Kling08Mission:enemyMobiles( )
    local answer = { }
    for _, team in ipairs( { 2, 8 } ) do
        for _, ship in pairs( findCraft( nil, team ) ) do
            if self:isCardassianHull( ship ) then answer[ #answer + 1 ] = ship end
        end
    end
    return answer
end

function A2Kling08Mission:checkSpotters( )
    if not valid( self.cardBase ) then return nil end
    local bases = self:playerBases( )
    for _, spotter in ipairs( self:enemyMobiles( ) ) do
        if not self.reporters[ spotter ] then
            for _, base in pairs( bases ) do
                if live( base ) and distanceSquared( spotter.position,
                    base.position ) <= 422500 then
                    self.reporters[ spotter ] = true
                    safeOrder( spotter, GameObject.Order.Move, self.cardBase )
                    Media:playSound( "a2_kling08_warning.wav" )
                    Media:playMovie( "a2_kling08_warning.bik" )
                    print( "[TrojanHorse] Cardassian spotter returning to base: "
                        .. tostring( spotter.label ) )
                    break
                end
            end
        end
    end

    for reporter in pairs( self.reporters ) do
        if live( reporter ) and distanceSquared( reporter.position,
            self.cardBase.position ) <= 360000 then
            return reporter
        end
    end
    return nil
end

function A2Kling08Mission:attackKlingBase( )
    if not live( self.klingBase ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if self:isCardassianHull( ship ) then
            safeOrder( ship, GameObject.Order.Attack, self.klingBase )
            ordered = ordered + 1
            if ordered >= 3 then break end
        end
    end
end

function A2Kling08Mission:allShipyardsDestroyed( )
    for index, yard in ipairs( self.shipyards ) do
        if not valid( yard ) then
            yard = findLabel( SHIPYARD_LABELS[ index ] )
            self.shipyards[ index ] = yard
        end
        if live( yard ) then return false end
    end
    return true
end

function A2Kling08Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 7 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if valid( self.cardBase ) then
        Cineractive:lookFrom( self.cardBase )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.cardBase )
    end
    UI:addTitle( "THE CARDASSIAN SHIPYARDS ARE DESTROYED", 50, 50, 8.0, true )
    Media:playMusic( "mkli15a.wav" )
    Media:playSound( "a2_kling08_win.wav" )
    self:schedule( "success", 20.0, "finishSuccess" )
end

function A2Kling08Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling08Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mkli10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 10.0, "finishFailure" )
end

function A2Kling08Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling08Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( "MARTOK HAS BEEN LOST", "a2_kling08_lose2.wav" )
        return
    end

    self:checkCapturedShips( )
    if not self.turretsDeactivated then
        local detected = self:stationDetectedKlingon( )
        if detected ~= nil then
            self:startFailure( "A KLINGON SHIP HAS BEEN DETECTED",
                "a2_kling08_lose1.wav" )
            return
        end
        local reporter = self:checkSpotters( )
        if reporter ~= nil then
            self:startFailure( "A CARDASSIAN SHIP HAS REPORTED THE STARBASE",
                "a2_kling08_lose1.wav" )
            return
        end
    end

    if not self.cardBaseAnnounced and valid( self.cardBase ) then
        for _, ship in pairs( findCraft( nil, 1 ) ) do
            if live( ship ) and distanceSquared( ship.position,
                self.cardBase.position ) <= 4000000 then
                self.cardBaseAnnounced = true
                Media:playSound( "a2_kling08_tachyon.wav" )
                break
            end
        end
    end

    if self:allShipyardsDestroyed( ) then
        self:complete( 4 )
        self:startSuccess( )
    end
end

function A2Kling08Mission:cineractiveUpdate( ) end

function A2Kling08Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Kling08Mission( ) )
