require("plugins")
require("keymaps")
require("toggleterm").setup()
require("ibl").setup()
require('lualine').setup()
vim.o.termguicolors = true --nvim-colorizer対策 https://www.reddit.com/r/neovim/comments/qoy419/termguicolors_error/?rdt=58132
require('colorizer').setup() -- https://github.com/norcalli/nvim-colorizer.lua
require("bufferline").setup{} -- termguicolorsの設定が必要

vim.api.nvim_set_var('mapleader', '\\')
vim.o.number = true
vim.o.cursorline = true
vim.o.cursorcolumn = true
vim.o.clipboard = 'unnamed'
vim.o.shiftwidth = 2
vim.o.autoident = true
vim.o.tabstop = 2
vim.o.expandtab = true
vim.o.list = true

-- 下記の２つがなくても表示されている
-- vim.o.laststatus = 2
-- vim.o.statusline = "%F"

vim.api.nvim_command('abbr _sh #!/bin/bash') -- 短縮入力 _shで#!/bin/bashを補完する
vim.cmd [[ let @q = '0i// ' ]] -- ts,vueファイルコメントアウト用の並列マクロ
vim.cmd [[ colorscheme habamax ]]
vim.cmd[[
augroup rbsyntaxcheck
  autocmd!
  autocmd BufWrite *.rb w !ruby -c
augroup END
]]

-- command! SS :so ~/.config/nvim/init.vim
vim.api.nvim_create_user_command('SS', 'so ~/.config/nvim/init.lua', { nargs = 0 })
vim.api.nvim_create_user_command('Pwd', 'pwd', { nargs = 0 })

