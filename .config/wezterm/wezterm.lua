local wezterm = require("wezterm")
local is_windows = wezterm.target_triple:find("windows") ~= nil

local config = {
	-- Same font / theme as Zed terminal (MesloLGS NF 12, line_height "standard" = 1.3, GitHub Dark)
	font = wezterm.font("MesloLGS NF"),
	font_size = 12,
	line_height = 1.3,
	color_scheme = "GitHub Dark",

	enable_tab_bar = true,
	window_decorations = "RESIZE",

	window_background_opacity = 0.85,
	macos_window_background_blur = 30, -- costs GPU every frame; lower/remove if rendering feels laggy
	max_fps = 120,
}

if is_windows then
	config.default_prog = { "wsl.exe", "--cd", "~" }
	config.launch_menu = {
		{ label = "Windows PowerShell", args = { "powershell.exe" } },
		{ label = "PowerShell Core", args = { "pwsh.exe" } },
		{ label = "WSL (Ubuntu)", args = { "wsl.exe", "--cd", "~" } },
	}
end

return config
