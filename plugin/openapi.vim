if !has('nvim-0.5') | echom "[Octo] Octo.nvim requires neovim 0.5+" | finish | endif
if exists('g:loaded_openapi_nvim') | finish | endif


augroup openapi_nvim_autocommands
  au!
augroup END

let g:loaded_openapi_nvim = 1
