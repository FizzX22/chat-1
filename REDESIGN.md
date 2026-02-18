# Chat Redesign - Dark UI & Theme System

This document outlines the enhancements made to the chat system, including the new dark UI design, theme system, and qbx_core integration.

## Features

### 1. Dark UI Redesign
- **Modern Dark Theme**: Sleek dark aesthetic with improved readability
- **Better Visual Hierarchy**: Messages now have left-border indicators for different message types
- **Smooth Animations**: Messages slide in smoothly for better visual feedback
- **Improved Accessibility**: Better contrast ratios and color choices
- **Enhanced Input Field**: Larger, more responsive textarea with hover and focus states

### 2. Theme System
The chat now supports multiple built-in themes that can be switched dynamically:

#### Built-in Themes:
- **Dark** (Default): Primary dark theme with blue accents
- **Darker**: Ultra-dark theme for low-light environments
- **Dim**: Softer dark theme for comfortable reading

#### CSS Variables:
All themes use CSS custom properties for easy customization:
```css
--chat-bg-primary      /* Main background color */
--chat-bg-hover        /* Hover background state */
--chat-text-primary    /* Primary text color */
--chat-text-secondary  /* Secondary/dim text color */
--chat-border          /* Border colors */
--chat-input-bg        /* Input field background */
--chat-message-bg      /* Message background */
--accent-primary       /* Primary accent color */
--accent-secondary     /* Secondary accent color */
```

#### Theme Configuration (config.js):
```javascript
CONFIG.themes = {
  'dark': {
    name: 'Dark (Default)',
    active: true,
    style: { /* CSS variable overrides */ }
  }
}
```

#### Using Themes from Other Resources:
```lua
-- Change chat theme
exports['chat']:setTheme('darker')
```

#### JavaScript Theme Control:
```javascript
// In App.js Vue component
this.setTheme('dark');      // Set specific theme
this.cycleTheme();          // Cycle through available themes
```

Themes are saved to localStorage and persist across sessions.

### 3. Message Types & Styling
Message types now have distinct visual indicators:

| Type | Color | Usage |
|------|-------|-------|
| **normal** | Blue | Regular chat messages |
| **advert** | Dark Blue | Advertisement/broadcast messages |
| **warning** | Orange | Warning messages |
| **error** | Red | Error messages |
| **system** | Gray | System messages |
| **emergency** | Bright Red | Emergency/alert messages |
| **nonemergency** | Orange-Yellow | Non-emergency notifications |
| **report** | Green | Report/success messages |

### 4. qbx_core Integration

#### Features:
- **Command Permissions**: Integrates with qbx_core permission system
- **Command Suggestions**: Shows only commands the player can access
- **Player Status**: Works with qbx_core player loading events
- **Command Execution**: Supports qbx_core command system

#### Implementation Details:

**Server-side (sv_chat.lua):**
```lua
-- Check if qbx_core is available
local function hasQbxCore()
    return GetResourceState('qbx_core') == 'started'
end

-- Permission checking with qbx_core fallback
if hasQbxCore() then
    if exports['qbx_core']:HasPermission(player, command.name) or 
       IsPlayerAceAllowed(player, ('command.%s'):format(command.name)) then
        -- Show command
    end
else
    if IsPlayerAceAllowed(player, ('command.%s'):format(command.name)) then
        -- Show command
    end
end
```

**Client-side (cl_chat.lua):**
```lua
-- Check qbx_core availability
local function hasQbxCore()
    return GetResourceState('qbx_core') == 'started'
end

-- Export function to add messages from other resources
exports('addMessage', function(author, message, type)
  TriggerEvent('chat:addMessage', {
    args = { author, message },
    template = '<div class="chat-message '..(type or 'normal')..'"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
  })
end)

-- Export function to change theme
exports('setTheme', function(themeName)
  if themeName then
    TriggerEvent('chat:setTheme', themeName)
  end
end)
```

#### Usage Examples:

**Adding a message from another resource:**
```lua
TriggerEvent('chat:addMessage', {
    args = { 'System', 'This is a system message' },
    template = '<div class="chat-message system"><div class="chat-message-body"><strong>{0}:</strong> {1}</div></div>'
})
```

**Setting a theme from another resource:**
```lua
TriggerEvent('chat:setTheme', 'darker')
```

### 5. Enhanced Command Suggestions
- Shows command help text when available
- Displays parameter information
- Visual distinction for disabled commands
- Supports hover states
- Scrollable suggestions list

## File Changes

### Modified:
- `html/css/style.css` - Complete redesign with dark theme and CSS variables
- `html/js/App.js` - Theme system, initialization, and helper methods
- `html/js/config.default.js` - Theme configurations
- `sv_chat.lua` - qbx_core integration on server
- `cl_chat.lua` - Theme events, exports, and qbx_core detection

## Installation & Configuration

1. **Update config.js**: Copy `html/js/config.default.js` to `html/js/config.js` and customize themes as needed
2. **Set default theme**: Edit the `currentTheme` variable in configuration
3. **Customize colors**: Modify CSS variables in the theme definitions
4. **qbx_core setup**: Ensure qbx_core is properly installed (optional, chat works without it)

## Customization

### Adding a New Theme:
```javascript
CONFIG.themes['myTheme'] = {
  name: 'My Custom Theme',
  style: {
    '--chat-bg-primary': 'rgba(25, 25, 35, 0.95)',
    '--chat-bg-hover': 'rgba(35, 35, 50, 0.9)',
    '--chat-text-primary': '#ffffff',
    '--chat-text-secondary': '#cccccc',
    '--chat-border': 'rgba(100, 100, 120, 0.6)',
    '--chat-input-bg': 'rgba(20, 20, 30, 0.9)',
    '--chat-message-bg': 'rgba(30, 30, 40, 0.95)',
    '--accent-primary': '#6a5acd',
    '--accent-secondary': '#8a7acc',
  }
}
```

### Customizing Message Styling:
Edit the relevant class in `style.css`:
```css
.chat-message.system {
  background-color: rgba(105, 105, 120, 0.3);
  border-left-color: var(--msg-system);
  color: var(--chat-text-secondary);
}
```

## API Reference

### JavaScript Exports (Client):
```javascript
// From other resources using exports:
exports['chat']:setTheme('themeName')      // Change theme
exports['chat']:addMessage(author, msg, type) // Add message
```

### Lua Events (Client):
```lua
TriggerEvent('chat:setTheme', themeName)
TriggerEvent('chat:addMessage', message_table)
TriggerEvent('chat:addSuggestion', name, help, params)
```

### Lua Events (Server):
```lua
TriggerEvent('chatMessage', source, author, message)
```

## Browser Compatibility
- Chrome/Chromium 90+
- Firefox 88+
- Edge 90+
- All modern NUI browsers in FiveM

## Performance
- CSS variables ensure minimal reflow during theme changes
- Smooth animations with GPU acceleration
- Optimized scrolling for suggestion lists
- Efficient message rendering with Vue.js

## Future Enhancements
- Theme editor UI
- User theme preferences
- Custom color picker
- Theme preview before switching
- qbx_core admin command integration

## Support
For issues or questions, refer to the main README.md or create an issue in the repository.
