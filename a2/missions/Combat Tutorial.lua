-- CLEAN-ROOM STAR TREK: ARMADA II COMBAT TUTORIAL CONVERSION
-- Behaviour evidence: a2_tutorial3s.dsl, a2_tutorial3r.drl, a2_tutorial3.bzn.

class 'A2CombatTutorialMission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
end

local STEPS = {
    { "a2_tutorial3_step_01.txt", "a2_tutorial3_display.wav", { { "fdestroy.odf", 1 } } },
    { "a2_tutorial3_step_02.txt", "a2_tutorial3_damaged.wav", { { "fdestroy.odf", 1 }, { "cdestroy.odf", 2 } } },
    { "a2_tutorial3_step_17.txt", "a2_tutorial3_repair.wav", { { "fsrepair.odf", 1 }, { "fdestroy.odf", 1 } } },
    { "a2_tutorial3_step_18.txt", "a2_tutorial3_frigate.wav", { { "ffrigate.odf", 1 } } },
    { "a2_tutorial3_step_03.txt", "a2_tutorial3_AI.wav", { { "fdestroy.odf", 1 } } },
    { "a2_tutorial3_step_04.txt", "a2_tutorial3_AI2.wav", { { "fdestroy.odf", 1 }, { "cscout.odf", 2 } } },
    { "a2_tutorial3_step_05.txt", "a2_tutorial3_AI3.wav", { { "fdestroy.odf", 1 }, { "cscout.odf", 2 }, { "cconst.odf", 2 } } },
    { "a2_tutorial3_step_06.txt", "a2_tutorial3_shoot.wav", { { "fcruise1.odf", 1 }, { "cconst.odf", 2 }, { "cscout.odf", 2 } } },
    { "a2_tutorial3_step_07.txt", "a2_tutorial3_speweap.wav", { { "cscout.odf", 2 }, { "cdestroy.odf", 2 }, { "cscout.odf", 2 } } },
    { "a2_tutorial3_step_08.txt", "a2_tutorial3_group.wav", { { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 }, { "fdestroy.odf", 1 } } },
    { "a2_tutorial3_step_09.txt", "a2_tutorial3_fltmanagement.wav", { { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 }, { "ffrigate.odf", 1 } } },
    { "a2_tutorial3_step_10.txt", "a2_tutorial3_fltbuilding.wav", { { "fbattle.odf", 1 }, { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 } } },
    { "a2_tutorial3_step_11.txt", "a2_tutorial3_formations.wav", { { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 }, { "fdestroy.odf", 1 } } },
    { "a2_tutorial3_step_12.txt", "a2_tutorial3_fleet.wav", { { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 }, { "fassault.odf", 1 } } },
    { "a2_tutorial3_step_13.txt", "a2_tutorial3_fltspeweap.wav", { { "rcruise1.odf", 4 }, { "rdestroy.odf", 4 }, { "rbattle.odf", 4 }, { "rcolony.odf", 4 } } },
    { "a2_tutorial3_step_14.txt", "a2_tutorial3_planets.wav", { { "fassault.odf", 1 }, { "fassault.odf", 1 }, { "pb_clssm.odf", 0 } } },
    { "a2_tutorial3_step_15.txt", "a2_tutorial3_hazards.wav", { { "fscout.odf", 1 }, { "mnebula8.odf", 0 } } },
    { "a2_tutorial3_step_16.txt", "a2_tutorial3_wrap.wav", { { "fbattle.odf", 1 }, { "fcruise1.odf", 1 }, { "fcruise2.odf", 1 } } }
}

function A2CombatTutorialMission:__init( )
    self.step = 0
    self.spawned = { }
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.opening = true
    self.finished = false
end

function A2CombatTutorialMission:clearShowcase( )
    for _, entity in ipairs( self.spawned ) do
        if live( entity ) then Entity.remove( entity ) end
    end
    self.spawned = { }
end

function A2CombatTutorialMission:spawnShowcase( definitions )
    local focus = nil
    for index, definition in ipairs( definitions or { } ) do
        local column = ( index - 1 ) % 4
        local row = math.floor( ( index - 1 ) / 4 )
        local position = Vector( 4450 + column * 180, 0, 4450 + row * 190 )
        local ok, entity = pcall( function( )
            return Entity.add( definition[ 1 ], definition[ 2 ], position )
        end )
        if ok and live( entity ) then
            self.spawned[ #self.spawned + 1 ] = entity
            if focus == nil then focus = entity end
        end
    end
    return focus
end

function A2CombatTutorialMission:showStep( )
    self:clearShowcase( )
    self.step = self.step + 1
    local item = STEPS[ self.step ]
    if item == nil then self:finishTutorial( ); return end
    local focus = self:spawnShowcase( item[ 3 ] )
    if live( focus ) then Camera:center( focus ) end
    Objectives:load( item[ 1 ] )
    Objectives.visible = true
    Media:playSound( item[ 2 ] )
    self.awaitingAdvance = true
    UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
end

function A2CombatTutorialMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self:showStep( )
end

function A2CombatTutorialMission:onAdvance( text, hook ) self:advanceTutorial( ) end

function A2CombatTutorialMission:finishOpening( )
    if not self.opening then return end
    self.opening = false
    Media:stopSounds( )
    Cineractive.active = false
    self:showStep( )
end

function A2CombatTutorialMission:finishTutorial( )
    if self.finished then return end
    self.finished = true
    self.awaitingAdvance = false
    self:clearShowcase( )
    Game.allowSave = true
    UI:addSubtitle( "Combat tutorial complete", 50, 1050, 3.0, false )
    local timer = Timer( "a2_tutorial3_finish", 3.0, Timer.State.Started )
    timer:hook( "a2_tutorial3_finish_hook", nil, function( timerObject, hook )
        Mission:finish( true, 0 )
    end, nil )
    self.finishTimer = timer
end

function A2CombatTutorialMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then self:advanceTutorial( ) end
    self.enterWasDown = enterDown
end

function A2CombatTutorialMission:cineractiveFinish( forced )
    if self.opening then self:finishOpening( ) end
end

function A2CombatTutorialMission:setup( )
    print( "[CombatTutorial] clean-room a2_tutorial3 conversion loaded" )
    Game.allowSave = false
    Player( 1 ):setRelation( Player( 2 ), Player.Relation.Enemy )
    Player( 2 ):setRelation( Player( 1 ), Player.Relation.Enemy )
    TextInput:hook( "a2_tutorial3.next", self, A2CombatTutorialMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 4100, 500, 4100 ) )
    Cineractive:lookAt( Vector( 4600, 0, 4600 ) )
    UI:addTitle( "COMBAT TUTORIAL", 100, 200, 7.0, true )
    Media:playMusic( "Mfed30.wav" )
    Media:playSound( "a2_tutorial3_intro.wav" )
    local timer = Timer( "a2_tutorial3_opening", 12.0, Timer.State.Started )
    timer:hook( "a2_tutorial3_opening_hook", nil, function( timerObject, hook ) self:finishOpening( ) end, nil )
    self.openingTimer = timer
end

MMM.register( A2CombatTutorialMission( ) )
