-- nvm で管理している node / tree-sitter-cli を nvim からも使えるようにする
do
  local nvm_dir = vim.fn.expand("$HOME/.nvm")
  local alias_file = nvm_dir .. "/alias/default"
  if vim.fn.filereadable(alias_file) == 1 then
    local version = vim.fn.readfile(alias_file)[1]
    if version then
      local node_bin = nvm_dir .. "/versions/node/" .. version .. "/bin"
      if vim.fn.isdirectory(node_bin) == 1 then
        vim.env.PATH = node_bin .. ":" .. vim.env.PATH
      end
    end
  end
end

-- Windows WSL ubuntuとWindows OSのWin+Vでのクリップボード連携設定
-- NOTE: プラグイン読み込み前に設定しないとクリップボードプロバイダーが正しく初期化されない
vim.g.clipboard = {
  name = "wsl-clipboard-win-v",
  copy = {
    -- シェルスクリプト経由で呼び出す場合、任意のパス
    ["+"] = { vim.fn.expand("$HOME") .. "/.local/bin/win-clip-copy.sh" },
    ["*"] = { vim.fn.expand("$HOME") .. "/.local/bin/win-clip-copy.sh" },
  },
  -- paste = {
  --   ["+"] = { "powershell.exe", "-NoProfile", "-Command", "Get-Clipboard" },
  --   ["*"] = { "powershell.exe", "-NoProfile", "-Command", "Get-Clipboard" },
  -- },
  paste = {
    ["+"] = { "powershell.exe", "-NoProfile", "-Command",  "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Get-Clipboard" },
    ["*"] = { "powershell.exe", "-NoProfile", "-Command",  "[Console]::OutputEncoding=[System.Text.Encoding]::UTF8; Get-Clipboard" },
  },
  cache_enabled = 0,
}
vim.o.clipboard = "unnamedplus"

-- treesitter パーサー未インストール時のエラーを防ぐ
-- (build-essential + :TSUpdate 後は通常通り動作する)
do
  local orig = vim.treesitter.start
  vim.treesitter.start = function(bufnr, lang)
    local ok, err = pcall(orig, bufnr, lang)
    if not ok then
      vim.notify("treesitter: parser not ready for " .. tostring(lang), vim.log.levels.DEBUG)
    end
  end
end

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
vim.o.shiftwidth = 2
vim.o.autoindent = true
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

-- windows設定
vim.opt.encoding = "utf-8"
vim.opt.fileencoding = "utf-8"
vim.opt.fileencodings = { "utf-8", "cp932", "sjis", "euc-jp", "iso-2022-jp" }
