" Prevent loading the plugin multiple times
if exists('g:loaded_terminal_images_plugin')
    finish
endif
let g:loaded_terminal_images_plugin = 1

" Highlight group used for floating window background. The background can also
" be controlled in per-buffer manner by setting `b:terminal_images_background`.
if !hlexists('TerminalImagesBackground')
    highlight link TerminalImagesBackground Pmenu
endif

" Highlighting groups TerminalImagesID1..TerminalImagesID255 are used for the
" corresponding image IDs.
for i in range(1, 255)
    let higroup_name = "TerminalImagesID" . string(i)
    execute "hi " . higroup_name . " ctermfg=" . string(i)
    let prop_name = "TerminalImagesID" . string(i)
    if !empty(prop_type_get(prop_name))
        call prop_type_delete(prop_name)
    endif
    call prop_type_add(prop_name, {'highlight': higroup_name})
endfor

let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

let g:terminal_images_max_columns = get(g:, 'terminal_images_max_columns', 100)
let g:terminal_images_max_rows = get(g:, 'terminal_images_max_rows', 30)

if !exists('g:terminal_images_command')
    let g:terminal_images_command =
                \ s:path . "/../tupimage/tupimage"
                " \ . " --less-diacritics"
endif

if !exists('g:terminal_images_regex')
    let g:terminal_images_regex = '\c\([a-z0-9_+=/$%-]\+\.\(png\|jpe\?g\|gif\)\)'
endif

let g:terminal_images_pending_uploads = []
let g:terminal_images_cache = {}

" Show image under cursor in a popup window
command TerminalImagesShowUnderCursor :call terminal_images#ShowImageUnderCursor()
" Same thing but do not show error messages if the file is not found
command ShowImageUnderCursorIfReadable :call terminal_images#ShowImageUnderCursor(1)

command TerminalImagesCloseObscuring :call terminal_images#CloseObscuringImages()
command TerminalImagesShowAll :call terminal_images#ShowAllImages()

augroup TerminalImagesAugroup
    autocmd!
    autocmd WinLeave,VimResized * :TerminalImagesCloseObscuring
    autocmd CursorHold * :TerminalImagesShowAll
augroup end
