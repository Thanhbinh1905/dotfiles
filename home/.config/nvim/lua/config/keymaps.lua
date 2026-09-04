local map = vim.keymap.set

map("n", "<leader>tt", "<cmd>terminal<cr>", { desc = "Terminal" })
map("t", "<esc><esc>", "<c-\\><c-n>", { desc = "Exit terminal mode" })
