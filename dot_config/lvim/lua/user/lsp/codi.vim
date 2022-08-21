" g:codi#aliases
"              A dictionary of user-defined interpreter filetype aliases.
"              This allows you to use an interpreter for more than one
"              filetype. For example, you can alias "javascript.jsx" to
"              "javascript" so the JavaScript interpreter (node) can be used
"              for the "javascript.jsx" filetype.
" >
"              let g:codi#aliases = {
"                    \ 'javascript.jsx': 'javascript',
"                    \ }

let g:codi#aliases = {
                   \ 'javascript.jsx': 'javascript',
                   \ 'js': 'javascript',
                   \ }

" let g:codi#rightsplit = 0
" let g:codi#rightalign = 0
