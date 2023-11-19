let mapleader = "\<space>"
set shiftwidth=2
syntax=on
set showmode
set number
set tabstop=2
set incsearch
set clipboard=unnamed
set cursorline
highlight CursorLine ctermfg=Blue ctermbg=Green
set cursorcolumn
set autoindent
set expandtab
set autowrite
set laststatus=0
set list " 不可視文字を表示
"set foldmethod=indent

let @q = ';;a;'
abbr _sh #!/bin/bash

call plug#begin()
Plug 'ntk148v/vim-horizon'
Plug 'preservim/nerdtree'
Plug 'lambdalisue/fern.vim'
Plug 'nathanaelkane/vim-indent-guides'
Plug 'lambdalisue/fern-git-status.vim'
Plug 'neoclide/coc.nvim', {'branch': 'release'}
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'yuki-yano/fzf-preview.vim', { 'branch': 'release/rpc' }
Plug 'https://github.com/PhilRunninger/nerdtree-visual-selection.git'
Plug 'b4b4r07/vim-shellutils'
Plug 'https://github.com/alvan/vim-closetag.git'
Plug 'easymotion/vim-easymotion'
Plug 'preservim/nerdtree' |
            \ Plug 'Xuyuanp/nerdtree-git-plugin'
Plug 'https://github.com/posva/vim-vue.git'
Plug 'https://github.com/tyru/open-browser.vim.git'
Plug 'https://github.com/tpope/vim-commentary.git'
Plug 'https://github.com/tpope/vim-surround.git'
Plug 'https://github.com/simeji/winresizer.git'
Plug 'https://github.com/easymotion/vim-easymotion.git'
Plug 'junegunn/goyo.vim'
Plug 'https://github.com/Shougo/unite.vim.git'
Plug 'https://github.com/Shougo/neomru.vim.git'
Plug 'https://github.com/ctrlpvim/ctrlp.vim.git'
Plug 'https://github.com/vim-syntastic/syntastic'
Plug 'Shougo/vimproc.vim', {'do' : 'make'} 
Plug 'vim-test/vim-test'
Plug 'https://github.com/vim-scripts/ScrollColors'
Plug 'kyazdani42/blue-moon'
Plug 'https://github.com/AlessandroYorba/Breve.git'
Plug 'vim-jp/vimdoc-ja'
Plug 'https://github.com/leafgarland/typescript-vim.git'
Plug 'peitalin/vim-jsx-typescript'
Plug 'nvim-treesitter/nvim-treesitter', {'do': ':TSUpdate'} 
Plug 'nvim-lua/plenary.nvim'
Plug 'nvim-telescope/telescope.nvim', { 'tag': '0.1.2' }
Plug 'dense-analysis/ale'
Plug 'akinsho/toggleterm.nvim', {'tag' : '*'}
Plug 'https://github.com/lewis6991/gitsigns.nvim'
Plug 'nvim-tree/nvim-web-devicons'
call plug#end()
let g:ale_linters = {
\   'ruby': ['rubocop'],
\}
let g:ale_linters_explicit = 1
let g:airline#extensions#ale#enabled = 1

let g:ctrlp_user_command = ['.git', 'cd %s && git ls-files']
let g:typescript_indent_disable = 1
lua require("toggleterm").setup()

lua << EOF
require('gitsigns').setup {
  signs = {
    add          = { text = '+' },
    change       = { text = '│' },
    delete       = { text = '_' },
    topdelete    = { text = '‾' },
    changedelete = { text = '~' },
    untracked    = { text = '┆' },
  },
  signcolumn = true,  -- Toggle with `:Gitsigns toggle_signs`
  numhl      = false, -- Toggle with `:Gitsigns toggle_numhl`
  linehl     = false, -- Toggle with `:Gitsigns toggle_linehl`
  word_diff  = false, -- Toggle with `:Gitsigns toggle_word_diff`
  watch_gitdir = {
    follow_files = true
  },
  attach_to_untracked = true,
  current_line_blame = true, -- Toggle with `:Gitsigns toggle_current_line_blame`
  current_line_blame_opts = {
    virt_text = true,
    virt_text_pos = 'eol', -- 'eol' | 'overlay' | 'right_align'
    delay = 10,
    ignore_whitespace = false,
  },
  current_line_blame_formatter = '<author>, <author_time:%Y-%m-%d> - <summary>',
  sign_priority = 6,
  update_debounce = 100,
  status_formatter = nil, -- Use default
  max_file_length = 40000, -- Disable if file is longer than this (in lines)
  preview_config = {
    -- Options passed to nvim_open_win
    border = 'single',
    style = 'minimal',
    relative = 'cursor',
    row = 0,
    col = 1
  },
  yadm = {
    enable = false
  },
}


local map = vim.api.nvim_set_keymap
local opts = { noremap = true, silent = true }

-- Move to previous/next
map('n', 'jhsa', '<Cmd>BufferPrevious<CR>', opts)
map('n', 'jkas', '<Cmd>BufferNext<CR>', opts)
-- Re-order to previous/next
map('n', '<A-<>', '<Cmd>BufferMovePrevious<CR>', opts)
map('n', '<A->>', '<Cmd>BufferMoveNext<CR>', opts)
-- Goto buffer in position...
map('n', 'j1', '<Cmd>BufferGoto 1<CR>', opts)
map('n', 'j2', '<Cmd>BufferGoto 2<CR>', opts)
map('n', 'j3', '<Cmd>BufferGoto 3<CR>', opts)
map('n', 'j4', '<Cmd>BufferGoto 4<CR>', opts)
map('n', 'j5', '<Cmd>BufferGoto 5<CR>', opts)
map('n', 'j6', '<Cmd>BufferGoto 6<CR>', opts)
map('n', 'j7', '<Cmd>BufferGoto 7<CR>', opts)
map('n', 'j8', '<Cmd>BufferGoto 8<CR>', opts)
map('n', 'j9', '<Cmd>BufferGoto 9<CR>', opts)
map('n', 'j0', '<Cmd>BufferLast<CR>', opts)
-- Pin/unpin buffer
map('n', 'fpin', '<Cmd>BufferPin<CR>', opts)
-- Close buffer
map('n', '<A-c>', '<Cmd>BufferClose<CR>', opts)
-- Sort automatically by...
map('n', '<Space>bb', '<Cmd>BufferOrderByBufferNumber<CR>', opts)
map('n', '<Space>bd', '<Cmd>BufferOrderByDirectory<CR>', opts)
map('n', '<Space>bl', '<Cmd>BufferOrderByLanguage<CR>', opts)
map('n', '<Space>bw', '<Cmd>BufferOrderByWindowNumber<CR>', opts)

-- Other:
-- :BarbarEnable - enables barbar (enabled by default)
-- :BarbarDisable - very bad command, should never be used
EOF

inoremap { {}<LEFT>
inoremap [ []<LEFT>
inoremap ( ()<LEFT>
inoremap " ""<LEFT>
inoremap ' ''<LEFT>
inoremap jj <ESC>
nnoremap <silent> un :<C-u>Unite buffer<CR>
nnoremap <silent> buf :BufferGoto 1<CR>
nnoremap <silent> unf :<C-u>Unite file<CR>
nnoremap <silent> ufr :<C-u>Unite file_rec<CR>
nnoremap <silent> ub :<C-u>Unite bookmark<CR>
nnoremap <silent> umru :<C-u>Unite file_mru<CR>
nnoremap <silent> ur :<C-u>Unite -buffer-name=register register<CR>
nnoremap <ESC><ESC> :nohlsearch<CR>
nnoremap ctag :!ctags -R<CR>
nnoremap term :ToggleTerm direction=float<CR>
" ターミナルjobモードでのキーバインド
tnoremap <space>jj <C-\><C-n>
noremap ss ^
noremap ;; $
nmap <silent> <space>df <Plug>(coc-definition)
nnoremap <silent> <C-2> :BufferGoto 1<CR>
nnoremap <C-n> :NERDTree<CR>
nnoremap <C-t> :NERDTreeToggle<CR>
command! -nargs=0 Format :call CocAction('format')
command! Solitary :echo '人生字を識るは憂患の始まり'
command! SS :so ~/.config/nvim/init.vim
command! Svs :source ~/.vimrc
command! Co :colorscheme
command  Eve :colorscheme evening
let mapleader = "\<space>"
command! Bre :colorscheme breve
command  Horizon :colorscheme horizon
nmap <silent> <space>fmt <Plug>(coc-format)
nmap <silent> gy <Plug>(coc-type-definition)
nmap gx <Plug>(openbrowser-smart-search)
vmap gx <Plug>(openbrowser-smart-search)
nnoremap <Leader>o :<C-u>execute "OpenBrowser" "file:///" . expand('%:p:gs?\\?/?')<CR>
nnoremap fff <cmd>Telescope find_files<cr>
nnoremap fgr <cmd>Telescope live_grep<cr>
let g:indent_guides_enable_on_vim_startup = 1
let g:gitgutter_highlight_lines = 1
let g:closetag_filenames = '*.html,*.xhtml,*.phtml,*.ctp,*.php,*.vue'
set helplang=ja,en " vim help日本語化のため
set termguicolors
" colorscheme slate
" colorscheme horizon
" colorscheme hybrid
" colorscheme blue
" colorscheme evening
colorscheme blue-moon
let g:lightline = { 'colorscheme': 'blue-moon' }

" Rubyの文法チェック"
augroup rbsyntaxcheck
  autocmd!
  autocmd BufWrite *.rb w !ruby -c
augroup END

" ファイル名表示
set statusline=%F
let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
