" Minimal, broadly compatible Neovim config
set nocompatible
syntax on
set number
set hidden
set ruler
set backspace=indent,eol,start
set tabstop=4 shiftwidth=4 expandtab
set undofile
set ignorecase smartcase
set incsearch hlsearch

" Colors: use defaults if no theme available
if &t_Co > 2 || has("gui_running")
  set background=dark
endif

" Neovim-specific settings
if has('nvim')
  set inccommand=nosplit
endif