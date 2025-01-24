return {
	dependencies = {
		"rcarriga/nvim-notify",
		"nvim-lua/plenary.nvim",
	},
	config = function()
		require("pomidor").setup()
	end,
	defualt_config = {},
}
