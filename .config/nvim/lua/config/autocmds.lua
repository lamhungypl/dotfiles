-- Disable the concealing in some file formats
-- The default conceallevel is 3 in LazyVim
vim.api.nvim_create_autocmd("FileType", {
	pattern = { "json", "jsonc", "markdown", "lua" },
	callback = function()
		vim.opt.conceallevel = 0
	end,
})

-- Like Zed `autosave: on_focus_change`: save when leaving a buffer or the app
vim.api.nvim_create_autocmd({ "FocusLost", "BufLeave" }, {
  callback = function(args)
    local bo = vim.bo[args.buf]
    if bo.modified and bo.modifiable and not bo.readonly and bo.buftype == "" and vim.api.nvim_buf_get_name(args.buf) ~= "" then
      vim.api.nvim_buf_call(args.buf, function()
        vim.cmd("silent! update")
      end)
    end
  end,
})
