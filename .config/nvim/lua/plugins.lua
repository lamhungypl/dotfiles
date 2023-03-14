local status, packer = pcall(require, 'packer')
if (not status) then
  print('Packer is not installed')
  return
end


vim.cmd [[packadd packer.nvim]]

packer.startup(function(use)
  -- Packer manage itself
  use 'wbthomason/packer.nvim'

  -- plugin list

  use {
    'nvim-lualine/lualine.nvim', -- statusline
    require = { 'kyazdani42/nvim-web-devicons', opt = true }
  }
  use 'nvim-lua/plenary.nvim' -- Common utilities
  use 'onsails/lspkind-nvim' -- vscode-like pictograms
  use 'L3MON4D3/LuaSnip'
  use 'hrsh7th/cmp-nvim-lsp' -- nvim-cmp source for neovim's built-in LSP
  use 'hrsh7th/cmp-buffer' -- nvim-cmp source for buffer words
  use 'hrsh7th/nvim-cmp' -- code completition
  use 'tpope/vim-surround' -- tag
  use 'tpope/vim-commentary' -- comment
  use {
    'nvim-treesitter/nvim-treesitter', -- syntax hightlight
    run = function()
      local ts_update = require('nvim-treesitter.install').update({ with_sync = true })
      ts_update()
    end,
  }
  use {
    'projekt0n/github-nvim-theme', tag = 'v0.0.7'
  }
  use 'neovim/nvim-lspconfig' -- language server potocol
  use 'windwp/nvim-autopairs' -- auto pairs
  use 'windwp/nvim-ts-autotag' -- auto tag
  use 'nvim-telescope/telescope.nvim' -- fuzzy finder
  use 'nvim-telescope/telescope-file-browser.nvim' -- file filter
  use 'glepnir/lspsaga.nvim' -- LSP UIs
  use 'jose-elias-alvarez/null-ls.nvim' -- code actions
  use 'MunifTanjim/prettier.nvim'
  use 'williamboman/mason.nvim' -- LSP support for specific lib
  use 'williamboman/mason-lspconfig.nvim'
end)
