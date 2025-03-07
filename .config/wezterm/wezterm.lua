local wezterm = require("wezterm")

return {
	font = wezterm.font("MesloLGS NF"),
	font_size = 13,

	color_scheme = "Gruvbox Dark", -- Matches Windows Terminal themes
	enable_tab_bar = true,

	default_prog = { "wsl.exe", "--cd", "~" }, -- Set default shell (change to WSL if needed)

	window_background_opacity = 0.85, -- Transparency

	window_decorations = "RESIZE",

	macos_window_background_blur = 30, -- For macOS only
	-- win32_system_backdrop = "Mica", -- Enables Windows Acrylic blur

	-- Define profiles for easy switching
	launch_menu = {
		{
			label = "Windows PowerShell",
			args = { "powershell.exe" },
		},
		{
			label = "PowerShell Core",
			args = { "pwsh.exe" },
		},
		{
			label = "WSL (Ubuntu)",
			args = { "wsl.exe", "--cd", "~" },
		},
	},
}
