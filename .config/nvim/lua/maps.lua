local keymap = vim.keymap

-- insert mode keys bindings
keymap.set('i', 'jk' , '<Esc>')
keymap.set('i', 'ww', '<Esc>:w<CR>')
keymap.set('i', 'qq', '<Esc>:q!<CR>')
