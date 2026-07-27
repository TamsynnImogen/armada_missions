-- CLEAN-ROOM STAR TREK: ARMADA II SPECIES 8472 TUTORIAL CONVERSION
-- Behaviour evidence: a2_tutorial6s.dsl, a2_tutorial6r.drl, a2_tutorial6.bzn.

class 'A28472TutorialMission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
end

local function findLabel( label )
    return EntityFinder( function( entity )
        return entity:isType( Entity.Type.GameObject ) and
            ( entity.label == label or entity.name == label )
    end ):findOne( )
end

local STEPS = {
    { "a2_tutorial6_text_mother.txt", "a2_tutorial6_mother.wav", { { "8472_mother.odf", 1 } } },
    { "a2_tutorial6_text_active.txt", "a2_tutorial6_active.wav", { { "8472_active.odf", 1 } } },
    { "a2_tutorial6_text_scout.txt", "a2_tutorial6_scout.wav", { { "8472_scout.odf", 1 }, { "kdestroy.odf", 2 }, { "kcruise2.odf", 2 } } },
    { "a2_tutorial6_text_destroyer.txt", "a2_tutorial6_destroyer.wav", { { "8472_destroy.odf", 1 } } },
    { "a2_tutorial6_text_cruiser.txt", "a2_tutorial6_cruiser.wav", { { "8472_cruise1.odf", 1 } } },
    { "a2_tutorial6_text_launcher.txt", "a2_tutorial6_launcher.wav", { { "8472_cruise2.odf", 1 }, { "kyard.odf", 2 } } },
    { "a2_tutorial6_text_collector.txt", "a2_tutorial6_collector.wav", { { "8472_collector.odf", 1 }, { "ksensor.odf", 2 } } },
    { "a2_tutorial6_text_passive.txt", "a2_tutorial6_passive.wav", { { "8472_passive.odf", 1 }, { "kdestroy.odf", 2 } } },
    { "a2_tutorial6_text_transmute.txt", "a2_tutorial6_transmute.wav", { { "8472_transmuter.odf", 1 }, { "8472_collector.odf", 1 } } },
    { "a2_tutorial6_text_enhancer.txt", "a2_tutorial6_enhancer.wav", { { "8472_BasicResearch.odf", 1 } } },
    { "a2_tutorial6_text_biocore.txt", "a2_tutorial6_biocore.wav", { { "8472_AdvancedResearch.odf", 1 } } },
    { "a2_tutorial6_text_shipresearch.txt", "a2_tutorial6_metocore.wav", { { "8472_ShipUpgradeResearch.odf", 1 } } },
    { "a2_tutorial6_text_gate.txt", "a2_tutorial6_gate.wav", { { "8472_FluidicGate.odf", 1 } } },
    { "a2_tutorial6_text_defender.txt", "a2_tutorial6_defender.wav", { { "8472_defender.odf", 1 }, { "8472_FluidicGate.odf", 1 } } },
    { "a2_tutorial6_text_battle.txt", "a2_tutorial6_battle.wav", { { "8472_battle.odf", 1 }, { "8472_FluidicGate.odf", 1 } } },
    { "a2_tutorial6_text_frigate.txt", "a2_tutorial6_frig.wav", { { "8472_frigate.odf", 1 }, { "kyard.odf", 2 } } },
    { "a2_tutorial6_text_behemoth.txt", "a2_tutorial6_behemoth.wav", { { "8472_behemoth.odf", 1 }, { "mnebula8.odf", 0 }, { "mnebula8.odf", 0 } } },
    { "a2_tutorial6_text_end.txt", "a2_tutorial6_wrap.wav" }
}

function A28472TutorialMission:__init( )
    self.step = 0
    self.spawned = { }
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.opening = true
    self.finished = false
end

function A28472TutorialMission:clearShowcase( )
    for _, entity in ipairs( self.spawned ) do
        if live( entity ) then Entity.remove( entity ) end
    end
    self.spawned = { }
end

function A28472TutorialMission:replaceShowcase( definitions )
    if definitions == nil then
        for _, entity in ipairs( self.spawned ) do if live( entity ) then return entity end end
        return findLabel( "main_mother" )
    end
    self:clearShowcase( )
    local focus = nil
    for index, definition in ipairs( definitions ) do
        local column = ( index - 1 ) % 4
        local row = math.floor( ( index - 1 ) / 4 )
        local ok, entity = pcall( function( )
            return Entity.add( definition[ 1 ], definition[ 2 ], Vector( 4450 + column * 210, 0, 4450 + row * 220 ) )
        end )
        if ok and live( entity ) then
            self.spawned[ #self.spawned + 1 ] = entity
            if focus == nil then focus = entity end
        end
    end
    return focus
end

function A28472TutorialMission:showStep( )
    self.step = self.step + 1
    local item = STEPS[ self.step ]
    if item == nil then self:finishTutorial( ); return end
    local focus = self:replaceShowcase( item[ 3 ] )
    if live( focus ) then Camera:center( focus ) end
    Objectives:load( item[ 1 ] )
    Objectives.visible = true
    Media:playSound( item[ 2 ] )
    self.awaitingAdvance = true
    UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
end

function A28472TutorialMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self:showStep( )
end

function A28472TutorialMission:onAdvance( text, hook ) self:advanceTutorial( ) end

function A28472TutorialMission:finishOpening( )
    if not self.opening then return end
    self.opening = false
    Media:stopSounds( )
    Cineractive.active = false
    self:showStep( )
end

function A28472TutorialMission:finishTutorial( )
    if self.finished then return end
    self.finished = true
    self.awaitingAdvance = false
    self:clearShowcase( )
    Game.allowSave = true
    local timer = Timer( "a2_tutorial6_finish", 3.0, Timer.State.Started )
    timer:hook( "a2_tutorial6_finish_hook", nil, function( timerObject, hook ) Mission:finish( true, 0 ) end, nil )
    self.finishTimer = timer
end

function A28472TutorialMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then self:advanceTutorial( ) end
    self.enterWasDown = enterDown
end

function A28472TutorialMission:cineractiveFinish( forced )
    if self.opening then self:finishOpening( ) end
end

function A28472TutorialMission:setup( )
    print( "[8472Tutorial] clean-room a2_tutorial6 conversion loaded" )
    Game.allowSave = false
    Player( 1 ):setRelation( Player( 2 ), Player.Relation.Enemy )
    Player( 2 ):setRelation( Player( 1 ), Player.Relation.Enemy )
    TextInput:hook( "a2_tutorial6.next", self, A28472TutorialMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 4100, 500, 4100 ) )
    local mother = findLabel( "main_mother" )
    if live( mother ) then Cineractive:lookAt( mother ) else Cineractive:lookAt( Vector( 4600, 0, 4600 ) ) end
    UI:addTitle( "SPECIES 8472 TUTORIAL", 100, 200, 7.0, true )
    Media:playSound( "a2_tutorial6_intro.wav" )
    local timer = Timer( "a2_tutorial6_opening", 12.0, Timer.State.Started )
    timer:hook( "a2_tutorial6_opening_hook", nil, function( timerObject, hook ) self:finishOpening( ) end, nil )
    self.openingTimer = timer
end

MMM.register( A28472TutorialMission( ) )
