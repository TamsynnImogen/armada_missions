-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 2 CONVERSION
-- Behaviour evidence: a2_borg02S.dsl, a2_borg02R.drl, a2_borg02.bzn.

class 'A2Borg02Mission'

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

local function firstQueen( )
    for _, label in ipairs( { "bqueen", "Borg_Queen_s_Diamond", "Queen" } ) do
        local queen = findLabel( label )
        if live( queen ) then return queen end
    end
    return findCraft( 1, "bqueen" )[ 1 ]
end

local function objectiveTarget( entity )
    if not live( entity ) then return false end
    local odf = odfBase( entity )
    return not string.find( odf, "freight", 1, true )
        and not string.find( odf, "cargo", 1, true )
        and not string.find( odf, "const", 1, true )
        and not string.find( odf, "colony", 1, true )
end

function A2Borg02Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.researchComplete = false
    self.firstContact = false
end

function A2Borg02Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b02_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg02Mission:setup( )
    print( "[PinkSlips] clean-room a2_borg02 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 2 )
    self.federation = Player( 3 )
    for _, enemy in ipairs( { self.species, self.federation } ) do
        self.player:setRelation( enemy, Player.Relation.Enemy )
        enemy:setRelation( self.player, Player.Relation.Enemy )
    end
    self.species:setRelation( self.federation, Player.Relation.Enemy )
    self.federation:setRelation( self.species, Player.Relation.Enemy )
    self.queen = firstQueen( )
    Objectives:load( "a2_borg02_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg02Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -500, 230, -700 ) )
        Cineractive:lookAt( self.queen )
    end
    Media:playMusic( "Mbor30.wav" )
    UI:addTitle( "PINK SLIPS", 50, 50, 8.0, true )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 42.0, "finishOpening" )
end

function A2Borg02Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg02_intro_1.wav" ) end
end

function A2Borg02Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg02_A.txt" )
    Objectives.visible = true
    self.species:loadAIP( "a2_borg02_build_list.aip" )
    self.federation:loadAIP( "a2_borg02_federation_build_list.aip" )
    self.phase = "gameplay"
    self:schedule( "federation_attack", 300.0, "federationAttack" )
    self:schedule( "species_attack", 420.0, "speciesAttack" )
    print( "[PinkSlips] gameplay started" )
end

function A2Borg02Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg02Mission:orderAttack( team )
    if self.phase ~= "gameplay" then return end
    local target = self.queen
    local sent = 0
    for _, ship in pairs( findCraft( team, nil ) ) do
        if objectiveTarget( ship ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= 6 then break end
        end
    end
end

function A2Borg02Mission:federationAttack( )
    self:orderAttack( 3 )
    self:schedule( "federation_repeat", 300.0, "federationAttack" )
end

function A2Borg02Mission:speciesAttack( )
    self:orderAttack( 2 )
    self:schedule( "species_repeat", 330.0, "speciesAttack" )
end

function A2Borg02Mission:hostilesRemaining( )
    for _, team in ipairs( { 2, 3 } ) do
        for _, entity in pairs( findCraft( team, nil ) ) do
            if objectiveTarget( entity ) then return true end
        end
    end
    return false
end

function A2Borg02Mission:startSuccess( )
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
    UI:addTitle( "ALL RESISTANCE ELIMINATED", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    Media:playSound( "a2_borg02_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg02Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg02Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE BORG QUEEN HAS BEEN DESTROYED", 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( "a2_borg02_failure.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg02Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg02Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = firstQueen( ) or self.queen
    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( )
        return
    end
    if not self.firstContact and #findCraft( 2, nil ) > 0 then
        self.firstContact = true
        Media:playMovie( "spe_att_07.bik" )
    end
    self.researchComplete = #findCraft( 1, "borpod1" ) > 0
    self:setObjective( 1, self.researchComplete )
    self:setObjective( 3, true )
    if self.researchComplete and not self:hostilesRemaining( ) then self:startSuccess( ) end
end

function A2Borg02Mission:cineractiveUpdate( ) end
function A2Borg02Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg02Mission( ) )
