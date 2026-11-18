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
				-- query-only bases: typescript/javascript/tsx/html/php `; inherits:` these, and
				-- nvim-treesitter (main) doesn't pull them in, so without them TS/JS lose most highlights
				"ecma",
				"html_tags",
				"jsx",
				"php_only",
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
