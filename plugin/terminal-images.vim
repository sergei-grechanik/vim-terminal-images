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
                \ executable('tupimage') ?
                \ 'tupimage' : (s:path . "/../tupimage-bundled.sh")
endif

" Show image under cursor in a popup window
command ShowImageUnderCursor :call ShowImageUnderCursor()
" Same thing but do not show error messages if the file is not found
command ShowImageUnderCursorIfReadable :call ShowImageUnderCursor(1)

" Upload the given image with the given size. If `cols` and `rows` are zero, the
" best size will be computed automatically. The image will be fit to width or
" height and centered.
" The result of this function is a list of lines with text properties
" representing the image (can be used with popup_create and popup_settext).
function! UploadTerminalImage(filename, cols, rows)
    " If the number of columns and rows is not provided, the script will compute
    " them automatically. We just need to limit the number of columns and rows
    " so that the image fits in the window.
    let maxcols = min([g:terminal_images_max_columns, &columns, winwidth(0) - 6])
    let maxrows = min([g:terminal_images_max_rows, &lines, winheight(0) - 2])
    let maxcols = max([1, maxcols])
    let maxrows = max([1, maxrows])
    let cols_str = a:cols ? " -c " . shellescape(string(a:cols)) : ""
    let rows_str = a:rows ? " -r " . shellescape(string(a:rows)) : ""
    let filename_expanded = resolve(expand(a:filename))
    let filename_str = shellescape(filename_expanded)
    let outfile = tempname()
    let errfile = tempname()
    let infofile = tempname()

    " We use a script to upload the file. We ask it to write lines
    " representing the image to `outfile` and disable outputting escape codes
    " for the image id (--noesc) because we assign them by ourselves using text
    " properties.
    let command = g:terminal_images_command .
                \ cols_str .
                \ rows_str .
                \ " --max-cols " . string(maxcols) .
                \ " --max-rows " . string(maxrows) .
                \ " -e " . shellescape(errfile) .
                \ " -o " . shellescape(outfile) .
                \ " --save-info " . shellescape(infofile) .
                \ " --noesc " .
                \ " --256 " .
                \ " " . filename_str .
                \ " < /dev/tty > /dev/tty"
    call system(command)
    if v:shell_error != 0
        if filereadable(errfile)
            let err_message = readfile(errfile)[0]
            call delete(errfile)
            throw "Uploading error: " . err_message
        endif
        throw "Command failed: " . command
    endif

    " Get image id from infofile.
    let id = ''
    for infoline in readfile(infofile)
        let id = matchstr(infoline, '^id[ \t]\+\zs[0-9]\+\ze$')
        if id != ''
            break
        endif
    endfor
    if id == ''
        throw "Could not read id from " . infofile
    endif
    call delete(infofile)

    " Read outfile and convert it to something suitable for floating windows.
    let lines = readfile(outfile)
    let result = []
    " We use text properties to assign each line the foreground color
    " corresponding to the image id.
    let prop_type = "TerminalImagesID" . id
    for line in lines
        call add(result,
                 \ {'text': line,
                 \  'props': [{'col': 1,
                 \             'length': len(line),
                 \             'type': prop_type}]})
    endfor
    call delete(outfile)
    return result
endfun

" Find a readable file named `filename` in some plausible directories. Display
" an error message if a file could not be found.
function! FindReadableFile(filename) abort
    let filenames = [a:filename, expand('%:p:h') . "/" . a:filename]
    if exists('b:netrw_curdir')
        call add(filenames, b:netrw_curdir . "/" . a:filename)
    endif
    let globlist = glob(expand('%:p:h') . "/**/" . a:filename, 0, 1)
    if len(globlist) == 1
        call extend(filenames, globlist)
    endif
    for filename in filenames
        if filereadable(filename)
            return filename
        endif
    endfor
    throw "File(s) not readable: " . string(filenames)
endfun

" Show the image under cursor in a popup window.
function! ShowImageUnderCursor(...) abort
    let silent = get(a:, 0, 0)
    try
        let filename = FindReadableFile(expand('<cfile>'))
    catch
        if !silent
            echohl ErrorMsg
            echo v:exception
            echohl None
        endif
        return 0
    endtry
    if !filereadable(filename)
        return
    endif
    let uploading_message = popup_atcursor("Uploading " . filename, {})
    redraw
    echo "Uploading " . filename
    try
        let text = UploadTerminalImage(filename, 0, 0)
        redraw
        echo "Showing " . filename
    catch
        call popup_close(uploading_message)
        " Vim doesn't want to redraw unless I put echo in between
        redraw!
        echo
        redraw!
        echohl ErrorMsg
        echo v:exception
        echohl None
        return
    endtry
    call popup_close(uploading_message)
    let background_higroup =
                \ get(b:, 'terminal_images_background', 'TerminalImagesBackground')
    return popup_atcursor(text,
                \ #{wrap: 0, highlight: background_higroup})
endfun

" Experimental function to show image somewhere not under cursor.
function! ShowImageSomewhere() abort
    let filename = FindReadableFile(expand('<cfile>'))
    if !filereadable(filename)
        return
    endif
    let uploading_message = popup_atcursor("Uploading " . filename, {})
    redraw
    echo "Uploading " . filename
    try
        let text = UploadTerminalImage(filename, 0, 0)
        redraw
        echo "Showing " . filename
    catch
        call popup_close(uploading_message)
        " Vim doesn't want to redraw unless I put echo in between
        redraw!
        echo
        redraw!
        echohl ErrorMsg
        echo v:exception
        echohl None
        return
    endtry
    let g:terminal_images_propid += 1
    let propid = g:terminal_images_propid
    call popup_close(uploading_message)
    call prop_type_add('TerminalImageMarker' . string(propid), {})
    call prop_add(line('.'), col('.'), #{length: 1, type: 'TerminalImageMarker' . string(propid), id: propid})
    return popup_create(text, #{line: 0, col: 10, pos: 'topleft', textprop: 'TerminalImageMarker' . string(propid), textpropid: propid, close: 'click', wrap: 0})
endfun
