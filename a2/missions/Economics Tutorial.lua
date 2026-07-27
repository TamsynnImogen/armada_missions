-- CLEAN-ROOM STAR TREK: ARMADA II ECONOMICS TUTORIAL CONVERSION
-- Behaviour evidence: a2_tutorial2s.dsl, a2_tutorial2r.drl, a2_tutorial2.bzn.

class 'A2EconomicsTutorialMission'

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
    { "a2_tutorial2_text_minstation.txt", "a2_tutorial2_start.wav", "fconst1018" },
    { "a2_tutorial2_text_latneb.txt", "a2_tutorial2_mine.wav", "mdmoon1012" },
    { "a2_tutorial2_text_metal.txt", "a2_tutorial2_orbital.wav", "mdmoon1013" },
    { "a2_tutorial2_text_colonyship.txt", "a2_tutorial2_planet.wav", "fyard1042" },
    { "a2_tutorial2_text_colonize.txt", "a2_tutorial2_colon.wav", "pb_clssm1017" },
    { "a2_tutorial2_text_trastation.txt", "a2_tutorial2_trade.wav", "ftrading1022" },
    { "a2_tutorial2_text_buymetal.txt", "a2_tutorial2_trade2.wav", "ftrading1022" },
    { "a2_tutorial2_text_trading.txt", "a2_tutorial2_trade3.wav", "ktrading1028" },
    { "a2_tutorial2_text_crew.txt", "a2_tutorial2_trade4.wav", "fbase1034" }
}

function A2EconomicsTutorialMission:__init( )
    self.step = 0
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.opening = true
    self.finished = false
end

function A2EconomicsTutorialMission:showStep( )
    self.step = self.step + 1
    local item = STEPS[ self.step ]
    if item == nil then
        self:finishTutorial( )
        return
    end

    Objectives:load( item[ 1 ] )
    Objectives.visible = true
    Media:playSound( item[ 2 ] )
    local focus = findLabel( item[ 3 ] )
    if live( focus ) then Camera:center( focus ) end
    self.awaitingAdvance = true
    UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
end

function A2EconomicsTutorialMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self:showStep( )
end

function A2EconomicsTutorialMission:onAdvance( text, hook )
    self:advanceTutorial( )
end

function A2EconomicsTutorialMission:finishOpening( )
    if not self.opening then return end
    self.opening = false
    Media:stopSounds( )
    Cineractive.active = false
    self:showStep( )
end

function A2EconomicsTutorialMission:finishTutorial( )
    if self.finished then return end
    self.finished = true
    self.awaitingAdvance = false
    Game.allowSave = true
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 1.0 )
    local base = findLabel( "fbase1034" )
    if live( base ) then Cineractive:lookAt( base ) end
    Media:playMusic( "Mfed30.wav" )
    Media:playSound( "a2_tutorial2_wrapup.wav" )
    UI:addSubtitle( "Economics tutorial complete", 50, 1050, 4.0, false )
    local timer = Timer( "a2_tutorial2_finish", 8.0, Timer.State.Started )
    timer:hook( "a2_tutorial2_finish_hook", nil, function( timerObject, hook )
        Cineractive.active = false
        Mission:finish( true, 0 )
    end, nil )
    self.finishTimer = timer
end

function A2EconomicsTutorialMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then self:advanceTutorial( ) end
    self.enterWasDown = enterDown
end

function A2EconomicsTutorialMission:cineractiveFinish( forced )
    if self.opening then self:finishOpening( ) end
end

function A2EconomicsTutorialMission:setup( )
    print( "[EconomicsTutorial] clean-room a2_tutorial2 conversion loaded" )
    Game.allowSave = false
    Player( 1 ):setRelation( Player( 2 ), Player.Relation.Ally )
    Player( 2 ):setRelation( Player( 1 ), Player.Relation.Ally )
    TextInput:hook( "a2_tutorial2.next", self, A2EconomicsTutorialMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    Cineractive.active = true
    Cineractive.skippable = true
    Cineractive:fadeIn( 3.0 )
    local constructor = findLabel( "fconst1018" )
    if live( constructor ) then Cineractive:lookAt( constructor ) end
    UI:addTitle( "ECONOMICS TUTORIAL", 100, 200, 7.0, true )
    Media:playMusic( "Mfed30.wav" )
    Media:playSound( "a2_tutorial2_intro.wav" )
    local timer = Timer( "a2_tutorial2_opening", 12.0, Timer.State.Started )
    timer:hook( "a2_tutorial2_opening_hook", nil, function( timerObject, hook )
        self:finishOpening( )
    end, nil )
    self.openingTimer = timer
end

MMM.register( A2EconomicsTutorialMission( ) )
