-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 8 CONVERSION
-- Behaviour evidence: a2_borg08S.dsl, a2_borg08R.drl, a2_borg08.bzn.

class 'A2Borg08Mission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
        and ( entity.crew == nil or entity.crew > 0 )
end

local function odfBase( entity )
    return string.gsub( string.lower( entity.odf or "" ), "%.odf$", "" )
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

function A2Borg08Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
end

function A2Borg08Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b08_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg08Mission:setup( )
    print( "[TidalWave] clean-room a2_borg08 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 2 )
    self.federation = Player( 3 )
    self.player:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.player, Player.Relation.Enemy )
    self.federation:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.federation, Player.Relation.Enemy )
    self.player:setRelation( self.federation, Player.Relation.Ally )
    self.federation:setRelation( self.player, Player.Relation.Ally )
    self.queen = findLabel( "bqueen" ) or findCraft( 1, "bqueen" )[ 1 ]
    self.enterprise = findLabel( "enterprise" )
    self.nexus = findLabel( "bbase1964" ) or findCraft( 1, "bbase" )[ 1 ]
    Objectives:load( "a2_borg08_main_objectives.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg08Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.enterprise ) then
        Cineractive:lookFrom( self.enterprise )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.enterprise )
    end
    UI:addTitle( "TIDAL WAVE", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "queen_intro", 21.0, "playQueenIntro" )
    self:schedule( "opening_done", 40.0, "finishOpening" )
end

function A2Borg08Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg08_intro_1.wav" ) end
end

function A2Borg08Mission:playQueenIntro( )
    if self.phase == "opening" then Media:playMovie( "a2_borg08_intro_2_Queen_1.bik" ) end
end

function A2Borg08Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg08_main_objectives.txt" )
    Objectives.visible = true
    self.species:loadAIP( "a2_borg08_build_list.aip" )
    self.phase = "gameplay"
    self:schedule( "resource_injection_1", 180.0, "injectResources" )
    self:schedule( "siege_1", 240.0, "siegeBorg" )
    self:schedule( "resource_injection_2", 360.0, "injectResources" )
    self:schedule( "siege_2", 480.0, "siegeFederation" )
    self:schedule( "resource_injection_3", 600.0, "injectResources" )
    self:schedule( "siege_3", 720.0, "siegeBorg" )
    print( "[TidalWave] gameplay started" )
end

function A2Borg08Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg08Mission:injectResources( )
    pcall( function( )
        self.species.resources.biomatter = self.species.resources.biomatter + 3000
    end )
end

function A2Borg08Mission:sendSpeciesAttack( target, limit )
    if not live( target ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 2, nil ) ) do
        local label = string.lower( ship.label or "" )
        local odf = odfBase( ship )
        if not string.find( label, "cineractive_", 1, true )
            and not string.find( odf, "active", 1, true )
            and not string.find( odf, "passive", 1, true )
            and not string.find( odf, "collector", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= limit then break end
        end
    end
end

function A2Borg08Mission:siegeBorg( )
    self:sendSpeciesAttack( self.nexus or self.queen, 6 )
end

function A2Borg08Mission:siegeFederation( )
    self:sendSpeciesAttack( self.enterprise, 6 )
end

function A2Borg08Mission:speciesTargetCount( )
    local count = 0
    for _, entity in pairs( findCraft( 2, nil ) ) do
        local label = string.lower( entity.label or "" )
        local odf = odfBase( entity )
        if not string.find( label, "cineractive_", 1, true )
            and not string.find( odf, "collector", 1, true )
            and not string.find( odf, "constructor", 1, true )
            and not string.find( odf, "colony", 1, true ) then
            count = count + 1
        end
    end
    return count
end

function A2Borg08Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 3 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "SPECIES 8472 ELIMINATED", 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( "a2_borg08_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg08Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg08Mission:startFailure( sound, title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg08Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg08Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = findLabel( "bqueen" ) or self.queen
    self.enterprise = findLabel( "enterprise" ) or self.enterprise
    self.nexus = findLabel( "bbase1964" ) or self.nexus

    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( "a2_borg08_queen_killed.wav", "THE BORG QUEEN HAS BEEN LOST" )
        return
    end
    if not live( self.enterprise ) or self.enterprise.player.number ~= 1 then
        self:startFailure( "a2_borg08_picard_killed.wav", "THE ENTERPRISE HAS BEEN LOST" )
        return
    end

    local speciesEliminated = self:speciesTargetCount( ) == 0
    self:setObjective( 1, speciesEliminated )
    if speciesEliminated then self:startSuccess( ) end
end

function A2Borg08Mission:cineractiveUpdate( ) end
function A2Borg08Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg08Mission( ) )
