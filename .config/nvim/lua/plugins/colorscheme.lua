return {
  -- GitHub Dark — same theme as Zed (`theme.dark: "GitHub Dark"`) and WezTerm
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 1000,
    -- transparent: show WezTerm's background opacity/blur through nvim
    -- floats stay solid (lazygit, pickers, popups were hard to read over the blurred background)
    opts = {
      options = { transparent = true },
      groups = {
        all = {
          NormalFloat = { bg = "bg0" },
          -- theme default fg (#161b22) is invisible on bg0; it's also lazygit's
          -- inactive border/title color (Snacks maps inactiveBorderColor → FloatBorder)
          FloatBorder = { fg = "#8b949e", bg = "bg0" },
          FloatTitle = { bg = "bg0" },
        },
      },
    },
    config = function(_, opts)
      require("github-theme").setup(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "github_dark" },
  },
}
