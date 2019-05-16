syntax on

" Enable folding
set foldmethod=indent
set foldlevel=99

" Enable folding using spacebar
nnoremap <space> za

" Set wildcard ignores
set wildignore+=*.pyc,*.o,*.obj,*.svn,*.swp,*.class,*.hg,*.DS_Store,*.min.*,*.meta

" better placement of swp files
set backupdir=/tmp//
set directory=/tmp//
set undodir=/tmp//

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
