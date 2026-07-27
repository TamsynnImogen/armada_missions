-- AUTO-GENERATED CLEAN-ROOM MMM EXECUTABLE PILOT
-- Source mission: a2_tutorial1 / BZN: a2_tutorial_UI.bzn / title: UI Tutorial
-- Generated only from schema-3 proven IR plus the documented COMPAT adaptations below.
-- Advancement adaptation: edge-detect Enter through Debug:getKeyState; chat command next remains a fallback.

class 'A2Tutorial1PilotMission'

function A2Tutorial1PilotMission:__init( )
    self.state = { }
    self.deadlines = { }
    self.handles = { }
    self.ruleMonitors = { }
    self.introRunning = false
    self.tutorialStarted = false
    self.awaitingAdvance = false
    self.enterWasDown = false
    self.tutorialStep = 0
    self.state["p_INTRO"] = 1
    self.state["p_MISSION_END"] = 0
end

function A2Tutorial1PilotMission:bindMapHandles( )
    self.handles["mwrmhole1023"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "mwrmhole1023" or e.name == "mwrmhole1023" )
    end ):findOne( )
    self.handles["mwrmhole1022"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "mwrmhole1022" or e.name == "mwrmhole1022" )
    end ):findOne( )
    self.handles["pb_clssm1016"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "pb_clssm1016" or e.name == "pb_clssm1016" )
    end ):findOne( )
    self.handles["mmooninf1015"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "mmooninf1015" or e.name == "mmooninf1015" )
    end ):findOne( )
    self.handles["mdmoon1014"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "mdmoon1014" or e.name == "mdmoon1014" )
    end ):findOne( )
    self.handles["fmining1006"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "fmining1006" or e.name == "fmining1006" )
    end ):findOne( )
    self.handles["fbase1005"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "fbase1005" or e.name == "fbase1005" )
    end ):findOne( )
    self.handles["fcruise11004"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "fcruise11004" or e.name == "fcruise11004" )
    end ):findOne( )
    self.handles["Enterprise"] = EntityFinder( function( e )
        return e:isType( Entity.Type.GameObject ) and
            ( e.label == "Enterprise" or e.name == "Enterprise" )
    end ):findOne( )
end

function A2Tutorial1PilotMission:runRunTutorial( )
    Game.allowSave = false
    self.state["p_INTRO"] = 0
    Player( 1 ):setRelation( Player( 4 ), Player.Relation.Ally )
    Player( 4 ):setRelation( Player( 1 ), Player.Relation.Ally )
    -- COMPAT: MMM has no documented decommission lock for Enterprise.
    -- COMPAT: MMM has no documented decommission lock for fmining1006.
    -- COMPAT: MMM has no documented decommission lock for fbase1005.
    -- COMPAT: MMM has no documented decommission lock for fcruise11004.
    -- COMPAT: MMM has no documented FerengiCanSteal equivalent.
    -- COMPAT: chat remains enabled because it carries the pilot's next command.
    Cineractive:fadeIn( 3.0 )
    Cineractive.active = true
    Cineractive.skippable = false
    Cineractive:lookFrom( Path( "OPENING_CAMERA" ), 0.20000000298023224 )
    if self.handles["Enterprise"] ~= nil then Cineractive:lookAt( self.handles["Enterprise"] ) end
    Media:playMusic( "Mfed30.wav" )
    -- COMPAT: constant-speed intent is represented by lookFrom(path, speed).
    self.deadlines["p_tDisplayMainTitle"] = Game.time + 3.0
    self.deadlines["p_tRemoveMainTitle"] = Game.time + 7.0
    self.deadlines["p_tChangeStatus"] = Game.time + 9.0
    self.deadlines["p_tChangeToApproved"] = Game.time + 12.0
    self.deadlines["p_tIntroWav"] = Game.time + 6.0
    self.deadlines["p_tRemoveAuthorization"] = Game.time + 17.0
    self.introRunning = true
end

function A2Tutorial1PilotMission:runApproved( )
    -- COMPAT: the matching MMM title expires via its generated lifetime.
    UI:addSubtitle( "Retinal Authorization Status: APPROVED", -1, 100, 5.0, true )
end

function A2Tutorial1PilotMission:runChangeStatus( )
    -- COMPAT: the matching MMM title expires via its generated lifetime.
    UI:addSubtitle( "Retinal Authorization Status: VERIFYING AUTHORIZATION...  PLEASE WAIT...", -1, 100, 3.0, true )
end

function A2Tutorial1PilotMission:runEndMissionScript( )
    self.state["p_MISSION_END"] = 0
    -- GetTime result is consumed by SucceedMission.
    Mission:finish( true, 0 )
end

function A2Tutorial1PilotMission:runIntroWav( )
    Media:playSound( "a2_tutorial_ui_intro.wav" )
end

function A2Tutorial1PilotMission:runRemoveMainTitle( )
    -- COMPAT: the matching MMM title expires via its generated lifetime.
    UI:addTitle( "STARFLEET INTELLIGENCE", -1, 50, 10.0, true )
    UI:addSubtitle( "Retinal Authorization Status: SCANNING...", -1, 100, 2.0, true )
    UI:addSubtitle( "Subject: User Interface", -1, 1100, 10.0, true )
end

function A2Tutorial1PilotMission:runShowMainTitle( )
    UI:addTitle( "Tutorial: User Interface", 100, 200, 4.0, true )
end

function A2Tutorial1PilotMission:runTutorialStep( )
    if self.tutorialStep == 1 then
        -- CineractiveEnd is delivered through cineractiveFinish below.
        self.deadlines["p_tIntroWav"] = nil
        self.deadlines["p_tRemoveMainTitle"] = nil
        self.deadlines["p_tChangeStatus"] = nil
        self.deadlines["p_tChangeToApproved"] = nil
        self.deadlines["p_tRemoveAuthorization"] = nil
        self.deadlines["p_tDisplayMainTitle"] = nil
        Media:stopSounds( ) -- COMPAT: broader than stopping one stock handle.
        Media:stopSounds( ) -- COMPAT: broader than stopping one stock handle.
        -- COMPAT: MMM has no documented FerengiCanTrade equivalent.
        if self.handles["Enterprise"] ~= nil then Camera:center( self.handles["Enterprise"] ) end
        -- COMPAT: the matching MMM title expires via its generated lifetime.
        -- COMPAT: the matching MMM title expires via its generated lifetime.
        -- COMPAT: the matching MMM title expires via its generated lifetime.
        -- COMPAT: the matching MMM title expires via its generated lifetime.
        Objectives:load( "a2_tutorial1_zoom.txt" )
        Media:playSound( "a2_tutorial_ui_zoom.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 2 then
        Media:playSound( "a2_tutorial_ui_selecting_an_object.wav" )
        Media:playSound( "a2_tutorial_ui_select_enterprise.wav" )
        Objectives:load( "a2_tutorial1_select.txt" )
        Media:playSound( "a2_tutorial_ui_press_enter.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 3 then
        Objectives:load( "a2_tutorial1_height.txt" )
        Media:playSound( "a2_tutorial_ui_height_change.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 4 then
        Objectives:load( "a2_tutorial1_height_reset.txt" )
        Media:playSound( "a2_tutorial_ui_reset_height.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 5 then
        Objectives:load( "a2_tutorial1_move.txt" )
        Media:playSound( "a2_tutorial_ui_giving_orders_overview_1.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 6 then
        Objectives:load( "a2_tutorial1_warping.txt" )
        Media:playSound( "a2_tutorial_ui_MiniMap_Move.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 7 then
        Objectives:load( "a2_tutorial1_transport.txt" )
        Media:playSound( "a2_tutorial_ui_giving_orders_overview_2.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 8 then
        Objectives:load( "a2_tutorial1_orders.txt" )
        Media:playSound( "a2_tutorial_ui_command_orders_button.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 9 then
        Objectives:load( "a2_tutorial1_build.txt" )
        Media:playSound( "a2_tutorial_ui_command_build_button.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 10 then
        Objectives:load( "a2_tutorial1_tooltips.txt" )
        Media:playSound( "a2_tutorial_ui_Tooltips_toggling.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 11 then
        Objectives:load( "a2_tutorial1_tactical.txt" )
        Media:playSound( "a2_tutorial_ui_Tactical_view.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 12 then
        Objectives:load( "a2_tutorial1_rotate.txt" )
        Media:playSound( "a2_tutorial_ui_Tactical_view_rotate.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 13 then
        Objectives:load( "a2_tutorial1_focus.txt" )
        Media:playSound( "a2_tutorial_ui_Tactical_view_change_focus.wav" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 14 then
        Media:playSound( "a2_tutorial_ui_done.wav" )
        Media:playMusic( "Mrom15a.wav" )
        Objectives:load( "a2_tutorial1_text_end.txt" )
        Objectives.visible = true
        self.awaitingAdvance = true
        UI:addSubtitle( "Press Enter to continue (Esc closes chat; or type next)", 50, 1050, 5.0, false )
    elseif self.tutorialStep == 15 then
        self.state["p_MISSION_END"] = 1
        self.awaitingAdvance = false
    end
end

function A2Tutorial1PilotMission:advanceTutorial( )
    if not self.awaitingAdvance then return end
    self.awaitingAdvance = false
    self.tutorialStep = self.tutorialStep + 1
    self:runTutorialStep( )
end

function A2Tutorial1PilotMission:onAdvance( text, hook )
    self:advanceTutorial( )
end

function A2Tutorial1PilotMission:update( )
    local enterDown = Debug:getKeyState( "\r" )
    if enterDown and not self.enterWasDown then
        self:advanceTutorial( )
    end
    self.enterWasDown = enterDown
end

function A2Tutorial1PilotMission:cineractiveUpdate( )
    local deadline = self.deadlines["p_tRemoveAuthorization"]
    if self.introRunning and deadline ~= nil and Game.time >= deadline then
        Cineractive.active = false
    end
end

function A2Tutorial1PilotMission:cineractiveFinish( forced )
    if not self.introRunning or self.tutorialStarted then return end
    self.introRunning = false
    self.tutorialStarted = true
    self.tutorialStep = 1
    self:runTutorialStep( )
end

function A2Tutorial1PilotMission:conditionIntroRule( )
    return (self.state["p_INTRO"] or 0) ~= 0
end

function A2Tutorial1PilotMission:fireIntroRule( )
    self:runRunTutorial( )
end

function A2Tutorial1PilotMission:conditionShowMainTitleRule( )
    return self.deadlines["p_tDisplayMainTitle"] ~= nil and Game.time >= self.deadlines["p_tDisplayMainTitle"]
end

function A2Tutorial1PilotMission:fireShowMainTitleRule( )
    self:runShowMainTitle( )
end

function A2Tutorial1PilotMission:conditionRemoveMainTitleRule( )
    return self.deadlines["p_tRemoveMainTitle"] ~= nil and Game.time >= self.deadlines["p_tRemoveMainTitle"]
end

function A2Tutorial1PilotMission:fireRemoveMainTitleRule( )
    self:runRemoveMainTitle( )
end

function A2Tutorial1PilotMission:conditionChangeStatus( )
    return self.deadlines["p_tChangeStatus"] ~= nil and Game.time >= self.deadlines["p_tChangeStatus"]
end

function A2Tutorial1PilotMission:fireChangeStatus( )
    self:runChangeStatus( )
end

function A2Tutorial1PilotMission:conditionApproved( )
    return self.deadlines["p_tChangeToApproved"] ~= nil and Game.time >= self.deadlines["p_tChangeToApproved"]
end

function A2Tutorial1PilotMission:fireApproved( )
    self:runApproved( )
end

function A2Tutorial1PilotMission:conditionIntroWav( )
    return self.deadlines["p_tIntroWav"] ~= nil and Game.time >= self.deadlines["p_tIntroWav"]
end

function A2Tutorial1PilotMission:fireIntroWav( )
    self:runIntroWav( )
end

function A2Tutorial1PilotMission:conditionEndMissionRule( )
    return (self.state["p_MISSION_END"] or 0) ~= 0
end

function A2Tutorial1PilotMission:fireEndMissionRule( )
    self:runEndMissionScript( )
end

function A2Tutorial1PilotMission:registerRules( )
    local app = self

    local monitor001 = Monitor( "a2_tutorial1.001.IntroRule", false, nil,
        function( instance, argument )
            return argument:conditionIntroRule( )
        end, app )
    monitor001:hook( "fire.a2_tutorial1.001.IntroRule", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireIntroRule( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor001

    local monitor002 = Monitor( "a2_tutorial1.002.ShowMainTitleRule", false, nil,
        function( instance, argument )
            return argument:conditionShowMainTitleRule( )
        end, app )
    monitor002:hook( "fire.a2_tutorial1.002.ShowMainTitleRule", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireShowMainTitleRule( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor002

    local monitor003 = Monitor( "a2_tutorial1.003.RemoveMainTitleRule", false, nil,
        function( instance, argument )
            return argument:conditionRemoveMainTitleRule( )
        end, app )
    monitor003:hook( "fire.a2_tutorial1.003.RemoveMainTitleRule", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireRemoveMainTitleRule( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor003

    local monitor004 = Monitor( "a2_tutorial1.004.Change_Status", false, nil,
        function( instance, argument )
            return argument:conditionChangeStatus( )
        end, app )
    monitor004:hook( "fire.a2_tutorial1.004.Change_Status", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireChangeStatus( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor004

    local monitor005 = Monitor( "a2_tutorial1.005.Approved", false, nil,
        function( instance, argument )
            return argument:conditionApproved( )
        end, app )
    monitor005:hook( "fire.a2_tutorial1.005.Approved", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireApproved( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor005

    local monitor006 = Monitor( "a2_tutorial1.006.Intro_Wav", false, nil,
        function( instance, argument )
            return argument:conditionIntroWav( )
        end, app )
    monitor006:hook( "fire.a2_tutorial1.006.Intro_Wav", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireIntroWav( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor006

    local monitor007 = Monitor( "a2_tutorial1.007.EndMissionRule", false, nil,
        function( instance, argument )
            return argument:conditionEndMissionRule( )
        end, app )
    monitor007:hook( "fire.a2_tutorial1.007.EndMissionRule", MonitorHook.Type.OnTrue, nil,
        function( instance, hook )
            app:fireEndMissionRule( )
            instance:stop( )
        end, nil )
    self.ruleMonitors[#self.ruleMonitors + 1] = monitor007

end

function A2Tutorial1PilotMission:setup( )
    UI:addSubtitle( "Clean-room UI Tutorial pilot loaded", 50, 50, 6.0, false )
    self:bindMapHandles( )
    Player( 1 ):setRelation( Player( 2 ), Player.Relation.Ally )
    Player( 2 ):setRelation( Player( 1 ), Player.Relation.Ally )
    TextInput:hook( "a2_tutorial1.next", self, A2Tutorial1PilotMission.onAdvance, nil, "^[Nn][Ee][Xx][Tt]$" )
    self:registerRules( )
end

MMM.register( A2Tutorial1PilotMission( ) )
