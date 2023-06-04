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

" The maximum width and height of an image window, in cells.
let g:terminal_images_max_columns = get(g:, 'terminal_images_max_columns', 100)
let g:terminal_images_max_rows = get(g:, 'terminal_images_max_rows', 30)

let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

" The name or path of the tupimage command and default options.
if !exists('g:terminal_images_command')
    let g:terminal_images_command =
                \ s:path . "/../tupimage/tupimage"
                " \ . " --less-diacritics"
endif

if !exists('g:terminal_images_subdir_glob')
    let g:terminal_images_subdir_glob = '*'
endif

" A regexp matching image file names. May be overridden by the buffer variable.
if !exists('g:terminal_images_regex')
    let g:terminal_images_regex = '\c\([a-z0-9_+=/$%-]\+\.\(png\|jpe\?g\|gif\)\)'
endif

" Try not to position images closer than this num of columns to the right edge.
if !exists('g:terminal_images_right_margin')
    let g:terminal_images_right_margin = 1
endif

" Try not to position images closer than this num of columns to the left edge
" (only for automatic positioning). If the value of this variable is
" 'textwidth', textwidth + 1 will be used. If the value is 'auto', it will be
" computed as the max line width displayed on the screen (but not higher than
" textwidth + 1).
if !exists('g:terminal_images_left_margin')
    let g:terminal_images_left_margin = 0
endif

if !exists('g:terminal_images_auto')
    let g:terminal_images_auto = 1
endif

if !exists('g:terminal_images_auto_show_current')
    let g:terminal_images_auto_show_current = 1
endif

let g:terminal_images_pending_uploads = []
let g:terminal_images_cache = {}


" Show image under cursor in a popup window
command TerminalImagesShowUnderCursor :call terminal_images#ShowImageUnderCursor()
" Same thing but do not show error messages if the file is not found
command TerminalImagesShowUnderCursorIfReadable :call terminal_images#ShowImageUnderCursor(1)

" Enable/Disable/Toggle automatic image display on cursor hold.
command TerminalImagesToggle :call terminal_images#ToggleGlobal()
command TerminalImagesEnable :call terminal_images#EnableGlobal()
command TerminalImagesDisable :call terminal_images#DisableGlobal()
command TerminalImagesEnableBuffer :call terminal_images#EnableBuffer()
command TerminalImagesDisableBuffer :call terminal_images#DisableBuffer()
command TerminalImagesUnletBuffer :call terminal_images#ClearBufferEnableSettings()
" Show the current buffer if it's an image.
command TerminalImagesShowCurrent :call terminal_images#ShowCurrentFile({})
" Show all images found in the current window.
command TerminalImagesShowAll :call terminal_images#ShowAllImages({})
" Show all images and force reuploading all of them. Useful when you think that
" some of the images are broken.
command TerminalImagesShowAllForceReupload :call terminal_images#ShowAllImagesForceReupload()
" Clear all images in the current window.
command TerminalImagesClear :call terminal_images#ClearVisibleImages() | redraw!
" Upload images that are pending upload.
command TerminalImagesUploadPending :call terminal_images#UploadPendingImages({})
" Close images that may obscure other windows.
command TerminalImagesCloseObscuring :call terminal_images#CloseObscuringImages()

augroup TerminalImagesAugroup
    autocmd!
    autocmd WinLeave,VimResized * :call terminal_images#CloseObscuringImages()
    autocmd CursorHold,BufWinEnter * :call terminal_images#ShowAllMaybe()
    autocmd BufWinEnter * :call terminal_images#ShowCurrentMaybe()
augroup end
