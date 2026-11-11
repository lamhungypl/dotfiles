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

	-- `gd` like VSCode/Zed: on the declaration itself, the only definition is the cursor
	-- position (telescope "jumps" in place, nothing visible) → list the usages instead.
	-- Appended in an opts function: a `keys` list in an opts table would replace LazyVim's.
	{
		"neovim/nvim-lspconfig",
		opts = function(_, opts)
			local function definition_or_references()
				local buf = vim.api.nvim_get_current_buf()
				local uri = vim.uri_from_bufnr(buf)
				local line = vim.api.nvim_win_get_cursor(0)[1] - 1
				vim.lsp.buf_request_all(buf, "textDocument/definition", function(client)
					return vim.lsp.util.make_position_params(0, client.offset_encoding)
				end, function(results)
					local on_declaration = true
					for _, res in pairs(results) do
						local locs = res.result or {}
						if locs.uri or locs.targetUri then
							locs = { locs }
						end
						for _, loc in ipairs(locs) do
							local range = loc.targetSelectionRange or loc.range
							if (loc.uri or loc.targetUri) ~= uri or range.start.line ~= line then
								on_declaration = false
							end
						end
					end
					vim.schedule(function()
						local builtin = require("telescope.builtin")
						if on_declaration then
							builtin.lsp_references({ include_declaration = false, show_line = true })
						else
							builtin.lsp_definitions({ reuse_win = true })
						end
					end)
				end)
			end

			opts.servers = opts.servers or {}
			opts.servers["*"] = opts.servers["*"] or {}
			opts.servers["*"].keys = opts.servers["*"].keys or {}
			table.insert(opts.servers["*"].keys, {
				"gd",
				definition_or_references,
				desc = "Goto Definition (references when on it)",
				has = "definition",
			})
		end,
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
