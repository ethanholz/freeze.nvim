.PHONY: lint style-lint lint-all

lint:
	@printf "\nRunning selene\n"
	@selene --display-style quiet lua/freeze

style-lint:
	@printf "\nRunning stylua\n"
	@stylua --color always --check .

lint-all: lint style-lint

format:
	@printf "\nFormatting with stylua\n"
	@stylua --color always .