return {
  -- GitHub Dark — same theme as Zed (`theme.dark: "GitHub Dark"`) and WezTerm
  {
    "projekt0n/github-nvim-theme",
    name = "github-theme",
    lazy = false,
    priority = 1000,
    -- transparent: show WezTerm's background opacity/blur through nvim
    opts = { options = { transparent = true } },
    config = function(_, opts)
      require("github-theme").setup(opts)
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "github_dark" },
  },
}
