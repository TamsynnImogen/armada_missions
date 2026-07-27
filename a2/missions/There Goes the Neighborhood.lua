-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 4 CONVERSION
-- Behaviour evidence: a2_borg04S.dsl, a2_borg04R.drl, a2_borg04.bzn.

class 'A2Borg04Mission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
        and ( entity.crew == nil or entity.crew > 0 )
end

local function odfBase( entity )
    return string.gsub( string.lower( entity.odf or "" ), "%.odf$", "" )
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

local function findCraft( team, odf )
    odf = odf and string.gsub( string.lower( odf ), "%.odf$", "" ) or nil
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( team == nil or entity.player.number == team )
            and ( odf == nil or odfBase( entity ) == odf )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( ) or { }
end

local PLANET_LABELS = { "objectPlanet1", "objectPlanet2", "objectPlanet3", "objectPlanet4" }
local PLANET_AUDIO = {
    "a2_borg04_planet_attack_1.wav", "a2_borg04_planet_attack_2.wav",
    "a2_borg04_planet_attack_3.wav", "a2_borg04_planet_attack_4.wav"
}

function A2Borg04Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.nexusBuilt = false
    self.techBuilt = false
    self.romulansEncountered = false
    self.rescueSent = { false, false, false, false }
    self.siegeSent = { false, false, false, false }
end

function A2Borg04Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b04_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg04Mission:setup( )
    print( "[ThereGoesTheNeighborhood] clean-room a2_borg04 conversion loaded" )
    self.player = Player( 1 )
    self.romulan = Player( 4 )
    self.player:setRelation( self.romulan, Player.Relation.Enemy )
    self.romulan:setRelation( self.player, Player.Relation.Enemy )
    self.queen = findLabel( "objectBorgQueen" ) or findCraft( 1, "bqueen" )[ 1 ]
    Objectives:load( "a2_borg04_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg04Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -500, 230, -700 ) )
        Cineractive:lookAt( self.queen )
    end
    Media:playMusic( "Mbor15a.wav" )
    UI:addTitle( "THERE GOES THE NEIGHBORHOOD", 50, 50, 8.0, true )
    self:schedule( "queen_intro_1", 4.0, "playQueenIntro1" )
    self:schedule( "queen_intro_2", 20.0, "playQueenIntro2" )
    self:schedule( "opening_done", 38.0, "finishOpening" )
end

function A2Borg04Mission:playQueenIntro1( )
    if self.phase == "opening" then Media:playSound( "a2_borg04_queen_intro_1.wav" ) end
end

function A2Borg04Mission:playQueenIntro2( )
    if self.phase == "opening" then Media:playSound( "a2_borg04_queen_intro_2.wav" ) end
end

function A2Borg04Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg04_main.txt" )
    Objectives.visible = true
    self.romulan:loadAIP( "a2_borg04_build_list.aip" )
    self.phase = "gameplay"
    print( "[ThereGoesTheNeighborhood] gameplay started" )
end

function A2Borg04Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg04Mission:planet( index )
    return findLabel( PLANET_LABELS[ index ] )
end

function A2Borg04Mission:nearestPlayerCraft( position )
    local nearest, nearestDistance = nil, 1000000000
    for _, ship in pairs( findCraft( 1, nil ) ) do
        local distance = distanceSquared( ship.position, position )
        if distance < nearestDistance then nearest, nearestDistance = ship, distance end
    end
    return nearest
end

function A2Borg04Mission:sendRomulanAttack( target, limit )
    if not live( target ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 4, nil ) ) do
        local odf = odfBase( ship )
        if not string.find( odf, "base", 1, true )
            and not string.find( odf, "yard", 1, true )
            and not string.find( odf, "mining", 1, true )
            and not string.find( odf, "resear", 1, true )
            and not string.find( odf, "turret", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= limit then break end
        end
    end
end

function A2Borg04Mission:sendRescue( index )
    local planet = self:planet( index )
    if not live( planet ) then return end
    local intruder = self:nearestPlayerCraft( planet.position )
    self:sendRomulanAttack( intruder, 4 )
end

function A2Borg04Mission:sendSiege( index )
    local planet = self:planet( index )
    self:sendRomulanAttack( planet, 6 )
end

function A2Borg04Mission:siegePlanet1( ) self:sendSiege( 1 ) end
function A2Borg04Mission:siegePlanet2( ) self:sendSiege( 2 ) end
function A2Borg04Mission:siegePlanet3( ) self:sendSiege( 3 ) end
function A2Borg04Mission:siegePlanet4( ) self:sendSiege( 4 ) end

function A2Borg04Mission:playerNearRomulans( )
    for _, playerShip in pairs( findCraft( 1, nil ) ) do
        for _, romulanShip in pairs( findCraft( 4, nil ) ) do
            if distanceSquared( playerShip.position, romulanShip.position ) <= 2500 * 2500 then
                return true
            end
        end
    end
    return false
end

function A2Borg04Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 4 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "GRID 967 ASSIMILATED", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    Media:playSound( "a2_borg04_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg04Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg04Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE BORG QUEEN HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    Media:playSound( "a2_borg08_queen_killed.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg04Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg04Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = findLabel( "objectBorgQueen" ) or self.queen
    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( )
        return
    end

    if #findCraft( 1, "bbase" ) > 0 then self.nexusBuilt = true end
    if #findCraft( 1, "btechass" ) > 0 then self.techBuilt = true end

    if not self.romulansEncountered and self:playerNearRomulans( ) then
        self.romulansEncountered = true
        Media:playSound( "a2_borg04_romulan_alert.wav" )
    end

    local allCaptured = true
    for index = 1, 4 do
        local planet = self:planet( index )
        local captured = live( planet ) and planet.player.number == 1
        if not captured then allCaptured = false end
        if live( planet ) and planet.underAttack and not captured and not self.rescueSent[ index ] then
            self.rescueSent[ index ] = true
            Media:playSound( PLANET_AUDIO[ index ] )
            self:sendRescue( index )
        end
        if captured and not self.siegeSent[ index ] then
            self.siegeSent[ index ] = true
            self:schedule( "planet_" .. tostring( index ) .. "_siege", 45.0,
                "siegePlanet" .. tostring( index ) )
        end
    end

    self:setObjective( 1, self.nexusBuilt )
    self:setObjective( 2, self.techBuilt )
    self:setObjective( 3, allCaptured )
    if self.nexusBuilt and self.techBuilt and allCaptured then self:startSuccess( ) end
end

function A2Borg04Mission:cineractiveUpdate( ) end
function A2Borg04Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg04Mission( ) )
