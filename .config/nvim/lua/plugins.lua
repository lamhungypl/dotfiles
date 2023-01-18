local status , packer = pcall(require,'packer')
if (not status) then 
  print ('Packer is not installed')
  return 
end


vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  use 'wbthomason/packer.nvim'
  --Statusline
  use 'nvim-lualine/lualine.nvim' 
  --Completion
  use 'hrsh7th/nvim-cmp' 
  use 'tpope/vim-surround'
  use 'tpope/vim-commentary'
end)
