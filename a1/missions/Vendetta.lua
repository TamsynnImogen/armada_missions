-- CLEAN-ROOM STAR TREK: ARMADA 1 CAMPAIGN CONVERSION
--
-- Behaviour evidence: retail BZN, objective text, and static DSL/DRL analysis.
-- The original mission binaries are never loaded or executed by this script.

class 'A1VendettaMission'

local SPEC = {
    title = "VENDETTA",
    hostile_prefixes = {
        "k",
        "z"
    },
    hostile_targets = {
        {
            id = "toral",
            labels = {
                "Toral"
            },
            odfs = {
                "ktoral"
            }
        }
    },
    tracked = {
        {
            id = "worf",
            labels = {
                "Worf",
                "WORF1"
            },
            odfs = {
                "favenger"
            }
        },
        {
            id = "death_base",
            labels = {
                "DeathBase"
            },
            odfs = {
                "zneubase"
            }
        },
        {
            id = "fifth",
            labels = {
                "TheFifth"
            },
            odfs = {
                "zjemdest"
            }
        },
        {
            id = "pooj",
            labels = {
                "Pooj"
            },
            odfs = {
                "zferengi"
            }
        },
        {
            id = "baal",
            labels = {
                "Baal"
            },
            odfs = {
                "zsondest"
            }
        },
        {
            id = "derelict_base",
            labels = {
                "DerelictBase"
            },
            odfs = {
                "fbase"
            }
        },
        {
            id = "derelict_yard",
            labels = {
                "DerelictShipyard"
            },
            odfs = {
                "fyard"
            }
        }
    },
    vitals = {
        {
            id = "worf",
            labels = {
                "Worf",
                "WORF1"
            },
            odfs = {
                "favenger"
            }
        }
    },
    stages = {
        {
            objective = "f5ob1.txt",
            condition = {
                kind = "near",
                actor = {
                    id = "worf",
                    labels = {
                        "Worf",
                        "WORF1"
                    },
                    odfs = {
                        "favenger"
                    }
                },
                destination = {
                    id = "worm1",
                    labels = {
                        "WormholeEntrance1"
                    },
                    odfs = { }
                },
                radius = 700
            }
        },
        {
            objective = "f5ob2.txt",
            condition = {
                kind = "targets_gone",
                targets = {
                    {
                        id = "death_base",
                        labels = {
                            "DeathBase"
                        },
                        odfs = {
                            "zneubase"
                        }
                    }
                }
            }
        },
        {
            objective = "f5ob3.txt",
            condition = {
                kind = "near",
                actor = {
                    id = "worf",
                    labels = {
                        "Worf",
                        "WORF1"
                    },
                    odfs = {
                        "favenger"
                    }
                },
                destination = {
                    id = "worm2",
                    labels = {
                        "WormholeEntrance2"
                    },
                    odfs = { }
                },
                radius = 700
            }
        },
        {
            objective = "f5ob4.txt",
            condition = {
                kind = "targets_owned",
                targets = {
                    {
                        id = "fifth",
                        labels = {
                            "TheFifth"
                        },
                        odfs = {
                            "zjemdest"
                        }
                    },
                    {
                        id = "pooj",
                        labels = {
                            "Pooj"
                        },
                        odfs = {
                            "zferengi"
                        }
                    },
                    {
                        id = "baal",
                        labels = {
                            "Baal"
                        },
                        odfs = {
                            "zsondest"
                        }
                    }
                }
            }
        },
        {
            objective = "f5ob5.txt",
            condition = {
                kind = "all",
                conditions = {
                    {
                        kind = "targets_owned",
                        targets = {
                            {
                                id = "derelict_base",
                                labels = {
                                    "DerelictBase"
                                },
                                odfs = {
                                    "fbase"
                                }
                            },
                            {
                                id = "derelict_yard",
                                labels = {
                                    "DerelictShipyard"
                                },
                                odfs = {
                                    "fyard"
                                }
                            }
                        }
                    },
                    {
                        kind = "near",
                        actor = {
                            id = "worf",
                            labels = {
                                "Worf",
                                "WORF1"
                            },
                            odfs = {
                                "favenger"
                            }
                        },
                        destination = {
                            id = "worm_end",
                            labels = {
                                "WormholeEnd"
                            },
                            odfs = { }
                        },
                        radius = 800
                    }
                }
            }
        }
    }
}
local function live( entity )
    if entity == nil or type( entity ) == "boolean" then return false end
    local ok, valid = pcall( function( ) return entity.valid end )
    if not ok or not valid then return false end
    local crewOk, crew = pcall( function( ) return entity.crew end )
    return not crewOk or crew == nil or crew > 0
end

local function field( entity, key )
    if entity == nil then return nil end
    local ok, value = pcall( function( ) return entity[ key ] end )
    if ok then return value end
    return nil
end

local function lower( value )
    return string.lower( tostring( value or "" ) )
end

local function odfBase( entity )
    local result = lower( field( entity, "odf" ) )
    result = string.gsub( result, "\\", "/" )
    result = string.match( result, "([^/]+)$" ) or result
    return string.gsub( result, "%.odf$", "" )
end

local function playerNumber( entity )
    local player = field( entity, "player" )
    return player and field( player, "number" ) or nil
end

local function allCraft( )
    return EntityFinder( function( entity )
        local ok, result = pcall( function( ) return entity:isType( Entity.Type.Craft ) end )
        return ok and result
    end ):find( ) or { }
end

local function matchesPrefix( entity, prefixes )
    local odf = odfBase( entity )
    for _, prefix in ipairs( prefixes or { } ) do
        if string.sub( odf, 1, string.len( prefix ) ) == lower( prefix ) then return true end
    end
    return false
end

local function matchesOdf( entity, odfs )
    local odf = odfBase( entity )
    for _, wanted in ipairs( odfs or { } ) do
        if odf == string.gsub( lower( wanted ), "%.odf$", "" ) then return true end
    end
    return false
end

local function isLikelyStation( entity )
    local odf = odfBase( entity )
    local words = { "base", "yard", "mining", "sensor", "turret", "resear", "super", "facility", "station", "const" }
    for _, word in ipairs( words ) do
        if string.find( odf, word, 1, true ) then return true end
    end
    return false
end

local function distanceSquared( a, b )
    if a == nil or b == nil then return 1000000000000 end
    local x, y, z = a.x - b.x, a.y - b.y, a.z - b.z
    return x * x + y * y + z * z
end

local function targetKey( target )
    return target.id or table.concat( target.labels or target.odfs or { "target" }, "|" )
end

function A1VendettaMission:__init( )
    self.stageIndex = 1
    self.ending = false
    self.ended = false
    self.seenTargets = { }
    self.targetHandles = { }
    self.spawned = { }
    self.hostilePlayers = { }
    self.loadedAIPs = { }
    self.seenPrefixes = { }
    self.stageTimerDone = false
    self.timerSerial = 0
    self.timers = { }
end

function A1VendettaMission:schedule( name, seconds, callback )
    self.timerSerial = self.timerSerial + 1
    local id = "a1_campaign_" .. name .. "_" .. tostring( self.timerSerial )
    local timer = Timer( id, seconds, Timer.State.Started )
    timer:hook( id .. "_hook", nil, function( )
        if not self.ended then callback( ) end
    end, nil )
    self.timers[ id ] = timer
end

function A1VendettaMission:findTarget( target )
    if target == nil then return nil end
    if target.spawned ~= nil and live( self.spawned[ target.spawned ] ) then return self.spawned[ target.spawned ] end
    local key = targetKey( target )
    if self.seenTargets[ key ] and self.targetHandles[ key ] ~= nil then
        if live( self.targetHandles[ key ] ) then return self.targetHandles[ key ] end
        return nil
    end
    local wantedLabels = { }
    for _, label in ipairs( target.labels or { } ) do wantedLabels[ lower( label ) ] = true end
    local firstOdf = nil
    for _, entity in pairs( allCraft( ) ) do
        local label = lower( field( entity, "label" ) or field( entity, "name" ) )
        if wantedLabels[ label ] then
            self.seenTargets[ key ] = true
            self.targetHandles[ key ] = entity
            return entity
        end
        if firstOdf == nil and matchesOdf( entity, target.odfs ) then firstOdf = entity end
    end
    if live( firstOdf ) then
        self.seenTargets[ key ] = true
        self.targetHandles[ key ] = firstOdf
        return firstOdf
    end
    return nil
end

function A1VendettaMission:rememberTarget( target )
    self:findTarget( target )
end

function A1VendettaMission:rememberImportantObjects( )
    for _, target in ipairs( SPEC.tracked or { } ) do self:rememberTarget( target ) end
    for _, target in ipairs( SPEC.vitals or { } ) do self:rememberTarget( target ) end
end

function A1VendettaMission:effectivePrefixes( kind )
    local stage = SPEC.stages[ self.stageIndex ] or { }
    if kind == "hostile" then return stage.hostile_prefixes or SPEC.hostile_prefixes or { } end
    return stage.allied_prefixes or SPEC.allied_prefixes or { }
end

function A1VendettaMission:identifyPlayers( )
    local hostilePrefixes = self:effectivePrefixes( "hostile" )
    local alliedPrefixes = self:effectivePrefixes( "allied" )
    for _, entity in pairs( allCraft( ) ) do
        local number = playerNumber( entity )
        if number ~= nil and number ~= 1 then
            for _, prefix in ipairs( hostilePrefixes ) do
                if matchesPrefix( entity, { prefix } ) then
                    self.hostilePlayers[ number ] = true
                    self.seenPrefixes[ lower( prefix ) ] = true
                end
            end
            for _, prefix in ipairs( alliedPrefixes ) do
                if matchesPrefix( entity, { prefix } ) then self.seenPrefixes[ lower( prefix ) ] = true end
            end
            if matchesPrefix( entity, alliedPrefixes ) then
                pcall( function( ) self.player:setRelation( Player( number ), Player.Relation.Ally ) end )
                pcall( function( ) Player( number ):setRelation( self.player, Player.Relation.Ally ) end )
            end
        end
    end
    for _, seed in ipairs( SPEC.hostile_targets or { } ) do
        local entity = self:findTarget( seed )
        local number = playerNumber( entity )
        if number ~= nil and number ~= 1 then self.hostilePlayers[ number ] = true end
    end
    for number, _ in pairs( self.hostilePlayers ) do
        pcall( function( ) self.player:setRelation( Player( number ), Player.Relation.Enemy ) end )
        pcall( function( ) Player( number ):setRelation( self.player, Player.Relation.Enemy ) end )
    end
end

function A1VendettaMission:loadAIPs( )
    for _, aip in ipairs( SPEC.aips or { } ) do
        local owners = { }
        if aip.target ~= nil then
            local owner = playerNumber( self:findTarget( aip.target ) )
            if owner ~= nil and owner ~= 1 then owners[ owner ] = true end
        else
            for _, entity in pairs( allCraft( ) ) do
                local owner = playerNumber( entity )
                if owner ~= nil and owner ~= 1 and matchesPrefix( entity, { aip.prefix } ) then owners[ owner ] = true end
            end
        end
        for owner, _ in pairs( owners ) do
            local key = tostring( owner ) .. ":" .. aip.file
            if not self.loadedAIPs[ key ] then
                pcall( function( ) Player( owner ):loadAIP( aip.file ) end )
                self.loadedAIPs[ key ] = true
            end
        end
    end
end

function A1VendettaMission:spawnStageObjects( stage )
    for _, item in ipairs( stage.spawn or { } ) do
        local existing = item.if_missing and self:findTarget( item.if_missing ) or nil
        if not live( existing ) then
            local position = Vector( item.position[ 1 ], item.position[ 2 ], item.position[ 3 ] )
            local entity = Entity.add( item.odf, 1, position )
            if live( entity ) then
                pcall( function( ) entity.label = item.label end )
                self.spawned[ item.id ] = entity
                self.seenTargets[ item.id ] = true
                self.targetHandles[ item.id ] = entity
            end
        else
            self.spawned[ item.id ] = existing
        end
    end
end

function A1VendettaMission:completeDisplayedObjectives( )
    for index = 1, 16 do
        if Objectives.objectives[ index ] ~= nil then Objectives.objectives[ index ].state = true end
    end
    Objectives.visible = true
end

function A1VendettaMission:enterStage( )
    local stage = SPEC.stages[ self.stageIndex ]
    if stage == nil then self:startSuccess( ); return end
    self.stageTimerDone = false
    Objectives:load( stage.objective )
    Objectives.visible = true
    self:spawnStageObjects( stage )
    self:rememberImportantObjects( )
    self:identifyPlayers( )
    self:loadAIPs( )
    if stage.condition ~= nil and stage.condition.kind == "timer" then
        local enteringStage = self.stageIndex
        self:schedule( "stage", stage.condition.seconds, function( )
            if self.stageIndex == enteringStage then self.stageTimerDone = true end
        end )
    end
    print( "[" .. SPEC.title .. "] stage " .. tostring( self.stageIndex ) .. ": " .. stage.objective )
end

function A1VendettaMission:setup( )
    print( "[A1Campaign] clean-room conversion loaded: " .. SPEC.title )
    self.player = Player( 1 )
    UI:addTitle( SPEC.title, 50, 50, 7.0, true )
    self:enterStage( )
end

function A1VendettaMission:targetGone( target )
    local entity = self:findTarget( target )
    if live( entity ) then return false end
    local key = targetKey( target )
    local remembered = self.targetHandles[ key ]
    return self.seenTargets[ key ] and not live( remembered )
end

function A1VendettaMission:targetOwned( target )
    local entity = self:findTarget( target )
    return live( entity ) and playerNumber( entity ) == 1
end

function A1VendettaMission:targetResolved( target )
    return self:targetOwned( target ) or self:targetGone( target )
end

function A1VendettaMission:playerEntitiesByOdf( odfs )
    local result = { }
    for _, entity in pairs( allCraft( ) ) do
        if playerNumber( entity ) == 1 and matchesOdf( entity, odfs ) then table.insert( result, entity ) end
    end
    return result
end

function A1VendettaMission:prefixesGone( condition )
    local found = false
    local saw = false
    for _, prefix in ipairs( condition.prefixes or { } ) do
        if self.seenPrefixes[ lower( prefix ) ] then saw = true end
    end
    for _, entity in pairs( allCraft( ) ) do
        if playerNumber( entity ) ~= 1 and matchesPrefix( entity, condition.prefixes )
            and ( not condition.ship_only or not isLikelyStation( entity ) ) then
            found = true
            for _, prefix in ipairs( condition.prefixes or { } ) do
                if matchesPrefix( entity, { prefix } ) then self.seenPrefixes[ lower( prefix ) ] = true end
            end
            saw = true
        end
    end
    return saw and not found
end

function A1VendettaMission:hostilePlayersGone( )
    local sawHostile = false
    for number, _ in pairs( self.hostilePlayers ) do
        sawHostile = true
        for _, entity in pairs( allCraft( ) ) do
            if playerNumber( entity ) == number then return false end
        end
    end
    return sawHostile
end

function A1VendettaMission:evaluate( condition )
    if condition == nil then return false end
    if condition.kind == "timer" then return self.stageTimerDone end
    if condition.kind == "all" then
        for _, child in ipairs( condition.conditions or { } ) do if not self:evaluate( child ) then return false end end
        return true
    end
    if condition.kind == "any" then
        for _, child in ipairs( condition.conditions or { } ) do if self:evaluate( child ) then return true end end
        return false
    end
    if condition.kind == "targets_gone" then
        for _, item in ipairs( condition.targets or { } ) do if not self:targetGone( item ) then return false end end
        return true
    end
    if condition.kind == "targets_owned" then
        for _, item in ipairs( condition.targets or { } ) do if not self:targetOwned( item ) then return false end end
        return true
    end
    if condition.kind == "targets_resolved" then
        for _, item in ipairs( condition.targets or { } ) do if not self:targetResolved( item ) then return false end end
        return true
    end
    if condition.kind == "near" then
        local actor = self:findTarget( condition.actor )
        local destination = self:findTarget( condition.destination )
        return live( actor ) and live( destination )
            and distanceSquared( actor.position, destination.position ) <= condition.radius * condition.radius
    end
    if condition.kind == "near_position" then
        local actor = self:findTarget( condition.actor )
        local point = Vector( condition.position[ 1 ], condition.position[ 2 ], condition.position[ 3 ] )
        return live( actor ) and distanceSquared( actor.position, point ) <= condition.radius * condition.radius
    end
    if condition.kind == "near_player_odf" then
        local actor = self:findTarget( condition.actor )
        if not live( actor ) then return false end
        for _, destination in ipairs( self:playerEntitiesByOdf( condition.odfs ) ) do
            if distanceSquared( actor.position, destination.position ) <= condition.radius * condition.radius then return true end
        end
        return false
    end
    if condition.kind == "player_has_odf" then return #self:playerEntitiesByOdf( condition.odfs ) > 0 end
    if condition.kind == "player_odf_near" then
        local destination = self:findTarget( condition.destination )
        if not live( destination ) then return false end
        for _, entity in ipairs( self:playerEntitiesByOdf( condition.odfs ) ) do
            if distanceSquared( entity.position, destination.position ) <= condition.radius * condition.radius then return true end
        end
        return false
    end
    if condition.kind == "player_near" then
        local destination = self:findTarget( condition.destination )
        if not live( destination ) then return false end
        for _, entity in pairs( allCraft( ) ) do
            if playerNumber( entity ) == 1
                and distanceSquared( entity.position, destination.position ) <= condition.radius * condition.radius then return true end
        end
        return false
    end
    if condition.kind == "prefixes_gone" then return self:prefixesGone( condition ) end
    if condition.kind == "hostile_players_gone" then return self:hostilePlayersGone( ) end
    return false
end

function A1VendettaMission:vitalLost( vital )
    if self.stageIndex < ( vital.stage_min or 1 ) then return false end
    local entity = self:findTarget( vital )
    local key = targetKey( vital )
    if not self.seenTargets[ key ] then return false end
    if not live( entity ) and not live( self.targetHandles[ key ] ) then return true end
    local handle = entity or self.targetHandles[ key ]
    return vital.owner ~= nil and live( handle ) and playerNumber( handle ) ~= vital.owner
end

function A1VendettaMission:startSuccess( )
    if self.ending then return end
    self.ending = true
    self:completeDisplayedObjectives( )
    UI:addTitle( "MISSION ACCOMPLISHED", 50, 50, 6.0, true )
    self:schedule( "success", 3.0, function( )
        self.ended = true
        Mission:finish( true, 0 )
    end )
end

function A1VendettaMission:startFailure( )
    if self.ending then return end
    self.ending = true
    UI:addTitle( "MISSION FAILED", 50, 50, 6.0, true )
    self:schedule( "failure", 3.0, function( )
        self.ended = true
        Mission:finish( false, 0 )
    end )
end

function A1VendettaMission:update( )
    if self.ending or self.ended then return end
    self:rememberImportantObjects( )
    self:identifyPlayers( )
    for _, vital in ipairs( SPEC.vitals or { } ) do
        if self:vitalLost( vital ) then self:startFailure( ); return end
    end
    local stage = SPEC.stages[ self.stageIndex ]
    if stage ~= nil and self:evaluate( stage.condition ) then
        self:completeDisplayedObjectives( )
        self.stageIndex = self.stageIndex + 1
        self:enterStage( )
    end
end

function A1VendettaMission:cineractiveUpdate( ) end
function A1VendettaMission:cineractiveFinish( forced ) end

MMM.register( A1VendettaMission( ) )
