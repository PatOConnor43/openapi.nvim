fmt:
	stylua lua/

test:
	nvim --headless --clean \
	-u lua/spec/minimal.vim \
	-c "PlenaryBustedDirectory lua/spec {minimal_init = 'lua/spec/minimal.vim'}"
