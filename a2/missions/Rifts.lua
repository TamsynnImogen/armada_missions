-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 10 CONVERSION
-- Behaviour evidence: a2_borg10S.dsl, a2_borg10R.drl, a2_borg10.bzn.

class 'A2Borg10Mission'

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

local GROUP_LABELS = {
    {
        "ALPHA 8472_bat1364", "ALPHA 8472_cru1365", "ALPHA 8472_des1366",
        "ALPHA 8472_des1367", "ALPHA 8472_sco1368"
    },
    {
        "BETA 8472_bat1137", "BETA 8472_beh1141",
        "BETA 8472_cru1138", "BETA 8472_cru1139"
    },
    {
        "GAMMA 8472_bat1135", "GAMMA 8472_bat1136",
        "GAMMA 8472_cru1149", "GAMMA 8472_cru1150"
    }
}

function A2Borg10Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.tradingBuilt = false
    self.betaFound = false
    self.gammaFound = false
    self.makerFound = false
    self.groupActive = { false, false, false }
    self.groupSeen = { false, false, false }
    self.groupDefended = { false, false, false }
    self.supplyStarted = false
end

function A2Borg10Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b10_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg10Mission:setup( )
    print( "[Rifts] clean-room a2_borg10 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 3 )
    self.player:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.player, Player.Relation.Enemy )
    self.queen = findLabel( "Borg Queen's Diamond" ) or findCraft( 1, "bqueen" )[ 1 ]
    self.enterprise = findLabel( "Enterprise NCC 1701-E" ) or findCraft( 1, "fente" )[ 1 ]
    self.incursion = findLabel( "USS Incursion" ) or findCraft( 1, "fincursion" )[ 1 ]
    self.rifts = {
        findLabel( "RIFT_ALPHA" ), findLabel( "RIFT_BETA" ), findLabel( "RIFT_GAMMA" )
    }
    self.riftMaker = findLabel( "8472_bigmomma" )
    Objectives:load( "a2_borg10_primary.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg10Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "RIFTS", 50, 50, 8.0, true )
    Media:playMusic( "Mbor300.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 38.0, "finishOpening" )
end

function A2Borg10Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg10_queen_intro.wav" ) end
end

function A2Borg10Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg10_primary.txt" )
    Objectives.visible = true
    self.species:loadAIP( "species8472_build_list.aip" )
    self.phase = "gameplay"
    self:schedule( "alpha_fleet", 180.0, "sendAlphaFleet" )
    self:schedule( "beta_fleet", 420.0, "sendBetaFleet" )
    self:schedule( "gamma_fleet", 660.0, "sendGammaFleet" )
    print( "[Rifts] gameplay started" )
end

function A2Borg10Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg10Mission:playerNear( target, radius )
    if not live( target ) then return false end
    for _, entity in pairs( findCraft( 1, nil ) ) do
        if distanceSquared( entity.position, target.position ) <= radius * radius then return true end
    end
    return false
end

function A2Borg10Mission:groupShips( index )
    local ships = { }
    for _, label in ipairs( GROUP_LABELS[ index ] ) do
        local ship = findLabel( label )
        if live( ship ) then ships[ #ships + 1 ] = ship end
    end
    if #ships > 0 then self.groupSeen[ index ] = true end
    return ships
end

function A2Borg10Mission:sendGroup( index )
    self.groupActive[ index ] = true
    local rift = self.rifts[ index ]
    if not live( rift ) then return end
    for _, ship in ipairs( self:groupShips( index ) ) do
        pcall( function( ) ship:giveOrder( GameObject.Order.Go, rift.position ) end )
    end
end

function A2Borg10Mission:sendAlphaFleet( )
    Media:playMovie( "a2_borg10_alpha_fleet.bik" )
    self:sendGroup( 1 )
end

function A2Borg10Mission:sendBetaFleet( )
    Media:playMovie( "a2_borg10_beta_fleet.bik" )
    self:sendGroup( 2 )
end

function A2Borg10Mission:sendGammaFleet( )
    Media:playMovie( "a2_borg10_gamma_fleet.bik" )
    self:sendGroup( 3 )
end

function A2Borg10Mission:supplyShipment( )
    if self.phase ~= "gameplay" or not self.tradingBuilt then return end
    self.player.resources.dilithium = self.player.resources.dilithium + 2000
    self.player.resources.metal = self.player.resources.metal + 2000
    self:schedule( "supply_shipment", 180.0, "supplyShipment" )
end

function A2Borg10Mission:updateGroup( index )
    local ships = self:groupShips( index )
    if self.groupActive[ index ] and live( self.rifts[ index ] ) then
        for _, ship in ipairs( ships ) do
            if distanceSquared( ship.position, self.rifts[ index ].position ) <= 450 * 450 then
                self:startFailure( "a2_borg10_queen_ships_escaped.wav",
                    "A SPECIES 8472 FLEET HAS ESCAPED" )
                return
            end
        end
    end
    if self.groupSeen[ index ] and #ships == 0 then self.groupDefended[ index ] = true end
end

function A2Borg10Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 9 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "THE RIFT MAKER HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playMusic( "mfed10.wav" )
    Media:playMovie( "a2_borg10_queen_victory.bik" )
    self:schedule( "success", 14.0, "finishSuccess" )
end

function A2Borg10Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg10Mission:startFailure( sound, title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg10Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg10Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = findLabel( "Borg Queen's Diamond" ) or self.queen
    self.enterprise = findLabel( "Enterprise NCC 1701-E" ) or self.enterprise
    self.incursion = findLabel( "USS Incursion" ) or self.incursion
    self.rifts[ 1 ] = findLabel( "RIFT_ALPHA" ) or self.rifts[ 1 ]
    self.rifts[ 2 ] = findLabel( "RIFT_BETA" ) or self.rifts[ 2 ]
    self.rifts[ 3 ] = findLabel( "RIFT_GAMMA" ) or self.rifts[ 3 ]
    self.riftMaker = findLabel( "8472_bigmomma" ) or self.riftMaker

    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( "a2_borg08_queen_killed.wav", "THE BORG QUEEN HAS BEEN LOST" )
        return
    end
    if not live( self.enterprise ) or self.enterprise.player.number ~= 1 then
        self:startFailure( "a2_borg08_picard_killed.wav", "THE ENTERPRISE HAS BEEN LOST" )
        return
    end
    if not live( self.incursion ) or self.incursion.player.number ~= 1 then
        self:startFailure( "a2_borg01_defeat.wav", "THE USS INCURSION HAS BEEN LOST" )
        return
    end

    if not self.tradingBuilt and #findCraft( 1, "ftrading" ) > 0 then
        self.tradingBuilt = true
        if not self.supplyStarted then
            self.supplyStarted = true
            self:schedule( "supply_shipment", 30.0, "supplyShipment" )
        end
    end
    if not self.betaFound and self:playerNear( self.rifts[ 2 ], 2500 ) then self.betaFound = true end
    if not self.gammaFound and self:playerNear( self.rifts[ 3 ], 2500 ) then self.gammaFound = true end
    if not self.makerFound and self:playerNear( self.riftMaker, 2500 ) then
        self.makerFound = true
        Media:playMovie( "a2_borg10_queen_rift_maker_found.bik" )
    end

    self:updateGroup( 1 )
    self:updateGroup( 2 )
    self:updateGroup( 3 )
    if self.ending then return end

    local makerDestroyed = not live( self.riftMaker )
    if makerDestroyed then self.makerFound = true end
    self:setObjective( 1, self.tradingBuilt )
    self:setObjective( 2, self.betaFound )
    self:setObjective( 3, self.gammaFound )
    self:setObjective( 4, self.groupDefended[ 1 ] )
    self:setObjective( 5, self.groupDefended[ 2 ] )
    self:setObjective( 6, self.groupDefended[ 3 ] )
    self:setObjective( 7, self.makerFound )
    self:setObjective( 8, makerDestroyed )

    if self.tradingBuilt and self.betaFound and self.gammaFound
        and self.groupDefended[ 1 ] and self.groupDefended[ 2 ] and self.groupDefended[ 3 ]
        and self.makerFound and makerDestroyed then
        self:startSuccess( )
    end
end

function A2Borg10Mission:cineractiveUpdate( ) end
function A2Borg10Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg10Mission( ) )
