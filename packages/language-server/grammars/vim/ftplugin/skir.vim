" Vim ftplugin for Skir
if exists("b:did_ftplugin")
  finish
endif
let b:did_ftplugin = 1

setlocal commentstring=//\ %s
setlocal comments=s1:/*,mb:*,ex:*/,://

" Connect to skir-language-server via nvim-lspconfig (Neovim):
"
"   require('lspconfig.configs').skir = {
"     default_config = {
"       cmd = { 'skir-language-server', '--stdio' },
"       filetypes = { 'skir' },
"       root_dir = require('lspconfig.util').root_pattern('skir.yml', '.git'),
"     },
"   }
"   require('lspconfig').skir.setup {}
"
" Or with vim-lsp (Vim 8+):
"
"   if executable('skir-language-server')
"     augroup LspSkir
"       autocmd!
"       autocmd User lsp_setup call lsp#register_server({
"         \ 'name': 'skir-language-server',
"         \ 'cmd': {server_info -> ['skir-language-server', '--stdio']},
"         \ 'allowlist': ['skir'],
"         \ })
"     augroup END
"   endif
