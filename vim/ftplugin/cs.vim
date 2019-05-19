set tabstop=4
set shiftwidth=4
set softtabstop=4
set noexpandtab
set autoindent

:if !exists("autocommands_loaded")
:  let autocommands_loaded = 1
:  au BufWriteCmd *.cs :OmniSharpCodeFormat
:endif

