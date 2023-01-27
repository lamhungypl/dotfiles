local keymap = vim.keymap

-- insert mode keys binding
keymap.set('i', 'jk' , '<Esc>')
keymap.set('i', 'ww', '<Esc>:w<CR>')
keymap.set('i', 'qq', '<Esc>:q!<CR>')

-- normal mode keys bindings
keymap.set('n', '<C-a>', 'ggVG')


-- visualize mode keys bindings
keymap.set('v', 'L', '$')
