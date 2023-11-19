local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"

if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git",
    "clone",
    "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", -- latest stable release
    lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

require('lazy').setup {
  {'preservim/nerdtree'},
	{'Xuyuanp/nerdtree-git-plugin'},
  {'ctrlpvim/ctrlp.vim'},
  {'akinsho/toggleterm.nvim'},
  {'lukas-reineke/indent-blankline.nvim', main = "ibl", opts = {} },
	{'akinsho/bufferline.nvim', version = "*", dependencies = 'nvim-tree/nvim-web-devicons'},
  {"nvim-treesitter/nvim-treesitter", 
	  build = ":TSUpdate",
		config = function ()
      local configs = require("nvim-treesitter.configs")
      configs.setup({
          ensure_installed = { "c", "lua", "vim", "vimdoc", "ruby", "python", "typescript", "tsx", "query", "elixir", "heex", "javascript", "html", "css", "vue" },
          sync_install = false,
          highlight = { enable = true },
          indent = { enable = true },
        })
    end
	},
  {'lewis6991/gitsigns.nvim',
    config = function()
      require('settings/gitsigns')
    end
  },
  {'neoclide/coc.nvim',
    branch = 'release'
  },
  {'thinca/vim-scouter'},
  {"EdenEast/nightfox.nvim"},
  {'nvim-lualine/lualine.nvim'},
  {'norcalli/nvim-colorizer.lua'},
  {'nvim-telescope/telescope.nvim'},
  {'nvim-lua/plenary.nvim'},
  {'simeji/winresizer'},
  {'tpope/vim-commentary'},
  {'Shougo/unite.vim'},
  {'vim-scripts/ScrollColors'},
  {'tyru/open-browser.vim'},
}
