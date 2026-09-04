vim.opt.clipboard = "unnamedplus"
vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.wrap = false
vim.opt.smoothscroll = false
vim.opt.scrolloff = 8
vim.opt.sidescrolloff = 8
vim.opt.confirm = true

if vim.fn.executable("zsh") == 1 then
  vim.opt.shell = "zsh"
end
