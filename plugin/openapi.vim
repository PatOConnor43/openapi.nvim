if !has('nvim-0.5') | echom "[Octo] Octo.nvim requires neovim 0.5+" | finish | endif
if exists('g:loaded_openapi_nvim') | finish | endif

command! OpenApiPathsLoclist lua require"openapi".paths_loclist()
command! OpenApiNewOperation lua require"openapi".add_new_operation()
command! OpenApiNewPath lua require"openapi".add_new_path()


augroup openapi_nvim_autocommands
  au!
augroup END

let g:loaded_openapi_nvim = 1
