-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 6 CONVERSION
-- Behaviour evidence: a2_borg06S.dsl, a2_borg06R.drl, a2_borg06.bzn.

class 'A2Borg06Mission'

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

function A2Borg06Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.choktuCaptured = false
    self.nexusBuilt = false
    self.choktuDefendersSent = false
end

function A2Borg06Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b06_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg06Mission:setup( )
    print( "[Interception] clean-room a2_borg06 conversion loaded" )
    self.player = Player( 1 )
    self.klingon = Player( 3 )
    self.player:setRelation( self.klingon, Player.Relation.Enemy )
    self.klingon:setRelation( self.player, Player.Relation.Enemy )
    self.choktu = findLabel( "Choktu" )
    self.klingonBase = findLabel( "klingbase" )
    self.institute = findLabel( "kupgrade1139" )
    self.queen = findLabel( "Queen" ) or findCraft( 1, "bqueen" )[ 1 ]
    Objectives:load( "a2_borg06_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg06Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -500, 230, -700 ) )
        Cineractive:lookAt( self.queen )
    end
    UI:addTitle( "INTERCEPTION", 50, 50, 8.0, true )
    Media:playMusic( "Mbor300.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 36.0, "finishOpening" )
end

function A2Borg06Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg06_intro.wav" ) end
end

function A2Borg06Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg06_main.txt" )
    Objectives.visible = true
    self.klingon:loadAIP( "a2_borg06_build.aip" )
    self.phase = "gameplay"
    self:schedule( "base_siege_1", 240.0, "attackNexus" )
    self:schedule( "base_siege_2", 480.0, "attackNexus" )
    print( "[Interception] gameplay started" )
end

function A2Borg06Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg06Mission:nearestPlayerCraft( position )
    local nearest, nearestDistance = nil, 1000000000
    for _, ship in pairs( findCraft( 1, nil ) ) do
        local distance = distanceSquared( ship.position, position )
        if distance < nearestDistance then nearest, nearestDistance = ship, distance end
    end
    return nearest
end

function A2Borg06Mission:sendKlingons( target, limit )
    if not live( target ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 3, nil ) ) do
        local odf = odfBase( ship )
        if ship.label ~= "klingbase" and ship.label ~= "kupgrade1139"
            and not string.find( odf, "base", 1, true )
            and not string.find( odf, "yard", 1, true )
            and not string.find( odf, "resear", 1, true )
            and not string.find( odf, "mining", 1, true )
            and not string.find( odf, "turret", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
            sent = sent + 1
            if sent >= limit then break end
        end
    end
end

function A2Borg06Mission:attackNexus( )
    self:sendKlingons( findCraft( 1, "bbase" )[ 1 ] or self.queen, 6 )
end

function A2Borg06Mission:defendChoktu( )
    if not live( self.choktu ) then return end
    self:sendKlingons( self:nearestPlayerCraft( self.choktu.position ), 5 )
end

function A2Borg06Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 5 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.institute ) then
        Cineractive:lookFrom( self.institute )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.institute )
    end
    UI:addTitle( "KLINGON RESEARCH ASSIMILATED", 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    Media:playSound( "a2_borg06_win.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg06Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg06Mission:startFailure( )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( "THE BORG QUEEN HAS BEEN LOST", 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    Media:playSound( "a2_borg08_queen_killed.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg06Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg06Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.choktu = findLabel( "Choktu" ) or self.choktu
    self.klingonBase = findLabel( "klingbase" ) or self.klingonBase
    self.institute = findLabel( "kupgrade1139" ) or self.institute
    self.queen = findLabel( "Queen" ) or self.queen

    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( )
        return
    end

    if live( self.choktu ) and self.choktu.player.number == 1 then self.choktuCaptured = true end
    if #findCraft( 1, "bbase" ) > 0 then self.nexusBuilt = true end
    if live( self.choktu ) and self.choktu.underAttack and not self.choktuCaptured
        and not self.choktuDefendersSent then
        self.choktuDefendersSent = true
        self:defendChoktu( )
    end

    local baseDestroyed = not live( self.klingonBase )
    local instituteCaptured = live( self.institute ) and self.institute.player.number == 1
    self:setObjective( 1, self.choktuCaptured )
    self:setObjective( 2, self.nexusBuilt )
    self:setObjective( 3, baseDestroyed )
    self:setObjective( 4, instituteCaptured )
    if self.choktuCaptured and self.nexusBuilt and baseDestroyed and instituteCaptured then
        self:startSuccess( )
    end
end

function A2Borg06Mission:cineractiveUpdate( ) end
function A2Borg06Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg06Mission( ) )
