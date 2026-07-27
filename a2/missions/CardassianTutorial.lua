-- CLEAN-ROOM STAR TREK: ARMADA II CARDASSIAN TUTORIAL CONVERSION
-- Behaviour evidence: a2_tutorial5s.dsl, a2_tutorial5r.drl, a2_tutorial5.bzn.

class 'A2CardassianTutorialMission'

local function live( entity )
    return entity ~= nil and type( entity ) ~= "boolean" and entity.valid
end

local STEPS = {
    { "a2_tutorial5_construction.txt", "a2_tutorial5_construction.wav", { { "cconst.odf", 1 } } },
    { "a2_tutorial5_shipyard.txt", "a2_tutorial5_shipyard.wav", { { "cyard.odf", 1 } } },
    { "a2_tutorial5_hideki.txt", "a2_tutorial5_hideki.wav", { { "cscout.odf", 1 }, { "rdestroy.odf", 2 }, { "rdestroy.odf", 2 } } },
    { "a2_tutorial5_janissary.txt", "a2_tutorial5_Janissary.wav", { { "cassault.odf", 1 }, { "rfreight.odf", 2 } } },
    { "a2_tutorial5_gul_vystan.txt", "a2_tutorial5_gul_vystan.wav", { { "ccruise2.odf", 1 } } },
    { "a2_tutorial5_legate.txt", "a2_tutorial5_Legate.wav", { { "csensor.odf", 1 }, { "ccruise3.odf", 1 }, { "ccruise3.odf", 1 }, { "rturret.odf", 2 } } },
    { "a2_tutorial5_brinok.txt", "a2_tutorial5_Brinok.wav", { { "ccruise1.odf", 1 }, { "rmining.odf", 2 } } },
    { "a2_tutorial5_rasilak.txt", "a2_tutorial5_rasilak.wav", { { "cdestroy.odf", 1 }, { "rdestroy.odf", 2 } } },
    { "a2_tutorial5_yard2.txt", "a2_tutorial5_yard2.wav", { { "cyard2.odf", 1 } } },
    { "a2_tutorial5_vasad.txt", "a2_tutorial5_Vasad.wav", { { "cfrigate.odf", 1 }, { "cfreight.odf", 1 }, { "cturret2.odf", 1 }, { "rdestroy.odf", 2 } } },
    { "a2_tutorial5_kulinor.txt", "a2_tutorial5_kulinor.wav", { { "cspecial.odf", 1 }, { "pb_clssm.odf", 0 } } },
    { "a2_tutorial5_kulinor2.txt", "a2_tutorial5_kulinor2.wav", { { "cspecial.odf", 1 }, { "csensor.odf", 1 }, { "rmining.odf", 2 } } },
    { "a2_tutorial5_kulinor3.txt", "a2_tutorial5_kulinor3.wav", { { "cspecial.odf", 1 }, { "rdestroy.odf", 2 }, { "rdestroy.odf", 2 } } },
    { "a2_tutorial5_keldon.txt", "a2_tutorial5_keldon.wav", { { "cbattle2.odf", 1 } } },
    { "a2_tutorial5_robotics.txt", "a2_tutorial5_robotics.wav", { { "cardassian_super_station.odf", 1 } } },
    { "a2_tutorial5_super.txt", "a2_tutorial5_super.wav", { { "csuper.odf", 1 }, { "rbase.odf", 2 } } },
    { nil, "a2_tutorial5_research1.wav", { { "cresear.odf", 1 }, { "cresear2.odf", 1 }, { "cupgrade.odf", 1 } } },
    { nil, "a2_tutorial5_research2.wav" },
    { nil, "a2_tutorial5_research3.wav" },
    { "a2_tutorial5_wrap.txt", "a2_tutorial5_wrap.wav" }
}

function A2CardassianTutorialMission:__init( )
    self.step = 0
    self.spawned = { }
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.opening = true
    self.finished = false
end

function A2CardassianTutorialMission:clearShowcase( )
    for _, entity in ipairs( self.spawned ) do
        if live( entity ) then Entity.remove( entity ) end
    end
    self.spawned = { }
end

function A2CardassianTutorialMission:replaceShowcase( definitions )
    if definitions == nil then
        for _, entity in ipairs( self.spawned ) do if live( entity ) then return entity end end
        return nil
    end
    self:clearShowcase( )
    local focus = nil
    for index, definition in ipairs( definitions ) do
        local column = ( index - 1 ) % 4
        local row = math.floor( ( index - 1 ) / 4 )
        local ok, entity = pcall( function( )
            return Entity.add( definition[ 1 ], definition[ 2 ], Vector( 4450 + column * 190, 0, 4450 + row * 200 ) )
        end )
        if ok and live( entity ) then
            self.spawned[ #self.spawned + 1 ] = entity
            if focus == nil then focus = entity end
        end
    end
    return focus
end

function A2CardassianTutorialMission:showStep( )
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

function A2CardassianTutorialMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self:showStep( )
end

function A2CardassianTutorialMission:onAdvance( text, hook ) self:advanceTutorial( ) end

function A2CardassianTutorialMission:finishOpening( )
    if not self.opening then return end
    self.opening = false
    Media:stopSounds( )
    Cineractive.active = false
    self:showStep( )
end

function A2CardassianTutorialMission:finishTutorial( )
    if self.finished then return end
    self.finished = true
    self.awaitingAdvance = false
    self:clearShowcase( )
    Game.allowSave = true
    local timer = Timer( "a2_tutorial5_finish", 3.0, Timer.State.Started )
    timer:hook( "a2_tutorial5_finish_hook", nil, function( timerObject, hook ) Mission:finish( true, 0 ) end, nil )
    self.finishTimer = timer
end

function A2CardassianTutorialMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then self:advanceTutorial( ) end
    self.enterWasDown = enterDown
end

function A2CardassianTutorialMission:cineractiveFinish( forced )
    if self.opening then self:finishOpening( ) end
end

function A2CardassianTutorialMission:setup( )
    print( "[CardassianTutorial] clean-room a2_tutorial5 conversion loaded" )
    Game.allowSave = false
    Player( 1 ):setRelation( Player( 2 ), Player.Relation.Enemy )
    Player( 2 ):setRelation( Player( 1 ), Player.Relation.Enemy )
    TextInput:hook( "a2_tutorial5.next", self, A2CardassianTutorialMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    Cineractive:lookFrom( Vector( 4100, 500, 4100 ) )
    Cineractive:lookAt( Vector( 4600, 0, 4600 ) )
    UI:addTitle( "CARDASSIAN TUTORIAL", 100, 200, 7.0, true )
    Media:playSound( "a2_tutorial5_intro.wav" )
    local timer = Timer( "a2_tutorial5_opening", 12.0, Timer.State.Started )
    timer:hook( "a2_tutorial5_opening_hook", nil, function( timerObject, hook ) self:finishOpening( ) end, nil )
    self.openingTimer = timer
end

MMM.register( A2CardassianTutorialMission( ) )
