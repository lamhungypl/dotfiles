local keymap = vim.keymap

-- insert mode keys binding
keymap.set('i', 'jk', '<Esc>')
keymap.set('i', 'jj', '<Esc>')
keymap.set('i', 'ww', '<Esc>:w<CR>')
keymap.set('i', 'qq', '<Esc>:q!<CR>')

-- normal mode keys bindings
keymap.set('n', '<C-a>', 'ggVG')

-- Tab operation
keymap.set('n', 'tn', 'gt')
keymap.set('n', 'tp', 'gT')
-- whatever delete, make it go away
keymap.set('n', 'c', '"_c')
keymap.set('n', 'C', '"_C')
keymap.set('n', 'x', '"_x')
keymap.set('n', 'X', '"_X')

-- visualize mode keys bindings
keymap.set('v', 'L', '$')


-- New tab
keymap.set('n', 'te', ':tabedit')
-- Split window
keymap.set('n', 'ss', ':split<Return><C-w>w')
keymap.set('n', 'sv', ':vsplit<Return><C-w>w')
-- Move window
keymap.set('n', '<Space>', '<C-w>w')
keymap.set('', 'sh', '<C-w>h')
keymap.set('', 'sk', '<C-w>k')
keymap.set('', 'sj', '<C-w>j')
keymap.set('', 'sl', '<C-w>l')

-- Resize window
keymap.set('n', '<C-w><left>', '<C-w><')
keymap.set('n', '<C-w><right>', '<C-w>>')
keymap.set('n', '<C-w><up>', '<C-w>+')
keymap.set('n', '<C-w><down>', '<C-w>-')
