return {
	dependencies = {
		"rcarriga/nvim-notify",
		"nvim-lua/plenary.nvim",
	},
	config = function()
		require("pomidor").setup()
	end,
	default_config = {},
}
