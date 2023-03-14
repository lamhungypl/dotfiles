local status, n = pcall(require, "github-theme")
if (not status) then
  print('theme module not installed')
  return
end

if vim.g.vscode then
  print('vscode extension after')
else
  n.setup({
    theme_style = 'dark_colorblind'
  })
end
