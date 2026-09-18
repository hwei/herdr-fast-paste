local wezterm = require 'wezterm'
local act = wezterm.action
local module = {}

function module.apply_to_config(config)
  config.keys = config.keys or {}
  table.insert(config.keys, {
    key = 'Insert',
    mods = 'SHIFT',
    action = wezterm.action_callback(function(window, pane)
      local process = string.lower(pane:get_foreground_process_name() or '')
      if string.match(process, '[\\/]herdr%.exe$') then
        local local_app_data = os.getenv 'LOCALAPPDATA'
        wezterm.background_child_process {
          local_app_data .. '\\Programs\\herdr-fast-paste\\herdr-fast-paste.exe',
        }
      else
        window:perform_action(act.PasteFrom 'PrimarySelection', pane)
      end
    end),
  })
end

return module

