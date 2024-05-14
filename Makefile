.PHONY: test test-nvim test-all

test:
	@printf "\nRunning vusted tests\n"
	@vusted ./tests

test-nvim:
	@printf "\nRunning plenary tests\n"
	@nvim --headless --noplugin -u tests/minimal_init.lua -c "PlenaryBustedDirectory tests/freeze {minimal_init = 'tests/minimal_init.lua'}"

test-all: test test-nvim
