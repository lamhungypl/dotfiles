local status , packer = pcall(require,'packer')
if (not status) then 
  print ('Packer is not installed')
  return 
end


vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  -- Packer manage itself
  use 'wbthomason/packer.nvim'
  
  -- Statusline
  use {
  'nvim-lualine/lualine.nvim',
  require = { 'kyazdani42/nvim-web-devicons', opt = true}
  }
  
  -- Code completition
  use 'hrsh7th/nvim-cmp' 
  
  -- Tag
  use 'tpope/vim-surround'
  
  -- Comment
  use 'tpope/vim-commentary'
  
  -- Syntax Hightlight
  use {
    'nvim-treesitter/nvim-treesitter',
    run = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
  }
  
  -- Color theme
  use 'navarasu/onedark.nvim'
end)
