-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 5 CONVERSION
-- Behaviour evidence: a2_borg05S.dsl, a2_borg05R.drl, a2_borg05.bzn.

class 'A2Borg05Mission'

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

function A2Borg05Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
end

function A2Borg05Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b05_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg05Mission:setup( )
    print( "[TheCatch] clean-room a2_borg05 conversion loaded" )
    self.player = Player( 1 )
    self.species = Player( 2 )
    self.hostileReserve = Player( 3 )
    for _, enemy in ipairs( { self.species, self.hostileReserve } ) do
        self.player:setRelation( enemy, Player.Relation.Enemy )
        enemy:setRelation( self.player, Player.Relation.Enemy )
    end
    self.danvers = findLabel( "Danvers" )
    self.tonawanda = findLabel( "Tonawanda" )
    self.nexus = findLabel( "borgbase" )
    Objectives:load( "a2_borg05_main.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg05Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.nexus ) then
        Cineractive:lookFrom( self.nexus )
        Cineractive:setCameraOffset( Vector( -540, 250, -740 ) )
        Cineractive:lookAt( self.nexus )
    end
    UI:addTitle( "THE CATCH", 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 35.0, "finishOpening" )
end

function A2Borg05Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_borg05_intro.wav" ) end
end

function A2Borg05Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg05_main.txt" )
    Objectives.visible = true
    self.species:loadAIP( "a2_borg05_main.aip" )
    self.phase = "gameplay"
    self:schedule( "base_attack_1", 180.0, "attackBase" )
    self:schedule( "tonawanda_attack", 260.0, "attackTonawanda" )
    self:schedule( "danvers_attack", 340.0, "attackDanvers" )
    self:schedule( "base_attack_2", 460.0, "attackBase" )
    print( "[TheCatch] gameplay started" )
end

function A2Borg05Mission:setObjective( index, state )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = state end
    Objectives.visible = true
end

function A2Borg05Mission:sendHostiles( target, limit )
    if not live( target ) then return end
    local sent = 0
    for _, team in ipairs( { 2, 3 } ) do
        for _, ship in pairs( findCraft( team, nil ) ) do
            local odf = odfBase( ship )
            if ship.label ~= "Danvers" and ship.label ~= "Tonawanda"
                and not string.find( odf, "base", 1, true )
                and not string.find( odf, "yard", 1, true )
                and not string.find( odf, "mining", 1, true )
                and not string.find( odf, "mother", 1, true ) then
                pcall( function( ) ship:giveOrder( GameObject.Order.Attack, target ) end )
                sent = sent + 1
                if sent >= limit then return end
            end
        end
    end
end

function A2Borg05Mission:attackBase( ) self:sendHostiles( self.nexus, 5 ) end
function A2Borg05Mission:attackDanvers( ) self:sendHostiles( self.danvers, 3 ) end
function A2Borg05Mission:attackTonawanda( ) self:sendHostiles( self.tonawanda, 3 ) end

function A2Borg05Mission:atNexus( ship )
    return live( ship ) and live( self.nexus )
        and distanceSquared( ship.position, self.nexus.position ) < 500 * 500
end

function A2Borg05Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    for index = 1, 4 do self:setObjective( index, true ) end
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.nexus ) then
        Cineractive:lookFrom( self.nexus )
        Cineractive:setCameraOffset( Vector( -520, 240, -720 ) )
        Cineractive:lookAt( self.nexus )
    end
    UI:addTitle( "PROTOTYPE VESSELS RECOVERED", 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    Media:playSound( "a2_borg05_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Borg05Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg05Mission:startFailure( sound, title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "Mbor5.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg05Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg05Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.danvers = findLabel( "Danvers" ) or self.danvers
    self.tonawanda = findLabel( "Tonawanda" ) or self.tonawanda
    self.nexus = findLabel( "borgbase" ) or self.nexus

    if not live( self.danvers ) then
        self:startFailure( "a2_borg05_fail.wav", "THE USS DANVERS HAS BEEN DESTROYED" )
        return
    end
    if not live( self.tonawanda ) then
        self:startFailure( "a2_borg05_fail.wav", "THE USS TONAWANDA HAS BEEN DESTROYED" )
        return
    end
    if not live( self.nexus ) or self.nexus.player.number ~= 1 then
        self:startFailure( "a2_borg05_fail_2.wav", "NEXUS 4288 HAS BEEN DESTROYED" )
        return
    end

    local recyclerBuilt = #findCraft( 1, "brecycle" ) > 0
    local danversHome = self:atNexus( self.danvers )
    local tonawandaHome = self:atNexus( self.tonawanda )
    self:setObjective( 1, recyclerBuilt )
    self:setObjective( 2, danversHome and tonawandaHome )
    if recyclerBuilt and danversHome and tonawandaHome then self:startSuccess( ) end
end

function A2Borg05Mission:cineractiveUpdate( ) end
function A2Borg05Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg05Mission( ) )
