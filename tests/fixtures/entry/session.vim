" A stand-in for a session file, which the entry suites restore with `-S` or
" through a stand-in session plugin: written for these tests, not by
" `:mksession`. It marks that it ran and, as a file `:mksession` writes does,
" sets `v:this_session` to its own path.
let g:entry_session = 1
let v:this_session = expand('<sfile>:p')
