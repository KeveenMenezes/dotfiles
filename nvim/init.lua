-- bootstrap lazy.nvim, LazyVim and your plugins
require("config.lazy")

vim.env.PATH = "/opt/homebrew/opt/mysql-client/bin:" .. vim.env.PATH

vim.opt.expandtab = true
vim.opt.tabstop = 4
vim.opt.softtabstop = 4
vim.opt.shiftwidth = 4
vim.opt.clipboard = "unnamedplus"
vim.opt.shell = "/opt/homebrew/bin/nu"
vim.opt.shellcmdflag = "-c"
vim.opt.shellquote = ""
vim.opt.shellxquote = ""
vim.opt.shellredir = "out+err> %s"
vim.opt.shellpipe = "out+err| tee %s"

vim.keymap.set("t", "<C-q>", [[<C-\><C-n>]], { silent = true })

require("config.autocmds")
require("config.keymaps")
