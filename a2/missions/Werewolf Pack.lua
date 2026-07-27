-- CLEAN-ROOM STAR TREK: ARMADA II BORG MISSION 1 CONVERSION
-- Behaviour evidence: a2_borg01S.dsl, a2_borg01R.drl, a2_borg01.bzn.

class 'A2Borg01Mission'

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

local function firstLive( labels )
    for _, label in ipairs( labels ) do
        local entity = findLabel( label )
        if live( entity ) then return entity end
    end
end

local CRITICAL_STATION_LABELS = { "bresear1455", "RECYCLER", "byard1877" }

function A2Borg01Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.offensiveStage = false
    self.researchComplete = false
    self.dilithiumComplete = false
    self.metalComplete = false
end

function A2Borg01Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2b01_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Borg01Mission:setup( )
    print( "[WerewolfPack] clean-room a2_borg01 conversion loaded" )
    self.player = Player( 1 )
    self.federationA = Player( 2 )
    self.federationB = Player( 3 )
    self.klingon = Player( 4 )
    self.species = Player( 5 )
    for _, enemy in ipairs( { self.federationA, self.federationB, self.klingon, self.species } ) do
        self.player:setRelation( enemy, Player.Relation.Enemy )
        enemy:setRelation( self.player, Player.Relation.Enemy )
    end
    self.queen = firstLive( { "Borg_Queen_s_Diamond", "bqueen", "Queen" } )
        or findCraft( 1, "bqueen" )[ 1 ]
    self.criticalStations = { }
    for _, label in ipairs( CRITICAL_STATION_LABELS ) do
        local station = findLabel( label )
        if live( station ) then self.criticalStations[ #self.criticalStations + 1 ] = station end
    end
    Objectives:load( "a2_borg01_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Borg01Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    if live( self.queen ) then
        Cineractive:lookFrom( self.queen )
        Cineractive:setCameraOffset( Vector( -480, 220, -680 ) )
        Cineractive:lookAt( self.queen )
    end
    Media:playMusic( "mbor300.wav" )
    UI:addTitle( "WEREWOLF PACK", 50, 50, 8.0, true )
    self:schedule( "intro", 5.0, "playIntro" )
    self:schedule( "opening_done", 38.0, "finishOpening" )
end

function A2Borg01Mission:playIntro( )
    if self.phase == "opening" then
        Media:playSound( "a2_borg01_queens_lament_intro.wav" )
    end
end

function A2Borg01Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_borg01_A.txt" )
    Objectives.visible = true
    self.federationA:loadAIP( "a2_borg01_fed2basic.aip" )
    self.federationB:loadAIP( "a2_borg01_fed3basic.aip" )
    self.klingon:loadAIP( "a2_borg01_kling4basic.aip" )
    self.phase = "gameplay"
    self:schedule( "patrol_two", 240.0, "releasePatrols" )
    self:schedule( "patrol_three", 480.0, "releasePatrols" )
    print( "[WerewolfPack] gameplay started" )
end

function A2Borg01Mission:setObjective( index, complete )
    if Objectives.objectives[ index ] ~= nil then
        Objectives.objectives[ index ].state = complete
    end
    Objectives.visible = true
end

function A2Borg01Mission:releasePatrols( )
    if self.phase ~= "gameplay" then return end
    for _, team in ipairs( { 2, 3, 4 } ) do
        local sent = 0
        for _, ship in pairs( findCraft( team, nil ) ) do
            local odf = odfBase( ship )
            if not string.find( odf, "base", 1, true )
                and not string.find( odf, "yard", 1, true )
                and not string.find( odf, "mining", 1, true ) then
                pcall( function( ) ship:giveOrder( GameObject.Order.SearchAndDestroy ) end )
                sent = sent + 1
                if sent >= 3 then break end
            end
        end
    end
end

function A2Borg01Mission:enemyCount( )
    local count = 0
    for _, team in ipairs( { 2, 3, 4 } ) do
        for _, entity in pairs( findCraft( team, nil ) ) do
            if live( entity ) then count = count + 1 end
        end
    end
    return count
end

function A2Borg01Mission:criticalStationLost( )
    for _, station in ipairs( self.criticalStations ) do
        if not live( station ) or station.player.number ~= 1 then return true end
    end
    return false
end

function A2Borg01Mission:beginOffensiveStage( )
    if self.offensiveStage then return end
    self.offensiveStage = true
    Objectives:load( "a2_borg01_b.txt" )
    Objectives.visible = true
    self.federationA:loadAIP( "a2_aggressive.aip" )
    self.federationB:loadAIP( "a2_aggressive.aip" )
    self.klingon:loadAIP( "a2_aggressive.aip" )
    Media:playSound( "a2_borg01_queen_8472.wav" )
    self:schedule( "offensive_patrol", 20.0, "releasePatrols" )
    print( "[WerewolfPack] resource objective complete; offensive stage started" )
end

function A2Borg01Mission:startSuccess( )
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
    Media:playMusic( "mbor10.wav" )
    Media:playMovie( "a2_borg01_victory.bik" )
    self:schedule( "success", 12.0, "finishSuccess" )
end

function A2Borg01Mission:finishSuccess( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Borg01Mission:startFailure( sound, title )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playMusic( "mbor10.wav" )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Borg01Mission:finishFailure( )
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Borg01Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    self.queen = findCraft( 1, "bqueen" )[ 1 ] or self.queen
    if not live( self.queen ) or self.queen.player.number ~= 1 then
        self:startFailure( "a2_borg08_queen_killed.wav", "THE BORG QUEEN HAS BEEN LOST" )
        return
    end
    if self:criticalStationLost( ) then
        self:startFailure( "a2_borg01_queen_station_lost.wav", "A BORG STATION HAS BEEN DESTROYED" )
        return
    end

    self.researchComplete = #findCraft( 1, "borpod1" ) > 0
    self.dilithiumComplete = self.player.resources.dilithium >= 3000
    self.metalComplete = self.player.resources.metal >= 3000

    if not self.offensiveStage then
        self:setObjective( 1, self.researchComplete )
        self:setObjective( 2, self.dilithiumComplete )
        self:setObjective( 3, self.metalComplete )
        if self.dilithiumComplete and self.metalComplete then self:beginOffensiveStage( ) end
    elseif self:enemyCount( ) == 0 then
        self:startSuccess( )
    end
end

function A2Borg01Mission:cineractiveUpdate( ) end
function A2Borg01Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Borg01Mission( ) )
