RegisterServerEvent('chat:init')
RegisterServerEvent('chat:addTemplate')
RegisterServerEvent('chat:addMessage')
RegisterServerEvent('chat:addSuggestion')
RegisterServerEvent('chat:removeSuggestion')
RegisterServerEvent('_chat:messageEntered')
RegisterServerEvent('chat:clear')
RegisterServerEvent('__cfx_internal:commandFallback')
RegisterServerEvent('chat:server_luak')
RegisterServerEvent('chat:server_uak')

AddEventHandler('_chat:messageEntered', function(author, color, message)
    if not message or not author then
        return
    end

    TriggerEvent('chatMessage', source, author, message)

    if not WasEventCanceled() then
        --TriggerClientEvent('chatMessage', -1, 'OOC | '..author,  false, message)
    end
end)

AddEventHandler('__cfx_internal:commandFallback', function(command)
    local name = GetPlayerName(source)

    TriggerEvent('chatMessage', source, name, '/' .. command)

    if not WasEventCanceled() then
        TriggerClientEvent('chatMessage', -1, name, false, '/' .. command) 
    end

    CancelEvent()
end)

-- player join messages
AddEventHandler('chat:init', function()
    --TriggerClientEvent('chatMessage', -1, '', { 255, 255, 255 }, '^2* ' .. GetPlayerName(source) .. ' joined.')
end)

AddEventHandler('playerDropped', function(reason)
    --TriggerClientEvent('chatMessage', -1, '', { 255, 255, 255 }, '^2* ' .. GetPlayerName(source) ..' left (' .. reason .. ')')
end)

-- Check if qbx_core exists
local function hasQbxCore()
    return GetResourceState('qbx_core') == 'started'
end

-- command suggestions for clients (qbx_core compatible)
local function refreshCommands(player)
    if not player then return end
    local pid = tonumber(player)
    if not pid then return end

    if GetRegisteredCommands then
        local ok, registeredCommands = pcall(GetRegisteredCommands)
        if not ok or not registeredCommands then return end

        local suggestions = {}

        for _, command in ipairs(registeredCommands) do
            local allowed = false

            if hasQbxCore() then
                local okperm, result = pcall(function()
                    return exports['qbx_core']:HasPermission(pid, command.name)
                end)
                if okperm and result then
                    allowed = true
                else
                    local okace, aceRes = pcall(IsPlayerAceAllowed, pid, ('command.%s'):format(command.name))
                    if okace and aceRes then allowed = true end
                end
            else
                local okace, aceRes = pcall(IsPlayerAceAllowed, pid, ('command.%s'):format(command.name))
                if okace and aceRes then allowed = true end
            end

            if allowed then
                table.insert(suggestions, {
                    name = '/' .. command.name,
                    help = command.help or ''
                })
            end
        end

        -- Add custom chat commands
        table.insert(suggestions, {
            name = '/luak',
            help = 'Local chat - only nearby players can see (100m range)'
        })

        table.insert(suggestions, {
            name = '/uak',
            help = 'Global chat - all players can see'
        })

        TriggerClientEvent('chat:addSuggestions', pid, suggestions)
    end
end

-- Handle chat commands with qbx_core integration
AddEventHandler('chatMessage', function(source, author, message)
    if not message then return end

    -- If it's a command (starts with '/'), try command execution
    if message:sub(1, 1) == '/' then
        local args = string.split(message, ' ')
        local command = args[1]:sub(2):lower()

        if not command or command == '' then
            return
        end

        -- If qbx_core is available, let it handle command execution
        if hasQbxCore() then
            local ok, executedCommand = pcall(function()
                return exports['qbx_core']:ExecuteCommand(source, command, args)
            end)
            if ok and executedCommand then
                CancelEvent()
                return
            end
        end

        -- Handle built-in chat commands (uak/luak) explicitly when typed
        if command == 'uak' then
            local msg = table.concat(args, ' ', 2)
            sendGlobalChat(source, msg)
            CancelEvent()
            return
        elseif command == 'luak' then
            local msg = table.concat(args, ' ', 2)
            sendLocalChat(source, msg)
            CancelEvent()
            return
        end

        return
    end

    -- Not a command: broadcast normal chat message to all clients
    TriggerClientEvent('chat:addMessage', -1, {
        args = { author, message }
    })
end)

-- Refresh commands on resource start
AddEventHandler('chat:init', function()
    refreshCommands(source)
end)

AddEventHandler('onServerResourceStart', function(resName)
    Wait(500)

    for _, player in ipairs(GetPlayers()) do
        refreshCommands(player)
    end
end)

-- Refresh commands when qbx_core loads
AddEventHandler('qbx_core:server:PlayerLoaded', function(source)
    Wait(100)
    refreshCommands(source)
end)

-- Helper function to get player character info from qbx_core
local function getPlayerCharacterInfo(playerId)
    if not hasQbxCore() then
        return GetPlayerName(playerId), nil, nil
    end
    
    local player = exports['qbx_core']:GetPlayer(playerId)
    if not player then
        return GetPlayerName(playerId), nil, nil
    end
    
    local charInfo = player.PlayerData.charinfo
    if charInfo then
        return charInfo.firstname .. ' ' .. charInfo.lastname, playerId, true
    end
    
    return GetPlayerName(playerId), playerId, false
end

-- Helper function to get player coordinates
local function getPlayerCoords(playerId)
    local pid = tonumber(playerId) or playerId
    local ped = GetPlayerPed(pid)
    if ped == 0 then
        return nil
    end
    return GetEntityCoords(ped)
end

-- Helper to send local chat (used by command and server event)
local function sendLocalChat(fromSource, message)
    local playerName, playerId, hasCharInfo = getPlayerCharacterInfo(fromSource)
    local playerCoords = getPlayerCoords(fromSource)
    playerId = playerId or fromSource
    local proximityRange = 100.0 -- 100 meters proximity

    local players = GetPlayers()
    for _, target in ipairs(players) do
        local tid = tonumber(target)
        local targetCoords = getPlayerCoords(tid)
        local distance = getDistance(playerCoords, targetCoords)

        if distance <= proximityRange then
            TriggerClientEvent('chat:addMessage', tid, {
                args = { playerName, '[LOCAL] ' .. message, playerId },
                template = '<div class="chat-message advert"><div class="chat-message-body"><strong style="color: #74c0fc;">{0}</strong> <span style="color: #a0a0a0;">(ID: {2})</span> <strong>»</strong> <span style="color: #c0d9ff;">{1}</span></div></div>'
            })
        end
    end

    print(('^2[Local Chat] %s (ID: %s): %s^7'):format(tostring(playerName), tostring(playerId), tostring(message)))
end

-- Helper to send global chat (used by command and server event)
local function sendGlobalChat(fromSource, message)
    local playerName, playerId, hasCharInfo = getPlayerCharacterInfo(fromSource)
    playerId = playerId or fromSource
    local players = GetPlayers()
    for _, target in ipairs(players) do
        local tid = tonumber(target)
        TriggerClientEvent('chat:addMessage', tid, {
            args = { playerName, '[GLOBAL] ' .. message, playerId },
            template = '<div class="chat-message"><div class="chat-message-body"><strong style="color: #4dabf7;">{0}</strong> <span style="color: #a0a0a0;">(ID: {2})</span> <strong>»</strong> <span style="color: #b8ccff;">{1}</span></div></div>'
        })
    end

    print(('^3[Global Chat] %s (ID: %s): %s^7'):format(tostring(playerName), tostring(playerId), tostring(message)))
end

-- Helper function to calculate distance between two coordinates
local function getDistance(coord1, coord2)
    if not coord1 or not coord2 then
        return 999999
    end
    local dx = coord1.x - coord2.x
    local dy = coord1.y - coord2.y
    local dz = coord1.z - coord2.z
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

-- Local chat command - /luak (Local UAK)
RegisterCommand('luak', function(source, args, rawCommand)
    -- forward to the shared local chat sender (works whether qbx_core is present or not)
    local message = table.concat(args, ' ')
    if message == nil or message == '' then
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'System', 'Usage: /luak [message]' },
            template = '<div class="chat-message warning"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
        })
        return
    end

    sendLocalChat(source, message)
end, false)

-- Server events so client-side command forwards work reliably
AddEventHandler('chat:server_luak', function(message)
    local _source = source
    sendLocalChat(_source, message)
end)

AddEventHandler('chat:server_uak', function(message)
    local _source = source
    sendGlobalChat(_source, message)
end)

-- Ensure remote events are registered for client forwards (defensive)
RegisterServerEvent('chat:server_luak')
RegisterServerEvent('chat:server_uak')

-- Global chat command - /uak (Universal UAK)
RegisterCommand('uak', function(source, args, rawCommand)
    -- forward to the shared global chat sender (works whether qbx_core is present or not)
    local message = table.concat(args, ' ')
    if message == nil or message == '' then
        TriggerClientEvent('chat:addMessage', source, {
            args = { 'System', 'Usage: /uak [message]' },
            template = '<div class="chat-message warning"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
        })
        return
    end

    sendGlobalChat(source, message)
end, false)

-- Helper function for string splitting
function string.split(inputstr, sep)
    if sep == nil then
        sep = "%s"
    end
    local t = {}
    for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
        table.insert(t, str)
    end
    return t
end
