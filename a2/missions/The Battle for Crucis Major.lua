-- CLEAN-ROOM STAR TREK: ARMADA II KLINGON MISSION 7 CONVERSION
-- Behaviour evidence: a2_kling07S.dsl, a2_kling07R.drl, a2_kling07.bzn.

class 'A2Kling07Mission'

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
        print( "[CrucisMajor] order failed for " .. tostring( entity.label )
            .. ": " .. tostring( message ) )
    end
end

local SECONDARY_BASE = {
    "Team8Base", "Team8Refinery", "Team8Yard",
    "Team8Freighter", "Team8Freighter2",
    "Team8Turret1", "Team8Turret2", "Team8Turret3", "Team8Turret4",
    "Team8Turret5", "Team8Turret6", "Team8Turret7", "Team8Turret8",
    "Team8Turret9", "Team8Turret10", "Team8Turret11", "Team8Turret12",
    "Team8Turret13", "Team8Turret14"
}

local MOBILE_CARDASSIAN_ODFS = {
    [ "cdestroy.odf" ] = true, [ "cfrigate.odf" ] = true,
    [ "cscout.odf" ] = true, [ "ccruise1.odf" ] = true,
    [ "ccruise2.odf" ] = true, [ "ccruise3.odf" ] = true,
    [ "cbattle.odf" ] = true, [ "cbattle2.odf" ] = true,
    [ "cassault.odf" ] = true
}

function A2Kling07Mission:__init( )
    self.phase = "loading"
    self.ending = false
    self.ended = false
    self.timerSerial = 0
    self.timers = { }
    self.shockwaveBuilt = false
    self.jachengBuilt = false
    self.cardassiansDestroyed = false
    self.firstBaseStanding = true
    self.retreating = false
    self.secondaryBaseTransferred = false
end

function A2Kling07Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2k07_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Kling07Mission:setup( )
    print( "[CrucisMajor] clean-room a2_kling07 conversion loaded" )
    self.player = Player( 1 )
    self.cardassian = Player( 2 )
    self.reserve = Player( 8 )
    self.player:setRelation( self.cardassian, Player.Relation.Enemy )
    self.cardassian:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.reserve, Player.Relation.Ally )
    self.reserve:setRelation( self.player, Player.Relation.Ally )
    self.cardassian:setRelation( self.reserve, Player.Relation.Enemy )
    self.reserve:setRelation( self.cardassian, Player.Relation.Enemy )
    Objectives:load( "a2_kling07_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Kling07Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    self.martok = findLabel( "Martok" )
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -420, 190, -560 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "BATTLE OF CRUCIS MAJOR", 50, 50, 10.0, true )
    UI:addSubtitle( "Crucis Major System", 50, 85, 10.0, true )
    Media:playMusic( "mkli300.wav" )
    self:schedule( "intro_voice", 7.0, "playIntroVoice" )
    self:schedule( "opening_done", 30.0, "finishOpening" )
end

function A2Kling07Mission:playIntroVoice( )
    if self.phase == "opening" then Media:playSound( "a2_kling07_intro.wav" ) end
end

function A2Kling07Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    self.phase = "gameplay"
    self.martok = findLabel( "Martok" ) or self.martok
    self.firstBase = findLabel( "FirstBase" )
    self.cardassianBase = findLabel( "CardBase" )
    self.crucis = findLabel( "Crucis Major" )
    self.defenseCenter = ( valid( self.crucis ) and self.crucis.position )
        or ( valid( self.firstBase ) and self.firstBase.position )
        or Vector( 5250, 0, 5923 )
    Objectives:load( "a2_kling07_main.txt" )
    Objectives.visible = true
    self.cardassian:loadAIP( "a2_kling07_aggressive.aip" )

    -- Exact recovered timers: persistent pressure from 40 seconds, major
    -- Martok-targeting waves at 500 and 700 seconds, resource support at 1000.
    self:schedule( "first_base_check", 10.0, "checkFirstBase" )
    self:schedule( "more_attacks", 40.0, "moreAttacks" )
    self:schedule( "second_wave", 500.0, "secondAttackWave" )
    self:schedule( "third_wave", 700.0, "thirdAttackWave" )
    self:schedule( "kamikaze", 50.0, "kamikazeCheck" )
    print( "[CrucisMajor] gameplay started" )
end

function A2Kling07Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = true
    end
    Objectives.visible = true
end

function A2Kling07Mission:orderCardassianAttack( target, desired )
    if not live( target ) then return end
    local ordered = 0
    for _, ship in pairs( findCraft( nil, 2 ) ) do
        if live( ship ) and MOBILE_CARDASSIAN_ODFS[ string.lower( ship.odf or "" ) ] then
            safeOrder( ship, GameObject.Order.Attack, target )
            ordered = ordered + 1
            if ordered >= desired then break end
        end
    end
    print( "[CrucisMajor] Cardassian attack ordered ("
        .. tostring( ordered ) .. "/" .. tostring( desired ) .. ")" )
end

function A2Kling07Mission:playerUnitsNearFirstBase( )
    local count = 0
    for _, entity in pairs( findCraft( nil, 1 ) ) do
        if live( entity ) and distanceSquared( entity.position,
            self.defenseCenter ) <= 9000000 then
            count = count + 1
        end
    end
    return count
end

function A2Kling07Mission:checkFirstBase( )
    if self.phase ~= "gameplay" or not self.firstBaseStanding then return end
    if self:playerUnitsNearFirstBase( ) == 0 then
        self.firstBaseStanding = false
        self:startRetreat( )
        return
    end
    self:schedule( "first_base_check", 10.0, "checkFirstBase" )
end

function A2Kling07Mission:moreAttacks( )
    if self.phase ~= "gameplay" or not self.firstBaseStanding then return end
    self:orderCardassianAttack( self.firstBase or self.martok, 8 )
    self:schedule( "more_attacks", 30.0, "moreAttacks" )
end

function A2Kling07Mission:secondAttackWave( )
    self:orderCardassianAttack( self.martok, 7 )
end

function A2Kling07Mission:thirdAttackWave( )
    self:orderCardassianAttack( self.martok, 8 )
end

function A2Kling07Mission:kamikazeCheck( )
    if self.phase ~= "gameplay" then return end
    if not live( self.cardassianBase ) then
        for _, ship in pairs( findCraft( nil, 2 ) ) do
            if live( ship ) then
                safeOrder( ship, GameObject.Order.SearchAndDestroy, nil )
            end
        end
    end
    self:schedule( "kamikaze", 20.0, "kamikazeCheck" )
end

function A2Kling07Mission:startRetreat( )
    if self.retreating then return end
    self.retreating = true
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -420, 190, -560 ) )
        Cineractive:lookAt( self.martok )
    end
    Media:playMovie( "a2_kling07_retreat.bik" )
    UI:addTitle( "FALL BACK TO THE RESERVE BASE", 50, 50, 7.0, true )
    self:schedule( "transfer_base", 8.0, "transferSecondaryBase" )
end

function A2Kling07Mission:transferSecondaryBase( )
    if self.secondaryBaseTransferred then return end
    self.secondaryBaseTransferred = true
    local transferred = 0
    for _, label in ipairs( SECONDARY_BASE ) do
        local entity = findLabel( label )
        if valid( entity ) then
            local ok = pcall( function( )
                entity.player = self.player
                entity.perceivedTeam = self.player
                entity.forceOntoMap = true
            end )
            if ok then transferred = transferred + 1 end
        end
    end
    Cineractive.active = false
    self.retreating = false
    print( "[CrucisMajor] reserve base transferred ("
        .. tostring( transferred ) .. "/19 objects)" )
end

function A2Kling07Mission:checkBuildObjectives( )
    if not self.shockwaveBuilt and #findCraft( "ksuperbl.odf", 1 ) > 0 then
        self.shockwaveBuilt = true
        self:complete( 1 )
        Media:playSound( "a2_kling05_generic_Martok.wav" )
    end
    if not self.jachengBuilt and #findCraft( "ksuper.odf", 1 ) > 0 then
        self.jachengBuilt = true
        self:complete( 2 )
        Media:playSound( "a2_kling07_shockwave.wav" )
    end
end

function A2Kling07Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 4 do self:complete( index ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.martok ) then
        Cineractive:lookFrom( self.martok )
        Cineractive:setCameraOffset( Vector( -500, 220, -650 ) )
        Cineractive:lookAt( self.martok )
    end
    UI:addTitle( "CRUCIS MAJOR IS SECURE", 50, 50, 8.0, true )
    Media:playMusic( "mkli300.wav" )
    Media:playSound( "a2_kling07_win.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Kling07Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Kling07Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "MARTOK HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "mkli300.wav" )
    Media:playSound( "a2_kling07_lose.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Kling07Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Kling07Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end

    if not live( self.martok ) or self.martok.player.number ~= 1 then
        self:startFailure( )
        return
    end

    self:checkBuildObjectives( )
    if not self.cardassiansDestroyed and #findCraft( nil, 2 ) == 0 then
        self.cardassiansDestroyed = true
        self:complete( 3 )
        Media:playMovie( "a2_kling02_generic_objective_1.bik" )
    end

    if self.shockwaveBuilt and self.jachengBuilt and self.cardassiansDestroyed then
        self:startSuccess( )
    end
end

function A2Kling07Mission:cineractiveUpdate( ) end

function A2Kling07Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then
        self:finishOpening( )
    elseif forced and self.retreating then
        self:transferSecondaryBase( )
    end
end

MMM.register( A2Kling07Mission( ) )
