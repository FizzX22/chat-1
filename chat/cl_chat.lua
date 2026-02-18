local chatInputActive = false
local chatInputActivating = false
local chatHidden = true
local chatLoaded = false
local currentTheme = 'dark'
local chatFocusReleaseTimeout = 0  -- Watchdog timer to prevent being stuck in chat

RegisterNetEvent('chatMessage')
RegisterNetEvent('chat:addTemplate')
RegisterNetEvent('chat:addMessage')
RegisterNetEvent('chat:addSuggestion')
RegisterNetEvent('chat:addSuggestions')
RegisterNetEvent('chat:removeSuggestion')
RegisterNetEvent('chat:clear')
RegisterNetEvent('chat:setTheme')

-- internal events
RegisterNetEvent('__cfx_internal:serverPrint')

RegisterNetEvent('_chat:messageEntered')

--deprecated, use chat:addMessage
AddEventHandler('chatMessage', function(author, ctype, text)
  local args = { text }
  if author ~= "" then
    table.insert(args, 1, author)
  end
  local ctype = ctype ~= false and ctype or "normal"
  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = {
      template = '<div class="chat-message '..ctype..'"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>',
      args = {author, text}
    }
  })
end)

AddEventHandler('__cfx_internal:serverPrint', function(msg)

  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = {
      templateId = 'print',
      multiline = true,
      args = { msg }
    }
  })
end)

AddEventHandler('chat:addMessage', function(message)
  SendNUIMessage({
    type = 'ON_MESSAGE',
    message = message
  })
end)

AddEventHandler('chat:addSuggestion', function(name, help, params)
  SendNUIMessage({
    type = 'ON_SUGGESTION_ADD',
    suggestion = {
      name = name,
      help = help,
      params = params or nil
    }
  })
end)

AddEventHandler('chat:addSuggestions', function(suggestions)
  for _, suggestion in ipairs(suggestions) do
    SendNUIMessage({
      type = 'ON_SUGGESTION_ADD',
      suggestion = suggestion
    })
  end
end)

AddEventHandler('chat:removeSuggestion', function(name)
  SendNUIMessage({
    type = 'ON_SUGGESTION_REMOVE',
    name = name
  })
end)

AddEventHandler('chat:addTemplate', function(id, html)
  SendNUIMessage({
    type = 'ON_TEMPLATE_ADD',
    template = {
      id = id,
      html = html
    }
  })
end)

AddEventHandler('chat:clear', function(name)
  SendNUIMessage({
    type = 'ON_CLEAR'
  })
end)

-- Theme management event
AddEventHandler('chat:setTheme', function(themeName)
  if themeName then
    currentTheme = themeName
    SendNUIMessage({
      type = 'CHAT_SET_THEME',
      theme = themeName
    })
  end
end)

RegisterNUICallback('chatResult', function(data, cb)
  -- Debug: indicate we received chatResult
  print('[chat] RegisterNUICallback chatResult received, canceled=' .. tostring(data.canceled))
  TriggerEvent('chat:addMessage', { args = { 'CHAT', 'chatResult received: ' .. tostring(data.canceled) } })

  -- Ensure input flags and focus are always cleared to avoid freezing player
  chatInputActive = false
  chatInputActivating = false
  chatFocusReleaseTimeout = 0  -- Cancel watchdog timer

  -- Try to release focus and cursor (call multiple forms defensively)
  local ok1, err1 = pcall(function() SetNuiFocus(false, false) end)
  local ok2, err2 = pcall(function() SetNuiFocus(false) end)
  print('[chat] SetNuiFocus results: ' .. tostring(ok1) .. ', ' .. tostring(ok2))
  TriggerEvent('chat:addMessage', { args = { 'CHAT', 'SetNuiFocus results: ' .. tostring(ok1) .. ', ' .. tostring(ok2) } })

  if not data.canceled then
    local id = PlayerId()

    --deprecated
    local r, g, b = 0, 0x99, 255

    if data.message and data.message:sub(1, 1) == '/' then
      -- protect ExecuteCommand from throwing and ensure focus released
      local ok, err = pcall(function()
        ExecuteCommand(data.message:sub(2))
      end)
      if not ok then
        TriggerEvent('chat:addMessage', {
          args = { 'Chat', 'Command execution error: ' .. tostring(err) }
        })
      end
    else
      TriggerServerEvent('_chat:messageEntered', GetPlayerName(id), { r, g, b }, data.message)
    end
  end

  cb('ok')
end)

-- Handle postMessage events from NUI (alternative communication method for reliability)
RegisterNUICallback('message', function(data, cb)
  if data.action == 'loaded' then
    print('[chat] NUI loaded event via postMessage')
    TriggerServerEvent('chat:init')
    chatLoaded = true
    chatInputActive = false
    SetNuiFocus(false, false)
  elseif data.action == 'chatResult' then
    print('[chat] NUI chatResult event: canceled=' .. tostring(data.data.canceled))
    chatInputActive = false
    chatInputActivating = false
    chatFocusReleaseTimeout = 0
    SetNuiFocus(false, false)
  end
  cb('ok')
end)

-- Client-side command forwards so server receives /luak and /uak reliably
RegisterCommand('luak', function(source, args, raw)
    local msg = table.concat(args, ' ')
    TriggerServerEvent('chat:server_luak', msg)
end, false)

RegisterCommand('uak', function(source, args, raw)
    local msg = table.concat(args, ' ')
    TriggerServerEvent('chat:server_uak', msg)
end, false)

local function refreshCommands()
  if GetRegisteredCommands then
    local registeredCommands = GetRegisteredCommands()

    local suggestions = {}

    for _, command in ipairs(registeredCommands) do
        if IsAceAllowed(('command.%s'):format(command.name)) then
            table.insert(suggestions, {
                name = '/' .. command.name,
                help = command.help or ''
            })
        end
    end

    TriggerEvent('chat:addSuggestions', suggestions)
  end
end

local function refreshThemes()
  local themes = {}

  for resIdx = 0, GetNumResources() - 1 do
    local resource = GetResourceByFindIndex(resIdx)

    if GetResourceState(resource) == 'started' then
      local numThemes = GetNumResourceMetadata(resource, 'chat_theme')

      if numThemes > 0 then
        local themeName = GetResourceMetadata(resource, 'chat_theme')
        local themeData = json.decode(GetResourceMetadata(resource, 'chat_theme_extra') or 'null')

        if themeName and themeData then
          themeData.baseUrl = 'nui://' .. resource .. '/'
          themes[themeName] = themeData
        end
      end
    end
  end

  SendNUIMessage({
    type = 'ON_UPDATE_THEMES',
    themes = themes
  })
end

-- Check if qbx_core exists
local function hasQbxCore()
    return GetResourceState('qbx_core') == 'started'
end

-- Notify player when connecting
local function notifyPlayer(message, type)
    TriggerEvent('chat:addMessage', {
        args = { "CHAT", message },
        color = { 255, 255, 255 },
        multiline = false,
        template = '<div class="chat-message '..type..'"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
    })
end

AddEventHandler('onClientResourceStart', function(resName)
  Wait(500)

  refreshCommands()
  refreshThemes()
  
  -- Notify if qbx_core is loaded
  if hasQbxCore() and resName == 'qbx_core' then
    notifyPlayer('qbx_core integration enabled', 'system')
  end
end)

AddEventHandler('onClientResourceStop', function(resName)
  Wait(500)

  refreshCommands()
  refreshThemes()
end)

RegisterNUICallback('loaded', function(data, cb)
  TriggerServerEvent('chat:init');

  refreshCommands()
  refreshThemes()

  chatLoaded = true
  
  -- Print info message
  notifyPlayer('Chat loaded and ready | Theme: '..currentTheme, 'system')

  cb('ok')
end)

-- Export function to change theme from other resources
exports('setTheme', function(themeName)
  if themeName then
    TriggerEvent('chat:setTheme', themeName)
  end
end)

-- Export function to add message from other resources
exports('addMessage', function(author, message, type)
  TriggerEvent('chat:addMessage', {
    args = { author, message },
    template = '<div class="chat-message '..(type or 'normal')..'"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
  })
end)

Citizen.CreateThread(function()
  SetTextChatEnabled(false)
  SetNuiFocus(false, false)

  while true do
    Wait(3)

    -- Watchdog timer: Force release focus if stuck for too long
    if chatInputActive and chatFocusReleaseTimeout > 0 then
      chatFocusReleaseTimeout = chatFocusReleaseTimeout - 1
      if chatFocusReleaseTimeout <= 0 then
        print('^1[Chat] Focus stuck! Force releasing...^7')
        chatInputActive = false
        chatInputActivating = false
        SetNuiFocus(false, false)
        chatFocusReleaseTimeout = 0
      end
    end

    if not chatInputActive then
      if IsControlPressed(0, 245) --[[ INPUT_MP_TEXT_CHAT_ALL ]] then
        chatInputActive = true
        chatInputActivating = true
        chatFocusReleaseTimeout = 100  -- 3 second timeout (100 iterations * 3ms + NUI processing)

        SendNUIMessage({
          type = 'ON_OPEN'
        })
      end
    end

    if chatInputActivating then
      if not IsControlPressed(0, 245) then
        SetNuiFocus(true)

        chatInputActivating = false
      end
    end

    -- Emergency escape key handler to prevent being stuck in chat UI
    if chatInputActive and IsControlJustReleased(0, 322) --[[ INPUT_SCRIPT_PAD_UP / ESC ]] then
      chatInputActive = false
      chatFocusReleaseTimeout = 0
      SetNuiFocus(false, false)
    end

    if chatLoaded then
      local shouldBeHidden = false

      if IsScreenFadedOut() or IsPauseMenuActive() then
        shouldBeHidden = true
      end

      if (shouldBeHidden and not chatHidden) or (not shouldBeHidden and chatHidden) then
        chatHidden = shouldBeHidden

        SendNUIMessage({
          type = 'ON_SCREEN_STATE_CHANGE',
          shouldHide = shouldBeHidden
        })
      end
    end
  end
end)