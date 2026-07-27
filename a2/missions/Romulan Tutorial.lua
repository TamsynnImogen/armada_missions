-- CLEAN-ROOM STAR TREK: ARMADA II ROMULAN TUTORIAL CONVERSION
-- Behaviour evidence: a2_tutorial4s.dsl, a2_tutorial4r.drl, a2_tutorial4.bzn.

class 'A2RomulanTutorialMission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
end

local STEPS = {
    { "a2_tutorial4_enter.txt", "a2_tutorial4_noncom.wav", { "rbase.odf", "rfreight.odf", "rconst.odf", "rcargo.odf", "rsrepair.odf", "rcolony.odf" } },
    { "a2_tutorial4_colony.txt", "a2_tutorial4_colony.wav" },
    { "a2_tutorial4_repair.txt", "a2_tutorial4_repair.wav" },
    { "a2_tutorial4_Kestral.txt", "a2_tutorial4_Kestral.wav", { "ryard.odf", "rscout.odf", "rdestroy.odf", "rcruise2.odf", "rcruise1.odf", "rcruise3.odf", "rassault.odf" } },
    { nil, "a2_tutorial4_Com1.wav" }, { nil, "a2_tutorial4_Com2.wav" },
    { nil, "a2_tutorial4_Com4.wav" }, { nil, "a2_tutorial4_Com6.wav" },
    { nil, "a2_tutorial4_Com7.wav" }, { nil, "a2_tutorial4_Com8.wav" },
    { nil, "a2_tutorial4_Com3.wav" },
    { "a2_tutorial4_enter.txt", "a2_tutorial4_yard2.wav", { "ryard2.odf", "rbattle.odf", "rbattle2.odf", "rfrigate.odf", "rspecial.odf" } },
    { nil, "a2_tutorial4_Com11.wav" }, { nil, "a2_tutorial4_Com10.wav" },
    { nil, "a2_tutorial4_Com5.wav" }, { nil, "a2_tutorial4_Com9.wav" },
    { "a2_tutorial4_enter.txt", "a2_tutorial4_phoen.wav", { "rsuperbl.odf", "rsuper.odf" } },
    { nil, "a2_tutorial4_Com12.wav" },
    { "a2_tutorial4_enter.txt", "a2_tutorial4_stanstations.wav", { "rbase.odf", "rmining.odf", "rturret.odf", "rsensor.odf", "rtrading.odf", "rturret2.odf", "rresear.odf", "rresear2.odf", "rupgrade.odf" } },
    { nil, "a2_tutorial4_station1.wav" }, { nil, "a2_tutorial4_station2.wav" },
    { nil, "a2_tutorial4_station3.wav" },
    { "a2_tutorial4_combat.txt", "a2_tutorial4_combat.wav", { "rbattle.odf", "rcruise1.odf", "rcruise2.odf", "rdestroy.odf" } },
    { "a2_tutorial4_text_end.txt", "a2_tutorial4_wrap.wav" }
}

function A2RomulanTutorialMission:__init( )
    self.step = 0
    self.spawned = { }
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.opening = true
    self.finished = false
end

function A2RomulanTutorialMission:clearShowcase( )
    for _, entity in ipairs( self.spawned ) do
        if live( entity ) then Entity.remove( entity ) end
    end
    self.spawned = { }
end

function A2RomulanTutorialMission:replaceShowcase( odfs )
    if odfs == nil then
        for _, entity in ipairs( self.spawned ) do if live( entity ) then return entity end end
        return nil
    end
    self:clearShowcase( )
    local focus = nil
    for index, odf in ipairs( odfs ) do
        local column = ( index - 1 ) % 4
        local row = math.floor( ( index - 1 ) / 4 )
        local ok, entity = pcall( function( )
            return Entity.add( odf, 4, Vector( 4450 + column * 190, 0, 4450 + row * 200 ) )
        end )
        if ok and live( entity ) then
            self.spawned[ #self.spawned + 1 ] = entity
            if focus == nil then focus = entity end
        end
    end
    return focus
end

function A2RomulanTutorialMission:showStep( )
    self.step = self.step + 1
    local item = STEPS[ self.step ]
    if item == nil then self:finishTutorial( ); return end
    local focus = self:replaceShowcase( item[ 3 ] )
    if live( focus ) then Camera:center( focus ) end
    if item[ 1 ] ~= nil then Objectives:load( item[ 1 ] ) end
    Objectives.visible = true
    Media:playSound( item[ 2 ] )
    self.awaitingAdvance = true
    UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
end

function A2RomulanTutorialMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self:showStep( )
end

function A2RomulanTutorialMission:onAdvance( text, hook ) self:advanceTutorial( ) end

function A2RomulanTutorialMission:finishOpening( )
    if not self.opening then return end
    self.opening = false
    Media:stopSounds( )
    Cineractive.active = false
    self:showStep( )
end

function A2RomulanTutorialMission:finishTutorial( )
    if self.finished then return end
    self.finished = true
    self.awaitingAdvance = false
    self:clearShowcase( )
    Game.allowSave = true
    local timer = Timer( "a2_tutorial4_finish", 3.0, Timer.State.Started )
    timer:hook( "a2_tutorial4_finish_hook", nil, function( timerObject, hook ) Mission:finish( true, 0 ) end, nil )
    self.finishTimer = timer
end

function A2RomulanTutorialMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then self:advanceTutorial( ) end
    self.enterWasDown = enterDown
end

function A2RomulanTutorialMission:cineractiveFinish( forced )
    if self.opening then self:finishOpening( ) end
end

function A2RomulanTutorialMission:setup( )
    print( "[RomulanTutorial] clean-room a2_tutorial4 conversion loaded" )
    Game.allowSave = false
    Player( 1 ):setRelation( Player( 4 ), Player.Relation.Ally )
    Player( 4 ):setRelation( Player( 1 ), Player.Relation.Ally )
    TextInput:hook( "a2_tutorial4.next", self, A2RomulanTutorialMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 4100, 500, 4100 ) )
    Cineractive:lookAt( Vector( 4600, 0, 4600 ) )
    UI:addTitle( "ROMULAN TUTORIAL", 100, 200, 7.0, true )
    Media:playMusic( "mrom15a.wav" )
    Media:playSound( "a2_tutorial4_intro.wav" )
    local timer = Timer( "a2_tutorial4_opening", 12.0, Timer.State.Started )
    timer:hook( "a2_tutorial4_opening_hook", nil, function( timerObject, hook ) self:finishOpening( ) end, nil )
    self.openingTimer = timer
end

MMM.register( A2RomulanTutorialMission( ) )
