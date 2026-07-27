-- CLEAN-ROOM STAR TREK: ARMADA II FEDERATION MISSION 8 CONVERSION
-- Behaviour evidence: a2_fed08S.dsl, a2_fed08R.drl, a2_fed08.bzn.

class 'A2Federation08Mission'

local function live( entity ) return entity ~= nil and entity.valid end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function findCraft( odf, team )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.Craft )
            and ( odf == nil or entity.odf == odf )
            and ( team == nil or entity.player.number == team )
            and ( entity.crew == nil or entity.crew > 0 )
    end ):find( )
end

local function nearest( position, entities, range )
    local result = nil
    local best = ( range or 100000 ) * ( range or 100000 )
    for _, entity in pairs( entities ) do
        if live( entity ) then
            local candidate = distanceSquared( position, entity.position )
            if candidate <= best then result, best = entity, candidate end
        end
    end
    return result
end

local function safeOrder( entity, order, target )
    if not live( entity ) then return end
    pcall( function( ) entity:giveOrder( order, target ) end )
end

local FED_BASE_POSITION = Vector( 7188.5024, -144.98257, 1630.2567 )
local NEXUS_POSITION = Vector( 845.698, -37.2887, 18495.799 )
local BORG_ENTRY = Vector( 1300, 0, 17600 )

function A2Federation08Mission:__init( )
    self.phase = "loading"
    self.timerSerial = 0
    self.timers = { }
    self.ending = false
    self.ended = false
    self.temporalBuilt = false
    self.nexusSeen = false
    self.nexusTaken = false
    self.minerWorking = false
    self.dataRetrieved = false
end

function A2Federation08Mission:schedule( name, seconds, method )
    self.timerSerial = self.timerSerial + 1
    local id = "a2f08_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( timerObject, hook )
        if not self.ended then self[ method ]( self ) end
    end, nil )
    self.timers[ id ] = timer
end

function A2Federation08Mission:setup( )
    print( "[DataRetrieval] clean-room a2_fed08 conversion loaded" )
    self.player = Player( 1 )
    self.borg = Player( 2 )
    self.player:setRelation( self.borg, Player.Relation.Enemy )
    self.borg:setRelation( self.player, Player.Relation.Enemy )
    Objectives:load( "a2_fed08_A.txt" )
    Objectives.visible = false
    self:startOpening( )
end

function A2Federation08Mission:startOpening( )
    self.phase = "opening"
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 7900, 350, 2300 ) )
    Cineractive:lookAt( FED_BASE_POSITION )
    UI:addTitle( "DATA RETRIEVAL", 50, 50, 8.0, true )
    Media:playMusic( "Mfed300.wav" )
    self:schedule( "intro_voice", 3.0, "playIntro" )
    self:schedule( "intro_done", 60.0, "finishOpening" )
end

function A2Federation08Mission:playIntro( )
    if self.phase == "opening" then Media:playSound( "a2_fed08_intro.wav" ) end
end

function A2Federation08Mission:finishOpening( )
    if self.phase ~= "opening" then return end
    self.phase = "gameplay"
    Media:stopSounds( )
    Cineractive.active = false
    Objectives:load( "a2_fed08_A.txt" )
    Objectives.visible = true
    self.enterprise = nearest( FED_BASE_POSITION, findCraft( "fente.odf", 1 ) )
    self.dataMiner = nearest( FED_BASE_POSITION, findCraft( "fdata.odf", 1 ) )
    self.base = nearest( FED_BASE_POSITION, findCraft( "fbase.odf", 1 ) )
    self.nexus = nearest( NEXUS_POSITION, findCraft( "bbase.odf", nil ) )
    self.borg:loadAIP( "a2_fed08_start.aip" )
    self:schedule( "borg_one", 40.0, "borgAttackOne" )
    self:schedule( "borg_two", 350.0, "borgAttackTwo" )
    self:schedule( "borg_three", 600.0, "borgAttackThree" )
    print( "[DataRetrieval] gameplay started" )
end

function A2Federation08Mission:complete( index )
    if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    Objectives.visible = true
end

function A2Federation08Mission:spawnAttack( odfs, target )
    target = live( target ) and target or self.base
    for index, odf in ipairs( odfs ) do
        local ship = Entity.add( odf, 2, BORG_ENTRY + Vector( index * 105, 0, ( index % 3 ) * 95 ) )
        if live( target ) then safeOrder( ship, GameObject.Order.Attack, target ) end
    end
end

function A2Federation08Mission:borgAttackOne( )
    if self.phase == "gameplay" then
        self:spawnAttack( { "bdestroy.odf", "bdestroy.odf", "bdestroy.odf", "bcruise3.odf" }, self.base )
    end
end

function A2Federation08Mission:borgAttackTwo( )
    if self.phase == "gameplay" then
        self:spawnAttack( { "bdestroy.odf", "bcruise1.odf", "bcruise1.odf",
            "bcruise2.odf", "bcruise2.odf" }, self.base )
    end
end

function A2Federation08Mission:borgAttackThree( )
    if self.phase == "gameplay" then
        self:spawnAttack( { "bcruise3.odf", "bcruise3.odf", "bcruise3.odf",
            "bcruise2.odf", "bcruise2.odf", "bcruise2.odf", "bdestroy.odf" }, self.base )
    end
end

function A2Federation08Mission:minerArrived( )
    if self.minerWorking or self.dataRetrieved then return end
    self.minerWorking = true
    self:complete( 4 )
    Media:playSound( "a2_fed08_start.wav" )
    self:spawnAttack( { "bdestroy.odf", "bdestroy.odf", "bcruise1.odf", "bcruise1.odf" }, self.dataMiner )
    self:schedule( "miner_report_one", 60.0, "minerReportOne" )
    self:schedule( "miner_report_two", 120.0, "minerReportTwo" )
    self:schedule( "miner_done", 200.0, "minerDone" )
    print( "[DataRetrieval] Data Miner gathering intelligence" )
end

function A2Federation08Mission:minerReportOne( )
    if self.phase ~= "gameplay" or not self.minerWorking then return end
    Media:playMovie( "a2_fed08_working.bik" )
    self:spawnAttack( { "bbattle1.odf", "bcruise1.odf", "bcruise1.odf",
        "bcruise1.odf", "bcruise2.odf", "bcruise2.odf", "bcruise2.odf" }, self.dataMiner )
end

function A2Federation08Mission:minerReportTwo( )
    if self.phase ~= "gameplay" or not self.minerWorking then return end
    Media:playMovie( "a2_fed08_almost_pic_1.bik" )
    self:spawnAttack( { "bcruise2.odf", "bcruise2.odf", "bcruise3.odf", "bcruise3.odf" }, self.dataMiner )
end

function A2Federation08Mission:minerDone( )
    if self.phase ~= "gameplay" or not self.minerWorking or not live( self.dataMiner ) then return end
    self.minerWorking = false
    self.dataRetrieved = true
    self:complete( 5 )
    Media:playMovie( "a2_fed08_retrieved.bik" )
    self:spawnAttack( { "bcruise2.odf", "bcruise2.odf", "bcruise2.odf",
        "bbattle1.odf", "bdestroy.odf", "bbattle2.odf" }, self.dataMiner )
    self.borg:loadAIP( "a2_fed08_end.aip" )
    print( "[DataRetrieval] intelligence retrieved; return to starbase" )
end

function A2Federation08Mission:startSuccess( )
    if self.ending then return end
    self.ending, self.phase = true, "success"
    self:complete( 6 )
    self:complete( 7 )
    self:complete( 8 )
    Cineractive.active = true
    Cineractive.skippable = true
    if live( self.dataMiner ) then
        Cineractive:lookFrom( self.dataMiner )
        Cineractive:setCameraOffset( Vector( -450, 220, -450 ) )
        Cineractive:lookAt( self.dataMiner )
    end
    UI:addTitle( "INTELLIGENCE RECOVERED", 50, 50, 8.0, true )
    Media:playSound( "a2_fed08_success.wav" )
    self:schedule( "success", 10.0, "finishSuccess" )
end

function A2Federation08Mission:finishSuccess( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( true, 0 )
end

function A2Federation08Mission:startFailure( title, sound )
    if self.ending then return end
    self.ending, self.phase = true, "failure"
    Cineractive.active = true
    Cineractive.skippable = false
    UI:addTitle( title, 50, 50, 8.0, true )
    Media:playSound( sound )
    self:schedule( "failure", 8.0, "finishFailure" )
end

function A2Federation08Mission:finishFailure( )
    if self.ended then return end
    self.ended = true
    Cineractive.active = false
    Mission:finish( false, 0 )
end

function A2Federation08Mission:update( )
    if self.phase ~= "gameplay" or self.ending then return end
    if not live( self.enterprise ) then
        self:startFailure( "THE ENTERPRISE HAS BEEN DESTROYED", "a2_fed08_lost_Enterprise.wav" ); return
    end
    if not live( self.dataMiner ) then
        self:startFailure( "THE DATA MINER HAS BEEN DESTROYED", "a2_fed08_lost_DataMiner.wav" ); return
    end
    if not live( self.nexus ) then
        self:startFailure( "THE BORG NEXUS HAS BEEN DESTROYED", "a2_fed08_lost_Nexus.wav" ); return
    end

    if not self.temporalBuilt and #findCraft( "fsuperbl.odf", 1 ) > 0 then
        self.temporalBuilt = true
        self:complete( 1 )
        Media:playSound( "a2_fed08_temporal.wav" )
    end
    if not self.nexusSeen and nearest( NEXUS_POSITION, findCraft( nil, 1 ), 1800 ) ~= nil then
        self.nexusSeen = true
        self:complete( 2 )
        Media:playMovie( "a2_fed08_located.bik" )
    end
    if not self.nexusTaken and self.nexus.player.number == 1 then
        self.nexusTaken = true
        self:complete( 3 )
        Media:playMovie( "a2_fed08_taken.bik" )
    end
    if self.nexusTaken and not self.minerWorking and not self.dataRetrieved
        and distanceSquared( self.dataMiner.position, self.nexus.position ) <= 700 * 700 then
        self:minerArrived( )
    end
    if self.dataRetrieved and live( self.base )
        and distanceSquared( self.dataMiner.position, self.base.position ) <= 850 * 850 then
        self:startSuccess( )
    end
end

function A2Federation08Mission:cineractiveUpdate( ) end

function A2Federation08Mission:cineractiveFinish( forced )
    if forced and self.phase == "opening" then self:finishOpening( ) end
end

MMM.register( A2Federation08Mission( ) )
