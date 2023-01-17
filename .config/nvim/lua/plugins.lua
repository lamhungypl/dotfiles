local status , packer = pcall(require,'packer')
if (not status) then 
  print ('Packer is not installed')
  return 
end


vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  use 'wbthomason/packer.nvim'
  use 'nvim-lualine/lualine.nvim' --Statusline
  use 'hrsh7th/nvim-cmp' -- Completion
end)
