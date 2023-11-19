local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }
map('i', 'jj', '<ESC>', opts)
map('n', '<C-t>', ':NERDTreeToggle<CR>', opts)
map('', 'ss', '^', opts)
map('', ';;', '$', opts)
map('n', 'un', ':<C-u>Unite buffer<CR>', opts)
map('n', '<leader>t', ':<cmd>Telescope find_files<CR>', opts)
map('n', 'fgr', ':<cmd>Telescope live_grep<CR>', opts)
map('n', 'term', ':ToggleTerm direction=float<CR>', opts)
map('t', '<space>jj', '<C-\\><C-n>', opts)
map('', 'gx', '<Plug>(openbrowser-smart-search)', opts)
map('i', '(', '()<LEFT>', opts)
map('i', '[', '[]<LEFT>', opts)
map('i', '{', '{}<LEFT>', opts)
-- 参考記事 https://densan-labs.net/tech/lua/chapter2.html
map('i', "\'", "\'\'<LEFT>", opts) --luaのエスケープパターン1 "\"
map('i', [["]], [[""<LEFT>]], opts) --luaのエスケープパターン2 [[]]

-- bufferline.nvim
map('n', '<leader>1', '<Cmd>BufferLineGoToBuffer 1<CR>', opts)
map('n', '<leader>2', '<Cmd>BufferLineGoToBuffer 2<CR>', opts)
map('n', '<leader>3', '<Cmd>BufferLineGoToBuffer 3<CR>', opts)
map('n', '<leader>4', '<Cmd>BufferLineGoToBuffer 4<CR>', opts)
map('n', '<leader>5', '<Cmd>BufferLineGoToBuffer 5<CR>', opts)
map('n', '<leader>6', '<Cmd>BufferLineGoToBuffer 6<CR>', opts)
map('n', '<leader>7', '<Cmd>BufferLineGoToBuffer 7<CR>', opts)
map('n', '<leader>8', '<Cmd>BufferLineGoToBuffer 8<CR>', opts)
map('n', '<leader>9', '<Cmd>BufferLineGoToBuffer 9<CR>', opts)
map('n', '<leader>$', '<Cmd>BufferLineGoToBuffer -1<CR>', opts)
map('n', "gt", "<Cmd>BufferLineCycleNext<CR>", opts)
map('n', "gT", "<Cmd>BufferLineCyclePrev<CR>", opts)
