local discipline = require("craftzdog.discipline")

discipline.cowboy()

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

keymap.set("n", "x", '"_x')

-- Increment/decrement
keymap.set("n", "+", "<C-a>")
keymap.set("n", "-", "<C-x>")

-- Delete a word backwards
keymap.set("n", "dw", 'vb"_d')

-- Select all
keymap.set("n", "<C-a>", "gg<S-v>G")

-- Save with root permission (not working for now)
--vim.api.nvim_create_user_command('W', 'w !sudo tee > /dev/null %', {})

-- Disable continuations
keymap.set("n", "<Leader>o", "o<Esc>^Da", opts)
keymap.set("n", "<Leader>O", "O<Esc>^Da", opts)

-- Jumplist
keymap.set("n", "<C-m>", "<C-i>", opts)

-- New tab
keymap.set("n", "te", ":tabedit")
keymap.set("n", "<tab>", ":tabnext<Return>", opts)
keymap.set("n", "<s-tab>", ":tabprev<Return>", opts)
-- Split window
keymap.set("n", "ss", ":split<Return>", opts)
keymap.set("n", "sv", ":vsplit<Return>", opts)
-- Move window
keymap.set("n", "sh", "<C-w>h")
keymap.set("n", "sk", "<C-w>k")
keymap.set("n", "sj", "<C-w>j")
keymap.set("n", "sl", "<C-w>l")

-- Resize window
keymap.set("n", "<C-w><left>", "<C-w><")
keymap.set("n", "<C-w><right>", "<C-w>>")
keymap.set("n", "<C-w><up>", "<C-w>+")
keymap.set("n", "<C-w><down>", "<C-w>-")

keymap.set("i", "jj", "<Esc>")
keymap.set("i", "jk", "<Esc>")

-- Diagnostics
keymap.set("n", "<C-j>", function()
  vim.diagnostic.goto_next()
end, opts)

keymap.set("n", "<leader>r", function()
  require("craftzdog.utils").replaceHexWithHSL()
end)

keymap.set("n", ";e", function()
  local state = require("neo-tree.sources.manager").get_state("filesystem")
  if state and state.winid and vim.api.nvim_get_current_win() == state.winid then
    -- If inside Neo-tree, move focus back to editor
    vim.cmd("wincmd p")
  else
    -- Otherwise, open Neo-tree and focus on the current file
    vim.cmd("Neotree reveal filesystem")
  end
end, { desc = "Open File Explorer Neotree" })
keymap.set("n", "<C-b>", "<cmd>Neotree toggle<CR>", { noremap = true, silent = true, desc = "Toggle Neo-tree" })

keymap.set("n", ";d", "<cmd>BufferLineCloseOthers<CR>", { desc = "Close other buffers" })
keymap.set("n", "tn", "<cmd>BufferLineCycleNext<CR>", { desc = "Next Buffer" })
keymap.set("n", "tp", "<cmd>BufferLineCyclePrev<CR>", { desc = "Previous Buffer" })
keymap.set("n", ";w", "<cmd>w<CR>", { desc = "Save File" })
keymap.set("n", "H", "<C-u>", { desc = "Jump to top", noremap = true, silent = true })
keymap.set("n", "L", "<C-d>", { desc = "Jump to bottom", noremap = true, silent = true })
keymap.set("n", "gh", vim.lsp.buf.hover, { noremap = true, silent = true, desc = "LSP Hover" })
