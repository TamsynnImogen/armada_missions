-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 7 CONVERSION
-- Behaviour evidence: a2_borg07S.dsl, a2_borg07R.drl, a2_borg07.bzn.

class 'A2Borg07Mission'

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

function A2Borg07Mission:__init( )
    self.phase = "loading"
    self.stage = "locate"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.nebulaLocated = false
    self.nebulaCleared = false
    self.turretsBuilt = false
end

function A2Borg07Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b07_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg07Mission:setup( )
    print( "[StrangeBedfellows] clean-room a2_borg07 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 2 )
    self.federation = Player( 3 )
    self.player:setRelation( self.species, Player.Relation.Enemy )
    self.species:setRelation( self.player, Player.Relation.Enemy )
    self.player:setRelation( self.federation, Player.Relation.Ally )
    self.federation:setRelation( self.player, Player.Relation.Ally )
    self.queen = findLabel( "Diamond" ) or findCraft( 1, "bqueen" )[ 1 ]
    self.tachyonNebula = findLabel( "TachyonNebula" )
    Objectives:load( "a2_borg07_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg07Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -500, 230, -700 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "STRANGE BEDFELLOWS", 50, 50, 8.0, true )
    Media:playMusic( "Mbor300.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 38.0, "finishOpening" )
end

function A2Borg07Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg07_intro.wav" ) end
end

function A2Borg07Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg07_A.txt" )
    Objectives.visible = true
    self.species:loadAIP( "a2_borg07_basic.aip" )
    self.phase = "gameplay"
    self:schedule( "attack_wave_1", 150.0, "attackBorg" )
    self:schedule( "attack_wave_2", 300.0, "attackBorg" )
    self:schedule( "attack_wave_3", 450.0, "attackBorg" )
    self:schedule( "attack_wave_4", 600.0, "attackBorg" )
    self:schedule( "attack_wave_5", 750.0, "attackBorg" )
    self:schedule( "attack_wave_6", 900.0, "attackBorg" )
    self:schedule( "attack_wave_7", 1050.0, "attackBorg" )
    print( "[StrangeBedfellows] gameplay started" )
end

function A2Borg07Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg07Mission:nearCount( team, odf, radius )
    if not live( self.tachyonNebula ) then return 0 end
    local count = 0
    for _, entity in pairs( findCraft( team, odf ) ) do
        if distanceSquared( entity.position, self.tachyonNebula.position ) <= radius * radius then
            count = count + 1
        end
    end
    return count
end

function A2Borg07Mission:playerNearNebula( )
    if not live( self.tachyonNebula ) then return false end
    for _, entity in pairs( findCraft( 1, nil ) ) do
        if distanceSquared( entity.position, self.tachyonNebula.position ) <= 2500 * 2500 then
            return true
        end
    end
    return false
end

function A2Borg07Mission:attackBorg( )
    if self.phase ~= "gameplay" then return end
    local target = self.queen or findCraft( 1, "bbase" )[ 1 ]
    if not live( target ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 2, nil ) ) do
        local odf = odfBase( ship )
        if not string.find( odf, "mother", 1, true )
            and not string.find( odf, "active", 1, true )
            and not string.find( odf, "passive", 1, true )
            and not string.find( odf, "collector", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= 3 then break end
        end
    end
end

function A2Borg07Mission:beginTurretStage( )
    if self.stage ~= "clear" then return end
    self.stage = "turrets"
    self.nebulaCleared = true
    Objectives:load( "a2_borg07_B.txt" )
    Objectives.visible = true
    self:setObjective( 1, true )
    self:setObjective( 2, true )
    Media:playMovie( "a2_borg07_cleared.bik" )
    Media:playSound( "a2_borg07_build.wav" )
end

function A2Borg07Mission:beginAssemblerStage( )
    if self.stage ~= "turrets" then return end
    self.stage = "assemblers"
    self.turretsBuilt = true
    Objectives:load( "a2_borg07_C.txt" )
    Objectives.visible = true
    self:setObjective( 1, true )
    self:setObjective( 2, true )
    self:setObjective( 3, true )
end

function A2Borg07Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 5 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.tachyonNebula ) then
        Cineractive:lookFrom( self.tachyonNebula )
        Cineractive:setCameraOffset( Vector( -560, 260, -760 ) )
        Cineractive:lookAt( self.tachyonNebula )
    end
    UI:addTitle( "TRANSWARP PORTAL RECONSTRUCTED", 50, 50, 8.0, true )
    Media:playMusic( "Mkli30.wav" )
    Media:playSound( "a2_borg07_success1_1.wav" )
    self:schedule( "success_second", 7.0, "playSecondSuccess" )
    self:schedule( "success", 15.0, "finishSuccess" )
end

function A2Borg07Mission:playSecondSuccess( )
    if self.phase == "success" then Media:playSound( "a2_borg07_success2.wav" ) end
end

function A2Borg07Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg07Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE BORG QUEEN HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "Mbor300.wav" )
    Media:playSound( "a2_borg08_queen_killed.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg07Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg07Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = findLabel( "Diamond" ) or self.queen
    self.tachyonNebula = findLabel( "TachyonNebula" ) or self.tachyonNebula
    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( )
        return
    end

    if self.stage == "locate" and self:playerNearNebula( ) then
        self.stage = "clear"
        self.nebulaLocated = true
        self:setObjective( 1, true )
        Media:playMovie( "a2_borg07_located.bik" )
    elseif self.stage == "clear" and self:nearCount( 2, nil, 1000 ) == 0 then
        self:beginTurretStage( )
    elseif self.stage == "turrets" then
        local turrets = self:nearCount( 1, "bturret", 1000 )
            + self:nearCount( 1, "bturret2", 1000 )
        self:setObjective( 3, turrets >= 10 )
        if turrets >= 10 then self:beginAssemblerStage( ) end
    elseif self.stage == "assemblers" then
        local assemblers = self:nearCount( 1, "bconst", 600 )
        self:setObjective( 4, assemblers >= 3 )
        if assemblers >= 3 then self:startSuccess( ) end
    end
end

function A2Borg07Mission:cineractiveUpdate( ) end
function A2Borg07Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg07Mission( ) )
