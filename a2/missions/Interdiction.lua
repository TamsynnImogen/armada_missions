-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 3 CONVERSION
-- Behaviour evidence: a2_borg03S.dsl, a2_borg03R.drl, a2_borg03.bzn.

class 'A2Borg03Mission'

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

local OUTPOST_LABELS = {
    "rmining1015", "rbase1017", "ryard1018", "rturret1019",
    "rturret1021", "rturret1022", "rturret1023", "rturret1024",
    "rtrading1025", "rturret1026", "rmining1027", "rsuperbl1028",
    "ryard21029", "rturret1030", "rresear21031"
}

function A2Borg03Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.nexusBuilt = false
    self.wedgesBuilt = false
    self.outpostDiscovered = false
end

function A2Borg03Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b03_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg03Mission:setup( )
    print( "[Interdiction] clean-room a2_borg03 conversion loaded" )
    self.player = Player( 1 )
    self.federation = Player( 2 )
    self.traders = Player( 3 )
    self.romulan = Player( 4 )
    for _, enemy in ipairs( { self.federation, self.traders, self.romulan } ) do
        self.player:setRelation( enemy, Player.Relation.Enemy )
        enemy:setRelation( self.player, Player.Relation.Enemy )
    end
    self.outpost = { }
    for _, label in ipairs( OUTPOST_LABELS ) do
        local station = findLabel( label )
        if live( station ) then self.outpost[ #self.outpost + 1 ] = station end
    end
    Objectives:load( "a2_borg03_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg03Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    local subject = findLabel( "pb_clssd1003" ) or findCraft( 1, nil )[ 1 ]
    if live( subject ) then
        Cineractive:lookFrom( subject )
        Cineractive:setCameraOffset( Vector( -500, 230, -700 ) )
        Cineractive:lookAt( subject )
    end
    UI:addTitle( "INTERDICTION", 50, 50, 8.0, true )
    Media:playMusic( "Mbor30.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 36.0, "finishOpening" )
end

function A2Borg03Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg03_intro.wav" ) end
end

function A2Borg03Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg03_main.txt" )
    Objectives.visible = true
    self.romulan:loadAIP( "a2_borg03_build_list.aip" )
    self.phase = "gameplay"
    self:schedule( "attack_1", 240.0, "attackNexus" )
    self:schedule( "attack_2", 480.0, "attackNexus" )
    self:schedule( "attack_3", 720.0, "attackNexus" )
    self:schedule( "attack_4", 960.0, "attackNexus" )
    print( "[Interdiction] gameplay started" )
end

function A2Borg03Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg03Mission:attackNexus( )
    if self.phase ~= "gameplay" then return end
    local nexus = findCraft( 1, "bbase" )[ 1 ]
    if not live( nexus ) then return end
    local sent = 0
    for _, ship in pairs( findCraft( 4, nil ) ) do
        local odf = odfBase( ship )
        if not string.find( odf, "base", 1, true )
            and not string.find( odf, "yard", 1, true )
            and not string.find( odf, "mining", 1, true )
            and not string.find( odf, "turret", 1, true ) then
            pcall( function( ) ship:giveOrder( GameObject.Order.Attack, nexus ) end )
            sent = sent + 1
            if sent >= 5 then break end
        end
    end
end

function A2Borg03Mission:outpostAlive( )
    if #self.outpost > 0 then
        for _, station in ipairs( self.outpost ) do
            if live( station ) and station.player.number == 4 then return true end
        end
        return false
    end
    for _, entity in pairs( findCraft( 4, nil ) ) do
        local odf = odfBase( entity )
        if string.find( odf, "base", 1, true ) or string.find( odf, "yard", 1, true )
            or string.find( odf, "turret", 1, true ) or string.find( odf, "resear", 1, true )
            or string.find( odf, "mining", 1, true ) then return true end
    end
    return false
end

function A2Borg03Mission:playerNearOutpost( )
    local target = self.outpost[ 1 ] or findCraft( 4, "rbase" )[ 1 ]
    if not live( target ) then return false end
    for _, ship in pairs( findCraft( 1, nil ) ) do
        if distanceSquared( ship.position, target.position ) <= 2500 * 2500 then return true end
    end
    return false
end

function A2Borg03Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 4 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    local nexus = findCraft( 1, "bbase" )[ 1 ]
    if live( nexus ) then
        Cineractive:lookFrom( nexus )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( nexus )
    end
    UI:addTitle( "OUTPOST ELIMINATED", 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( "a2_borg03_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg03Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg03Mission:startFailure( title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( "a2_borg01_defeat.wav" )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg03Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg03Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    local nexus = findCraft( 1, "bbase" )[ 1 ]
    if live( nexus ) then self.nexusBuilt = true end
    self.wedgesBuilt = #findCraft( 1, "bassault" ) >= 2

    if self.nexusBuilt and not live( nexus ) then
        self:startFailure( "THE NEXUS HAS BEEN DESTROYED" )
        return
    end
    if #findCraft( 1, nil ) == 0 then
        self:startFailure( "ALL BORG FORCES HAVE BEEN DESTROYED" )
        return
    end

    if not self.outpostDiscovered and self:playerNearOutpost( ) then
        self.outpostDiscovered = true
        Objectives:load( "a2_borg03_sec.txt" )
        Objectives.visible = true
        Media:playSound( "a2_borg03_sec.wav" )
    end

    self:setObjective( 1, self.nexusBuilt )
    self:setObjective( 2, self.wedgesBuilt )
    if self.outpostDiscovered then self:setObjective( 3, not self:outpostAlive( ) ) end
    if self.nexusBuilt and self.wedgesBuilt and not self:outpostAlive( ) then
        self:startSuccess( )
    end
end

function A2Borg03Mission:cineractiveUpdate( ) end
function A2Borg03Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg03Mission( ) )
