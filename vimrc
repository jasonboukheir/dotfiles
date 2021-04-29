" Source all files in rc directory:
for f in split(glob('~/.vim/vimrc.d/*.vim'), '\n')
	exe 'source' f
endfor

" Put these lines at the very end of your vimrc file.

" Load all plugins now.
" Plugins need to be added to runtimepath before helptags can be generated.
packloadall
" Load all of the helptags now, after plugins have been loaded.
" All messages and errors will be ignored.
silent! helptags ALL
