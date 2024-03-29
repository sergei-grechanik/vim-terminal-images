# vim-terminal-images

Preview images in floating windows using the [tupimage
utility](https://github.com/sergei-grechanik/tupimage). You'll need a terminal
supporting the kitty graphics protocol with the unicode placeholder extension,
which are currently:
- [this fork of Kitty](https://github.com/sergei-grechanik/kitty/tree/unicode-placeholders)
- [this fork of st](https://github.com/sergei-grechanik/st/tree/graphics)

Very experimental.
Doesn't support nvim (yet).

![screenshot](https://user-images.githubusercontent.com/1084979/187103012-0e71333a-2c60-4f8d-8915-9dfa086686b6.png)

## Installation

As usual, use your favourite plugin manager, e.g.

    Plug 'sergei-grechanik/vim-terminal-images'

Note that tupimage is included as a git submodule, so you don't have to install
it separately.

## Usage

### Preview image under cursor

There is the `:TerminalImagesShowUnderCursor` command. You can create a binding
or use an autocommand:

    nnoremap <leader>i :TerminalImagesShowUnderCursor<cr>
    autocmd CursorHold * :TerminalImagesShowUnderCursorIfReadable

### Preview all images in the current window

By default, the plugin parses visible lines of the current buffer on cursor hold
and tries to show images it finds in popup windows. You can disable this
behavior with the following line:

    let g:terminal_images_auto = 0

Or use `:TerminalImagesEnable`, `:TerminalImagesDisable` or
`:TerminalImagesToggle` to toggle this behavior. When automatic preview is
disabled you can trigger it manually with `:TerminalImagesShowAll`.

To enable or disable the plugin for the current buffer only, use
`:TerminalImagesEnableBuffer`, `:TerminalImagesDisableBuffer`. Note that buffer
settings has a precedence over the global one. To clear the buffer
setting in favor of the global one, use `:TerminalImagesUnletBuffer`.

To hide images in the current buffer use `:TerminalImagesClear`. If you think
some of the images failed to upload correctly, use
`:TerminalImagesShowAllForceReupload`.

### Preview the current file

By default, on `BufWinEnter` the plugin will check if the current file is an
image file, and will display it in a floating window. This can be disabled
separately:

    let g:terminal_images_auto_show_current = 0

## Configuration

### Preview window background

    highlight TerminalImagesBackground ctermbg=0 ctermfg=15

### Maximum preview window size

    let g:terminal_images_max_columns = 100
    let g:terminal_images_max_rows = 30

Doesn't influence the size of the current file preview.

### Upload command

    " Use the command on PATH and override ppi for each image
    let g:terminal_images_command="tupimage --override-ppi 96"

### Margins

Margins can be set to prohibit placing preview windows to close to the buffer
window edges.

    let g:terminal_images_right_margin = 2

Left margin may help it look a bit nicer since left edges of preview windows
will tend to be aligned.

    " Left margin can be a number of columns
    let g:terminal_images_left_margin = 20
    " or 'textwidth' to use &textwidth
    let g:terminal_images_left_margin = "textwidth"
    " or 'auto' to compute it atomatically based on the visible lines
    let g:terminal_images_left_margin = "auto"
