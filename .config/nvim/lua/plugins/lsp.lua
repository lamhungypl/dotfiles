return {
	-- tools
	{
		"mason-org/mason.nvim",
		opts = {
			ensure_installed = {
				"stylua",
				"selene",
				"luacheck",
				"shellcheck",
				"shfmt",
				"css-lsp",
			},
		},
	},

	-- lsp servers (configured through native `vim.lsp.config` by LazyVim)
	-- TypeScript: vtsls from the `lang.typescript` extra (its defaults already match Zed:
	-- parameter-name inlay hints for literals, update imports on file move).
	-- ESLint fix-on-save: handled by the `linting.eslint` extra.
	{
		"neovim/nvim-lspconfig",
		opts = {
			inlay_hints = { enabled = true },
			servers = {
				-- inlay hints like VSCode: only parameter names for literal arguments
				-- (no return / parameter / property / variable types — use K to see a type)
				vtsls = {
					settings = {
						typescript = {
							inlayHints = {
								parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
								functionLikeReturnTypes = { enabled = false },
								parameterTypes = { enabled = false },
								propertyDeclarationTypes = { enabled = false },
								variableTypes = { enabled = false },
								enumMemberValues = { enabled = false },
							},
						},
						javascript = {
							inlayHints = {
								parameterNames = { enabled = "literals", suppressWhenArgumentMatchesName = true },
								functionLikeReturnTypes = { enabled = false },
								parameterTypes = { enabled = false },
								propertyDeclarationTypes = { enabled = false },
								variableTypes = { enabled = false },
								enumMemberValues = { enabled = false },
							},
						},
					},
				},
				cssls = {},
				html = {},
				-- same as Zed / VSCode: classes inside cva / cx / cn
				tailwindcss = {
					settings = {
						tailwindCSS = {
							classAttributes = { "class", "className", "ngClass", "classes" },
							classFunctions = { "cva", "cx" },
							experimental = {
								classRegex = {
									{ "cva\\(([^)]*)\\)", "[\"'`]([^\"'`]*).*?[\"'`]" },
									{ "cx\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
									{ "cn\\(([^)]*)\\)", "(?:'|\"|`)([^']*)(?:'|\"|`)" },
								},
							},
						},
					},
				},
				yamlls = {
					settings = {
						yaml = {
							keyOrdering = false,
						},
					},
				},
				lua_ls = {
					settings = {
						Lua = {
							workspace = {
								checkThirdParty = false,
							},
							completion = {
								workspaceWord = true,
								callSnippet = "Both",
							},
							hint = {
								enable = true,
								setType = false,
								paramType = true,
								paramName = "Disable",
								semicolon = "Disable",
								arrayIndex = "Disable",
							},
							doc = {
								privateName = { "^_" },
							},
							type = {
								castNumberToInteger = true,
							},
							diagnostics = {
								disable = { "incomplete-signature-doc", "trailing-space" },
								groupSeverity = {
									strong = "Warning",
									strict = "Warning",
								},
								groupFileStatus = {
									["ambiguity"] = "Opened",
									["await"] = "Opened",
									["codestyle"] = "None",
									["duplicate"] = "Opened",
									["global"] = "Opened",
									["luadoc"] = "Opened",
									["redefined"] = "Opened",
									["strict"] = "Opened",
									["strong"] = "Opened",
									["type-check"] = "Opened",
									["unbalanced"] = "Opened",
									["unused"] = "Opened",
								},
								unusedLocalExclude = { "_*" },
							},
							format = {
								enable = false,
							},
						},
					},
				},
			},
		},
	},
}
