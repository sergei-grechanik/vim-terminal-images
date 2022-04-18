" Prevent loading the plugin multiple times
if exists('g:loaded_terminal_images_plugin')
    finish
endif
let g:loaded_terminal_images_plugin = 1

" Highlighting groups TerminalImagesLine0..TerminalImagesLine255 are used for the
" corresponding image lines.
for i in range(0, 255)
    let higroup_name = "TerminalImagesLine" . string(i)
    execute "hi " . higroup_name . " ctermfg=" . string(i)
    let prop_name = "TerminalImagesLine" . string(i)
    if !empty(prop_type_get(prop_name))
        call prop_type_delete(prop_name)
    endif
    call prop_type_add(prop_name, {'highlight': higroup_name})
endfor

let s:path = fnamemodify(resolve(expand('<sfile>:p')), ':h')

let g:terminal_images_max_columns = get(g:, 'terminal_images_max_columns', 100)
let g:terminal_images_max_rows = get(g:, 'terminal_images_max_rows', 30)
let g:terminal_images_command =
    \ get(g:, 'terminal_images_command',
        \ s:path . "/../../upload-terminal-image.sh")

" Show image under cursor in a popup window
command ShowImageUnderCursor :call ShowImageUnderCursor()
" Same thing but do not show error messages if the file is not found
command ShowImageUnderCursorIfReadable :call ShowImageUnderCursor(1)

function! ComputeBestImageSize(filename)
    let maxcols = min([g:terminal_images_max_columns, &columns, winwidth(0) - 6])
    let maxrows = min([g:terminal_images_max_rows, &lines, winheight(0) - 2])
    let maxcols = max([g:terminal_images_min_columns, maxcols])
    let maxrows = max([g:terminal_images_min_rows, maxrows])
    let filename_expanded = resolve(expand(a:filename))
    let filename_str = shellescape(filename_expanded)
    let res = system("identify -format '%w %h %x %y'-units PixelsPerInch " . filename_str)
    if res == ""
        return [maxcols, maxrows]
    endif
    let whxy = split(res, ' ')
    let w = str2float(whxy[0])/str2float(whxy[2])
    let h = str2float(whxy[1])/str2float(whxy[3])
    let w = w * g:terminal_images_columns_per_inch
    let h = h * g:terminal_images_rows_per_inch
    if w > maxcols
        let h = h * maxcols / w
        let w = maxcols
    endif
    if h > maxrows
        let w = w * maxrows / h
        let h = maxrows
    endif
    return [max([g:terminal_images_min_columns, float2nr(w)]),
           \ max([g:terminal_images_min_rows, float2nr(h)])]
endfun

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
    let tmpfile = tempname()
    " We use a bash script to upload the file. We ask it to write lines
    " representing the image to `tmpfile` and disable outputting escape codes
    " for line numbers (--noesc) because we assign them by ourselves using text
    " properties.
    let command = g:terminal_images_command .
                \ cols_str .
                \ rows_str .
                \ " --max-cols " . string(maxcols) .
                \ " --max-rows " . string(maxrows) .
                \ " -e " . shellescape(tmpfile) .
                \ " -o " . shellescape(tmpfile) .
                \ " --noesc " .
                \ " " . filename_str .
                \ " < /dev/tty > /dev/tty"
    call system(command)
    if v:shell_error != 0
        if filereadable(tmpfile)
            let err_message = readfile(tmpfile)[0]
            call delete(tmpfile)
            throw "Uploading error: " . err_message
        endif
        throw "Command failed: " . command
    endif
    let lines = readfile(tmpfile)
    let result = []
    let i = 0
    for line in lines
        " We use text properties to assign each line the foreground color
        " corresponding to the row number.
        let prop_type = "TerminalImagesLine" . string(i)
        call add(result,
                 \ {'text': line,
                 \  'props': [{'col': 1,
                 \             'length': len(line),
                 \             'type': prop_type}]})
        let i += 1
    endfor
    call delete(tmpfile)
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
    return popup_atcursor(text, #{wrap: 0})
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
