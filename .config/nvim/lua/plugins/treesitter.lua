return {
	{
		"nvim-treesitter/nvim-treesitter",
		-- opts_extend in LazyVim's spec appends to its own ensure_installed list
		opts = {
			ensure_installed = {
				"astro",
				"cmake",
				"cpp",
				"css",
				"fish",
				"gitignore",
				"go",
				"graphql",
				"http",
				"java",
				"php",
				"rust",
				"scss",
				"sql",
				"svelte",
			},
		},
		init = function()
			vim.filetype.add({ extension = { mdx = "mdx" } })
			vim.treesitter.language.register("markdown", "mdx")
		end,
	},
}
