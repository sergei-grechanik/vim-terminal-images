#!/usr/bin/env bash

# vim: shiftwidth=4

# TODO: This script uses bash-specific features. Would be nice to make it more
#       portable.

# TODO list:
# - Fit status message to terminal width.
# - Fail on uploading error.
# - Deleting images from session.

script_fullname="$0"
script_name="$(basename $0)"

short_help="Usage: $script_name [OPTIONS] <image_file>

A utility to upload and display images in the terminal using the kitty graphics
protocol with the Unicode placeholder extension.

Options:
  -h                  Show this brief help.
  --help              Show full help.
  -c N, --cols N      Specify the number of columns.
  -r N, --rows N      Specify the number of rows.
  -o <file>           Output the characters representing the image to <file>.
  -e <file>           Output error messages to <file>.
  --256               Restrict the image ID to be within the range [1; 255].
  --fix               Try to reupload broken images.
  --fix --last N      Try to reupload broken images among N last images.
  --ls                List all images from the current session.
  --clear-term        Delete all known images from the terminal.
  -V                  Be very verbose.

Use --help to show the full help.
"

long_help="$script_name is a utility to upload and display images in the
terminal using the kitty graphics protocol with the Unicode placeholder
extension.

  Usage:
    $script_name [OPTIONS] [IMAGE_FILE]

  Examples:
    # Upload and display image.jpg, fitting it to 3 lines.
    $script_name -r 3 image.jpg

    # Reupload last 10 images if some of them appear broken.
    $script_name --fix --last 10

    # Reupload last 10 images, even if none of them appear broken.
    $script_name --fix --last 10 --force-upload

This utility automatically assigns an ID to the image instance, uploads the
image to the terminal, and outputs a placeholder text for the image instance.
The correspondence between IDs and image instances is recorded in the current
session database (think tmux sessions). The utility also keeps track of
successfully uploaded image instances. If uploading fails, the instance can be
reuploaded later using the --fix command.

Note that if image uploading fails, the utility doesn't fail by default: it
still produces the placeholder, and the image can be reuploaded later by calling
$script_name --fix. This behavior is desirable when images are displayed by
automatic script running within tmux (tmux makes image uploading unreliable).

  General options:
    -f <image_file>, --file <image_file>
        The image file (but you can specify it as a positional argument).
    --tty <file>
        Use the given file to communicate with the terminal and output status
        messages instead of /dev/tty.
    -e <file>, --err <file>
        Use <file> to output error messages in addition to displaying them as
        the status.
    -l <file>, --log <file>
        Enable logging and write logs to <file>.
    -V
        Same as --log /dev/stderr (i.e. be very verbose).
    -q, --quiet
        Do not show status messages or uploading progress. Error messages are
        still shown (but you can redirect them with --err).
    --save-info <file>
        Save some information to <file> (like image id, rows, columns, etc).
    --abort-on-keypress
        Abort when there is an input from the user.
    -h
        Show brief help.
    --help
        Show full help.

  Display options:
    -c N, --columns N, --cols N
    -r N, --rows N
        The number of columns and rows for the image. By default the script will
        try to compute the optimal values by itself.
    -x COLUMN, -y LINE
        Place the image and the status line at the given absolute coordinates.
        The coordinates are 1-based. Note that the output will use ANSI cursor
        movement sequences instead of \\n.
    -o <file>, --out <file>, --output <file>
        Use <file> to output the characters representing the image, instead of
        stdout.
    --noesc
        Do not issue the escape codes representing row numbers (encoded as
        foreground color).
    --less-diacritics
        Don't use column diacritics and specify the row number only in the first
        cell of a row. This will make the placeholder more lightweight but less
        reliable if it's partially obscured.
    --show-id N
        Display the image with the given id. The image will be reuploaded if
        needed.

  ID assignment options:
    --id N
        Use the specified image id instead of finding a free one.
    --256
        Restrict the image id to be within the range [1; 255] and use the 256
        colors mode to specify the image id (~24 bits will be used for image ids
        by default).

  Uploading options:
    --uploading-method <method>, -m <method>
        Set the uploading method which can be one of:
          'direct' for direct data uploading,
          'file'   for sending the file name to the terminal,
          'both'   for trying 'file' first and 'direct' on failure
          'auto'   to choose the method automatically (default).
    --no-upload
        Do not upload the image (it can be done later using --fix).
    --force-upload
        (Re)upload the image even if it has been uploaded.
    --no-tmux-hijack
        Do not try to hijack focus by creating a new pane when inside tmux and
        the current pane is not active (just fail instead).

  Session database management:
    --fix [IDs], --reupload [IDs]
        Reupload the given IDs. If no IDs are given, try to guess which images
        need reuploading automatically.
    --list, --ls
        List all images from the session in reverse chronological order.
    --last N
        Can be used together with --fix or --list. Reupload or show only last N
        IDs.
    --status
        Show various information.
    --clear-term
        Delete all known image data from the terminal.
    --clear-id <ID>
        Delete the image data corresponding to the given ID from the terminal.
    --clean-cache
        Remove some old files and IDs from the cache dir.

  Automatic row/column computation options:
    --max-cols N
        Do not exceed this value when automatically computing the number of
        columns. By default the width of the terminal is used as the maximum.
    --max-rows N
        Do not exceed this value when automatically computing the number of
        rows. This value cannot be larger than 255. By default the height of the
        terminal is used as the maximum.
    --cols-per-inch N
    --rows-per-inch N
        Floating point values specifying the number of terminal columns and rows
        per inch (may be approximate). Used to compute the optimal number of
        columns and rows when -c and -r are not specified. If these parameters
        are not specified, TUPIMAGE_COLS_PER_INCH and TUPIMAGE_ROWS_PER_INCH
        will be used. If they are not specified either, 12.0 and 6.0 will be
        used as columns per inch and rows per inch respectively.
    --get-cells-per-inch
        Queries the terminal and gets Xft.dpi to compute the number of columns
        per inch and rows per inch and writes them to stdout. May be used to
        initialize TUPIMAGE_COLS_PER_INCH and TUPIMAGE_ROWS_PER_INCH (e.g. in
        bashrc). Prints three numbers separated by space symbols: cols per inch,
        rows per inch, screen dpi.
    --override-ppi N
        Override ppi value for the image (both vertical and horizontal). By
        default ppi values will be requested using the 'identify' utility.

  Environment variables:
    TUPIMAGE_COLS_PER_INCH
    TUPIMAGE_ROWS_PER_INCH
        See  --cols-per-inch and --rows-per-inch.
    TUPIMAGE_OVERRIDE_PPI
        See --override-ppi.
    TUPIMAGE_CACHE_DIR
        The directory to store images being uploaded (in case if they need to be
        reuploaded) and session databases.
    TUPIMAGE_NO_TMUX_HIJACK
        If set, disable tmux hijacking.
    TUPIMAGE_UPLOADING_METHOD
        See --uploading-method.
    TUPIMAGE_CLEANUP_PROBABILITY
        The probability of running a clean-up on image upload (in %).
        Default: 5.
    TUPIMAGE_CACHE_COUNT_LIMIT
        The maximum number of images stored in the cache dir. Default: 512.
    TUPIMAGE_CACHE_SIZE_LIMIT
        The maximum total size of images stored in the cache dir, in Kbytes.
        Default: 300000.
    TUPIMAGE_IDS_LIMIT
        The maximum number of ids in a session or a terminal. Default: 512.
    TUPIMAGE_MAX_DAYS_OF_INACTIVITY
        The number of days of inactivity after which a session or terminal
        database is deleted. Default: 30.
"

# Exit the script on keyboard interrupt
trap "exit 1" INT

#Make sure that some_dir/* returns an empty list if some_dir is empty.
shopt -s nullglob

# The timeout for terminal response and file locks, in seconds.
default_timeout=3
# The size of a chunk (after base64-encoding), in bytes.
chunk_size=3968

# The probability of running a clean-up on image upload (in %).
cleanup_probability="$TUPIMAGE_CLEANUP_PROBABILITY"
[[ -n "$cleanup_probability" ]] || cleanup_probability=5
# The maximum number of days since last action after which a terminal or session
# dir will be deleted.
max_days_of_inactivity="$TUPIMAGE_MAX_DAYS_OF_INACTIVITY"
[[ -n "$max_days_of_inactivity" ]] || max_days_of_inactivity=30
# The maximum number of ids in a session or a terminal.
max_ids="$TUPIMAGE_IDS_LIMIT"
[[ -n "$max_ids" ]] || max_ids=512
# The number of ids deleted from a session or a terminal if there are too many.
num_ids_to_delete=4
# The maximum number of images stored in the cache dir.
max_cached_images="$TUPIMAGE_CACHE_COUNT_LIMIT"
[[ -n "$max_cached_images" ]] || max_cached_images=512
# The maximum total size of images stored in the cache dir, in Kbytes.
max_cached_images_size="$TUPIMAGE_CACHE_SIZE_LIMIT"
[[ -n "$max_cached_images_size" ]] || max_cached_images_size=300000
# The number of images to delete if there are too many.
num_images_to_delete=4

cols=""
rows=""
start_x=""
start_y=""
max_cols=""
max_rows=""
use_256=""
image_id=""
cols_per_inch="$TUPIMAGE_COLS_PER_INCH"
rows_per_inch="$TUPIMAGE_ROWS_PER_INCH"
cache_dir="$TUPIMAGE_CACHE_DIR"
override_ppi="$TUPIMAGE_OVERRIDE_PPI"
file=""
out="/dev/stdout"
err=""
tty="/dev/tty"
log=""
quiet=""
abort_on_keypress=""
noesc=""
less_diacritics=""
save_info=""
no_upload=""
force_upload=""
uploading_method="$TUPIMAGE_UPLOADING_METHOD"
tmux_hijack_allowed="1"
[[ -z "$TUPIMAGE_NO_TMUX_HIJACK" ]] || tmux_hijack_allowed=""
tmux_hijack_helper=""
store_code=""
store_pid=""
last_n=""

reupload=""
reupload_ids=()

cmd_list_images=""
cmd_clear_term=""
cmd_clear_id=""
cmd_clean_cache=""
cmd_show_status=""
cmd_show_id=""
cmd_get_cells_per_inch=""

command_count=0

# Parse the command line.
while [[ $# -gt 0 ]]; do
    case "$1" in
        -c|--columns|--cols)
            cols="$2"
            shift 2
            ;;
        -r|--rows)
            rows="$2"
            shift 2
            ;;
        -x)
            start_x="$2"
            shift 2
            ;;
        -y)
            start_y="$2"
            shift 2
            ;;
        -o|--out|--output)
            out="$2"
            shift 2
            ;;
        -e|--err)
            err="$2"
            shift 2
            ;;
        --tty)
            tty="$2"
            shift 2
            ;;
        -l|--log)
            log="$2"
            shift 2
            ;;
        -V)
            log="/dev/stderr"
            shift
            ;;
        -q|--quiet)
            quiet="1"
            shift
            ;;
        --abort-on-keypress)
            abort_on_keypress=1
            shift
            ;;
        -h)
            echo "$short_help"
            exit 0
            ;;
        --help)
            echo "$long_help" | less -F
            exit 0
            ;;
        -f|--file)
            if [[ -n "$file" ]]; then
                echo "Multiple image files are not supported" >&2
                exit 1
            fi
            file="$2"
            shift 2
            ;;
        --id)
            image_id="$2"
            shift 2
            ;;
        --256)
            use_256=1
            shift
            ;;
        --noesc)
            noesc=1
            shift
            ;;
        --less-diacritics)
            less_diacritics=1
            shift
            ;;
        --save-info)
            save_info="$2"
            shift 2
            ;;
        --no-tmux-hijack)
            tmux_hijack_allowed=""
            shift
            ;;
        -m|--uploading-method)
            uploading_method="$2"
            shift 2
            ;;
        --no-upload)
            no_upload=1
            shift
            ;;
        --force-upload)
            force_upload=1
            shift
            ;;
        --max-cols)
            max_cols="$2"
            shift 2
            ;;
        --max-rows)
            max_rows="$2"
            if (( max_rows > 255 )); then
                echo "--max-rows cannot be larger than 255 ($2 is specified)" >&2
                exit 1
            fi
            shift 2
            ;;
        --cols-per-inch)
            cols_per_inch="$2"
            shift 2
            ;;
        --rows-per-inch)
            rows_per_inch="$2"
            shift 2
            ;;
        --override-ppi|--override-dpi)
            override_ppi="$2"
            shift 2
            ;;
        --last)
            last_n="$2"
            shift 2
            ;;

        # Subcommand-like options
        --fix|--reupload)
            reupload=1
            ((command_count++))
            shift
            while [[ "$1" =~ ^[0-9]+$ ]]; do
                reupload_ids+=("$1")
                shift
            done
            ;;
        --list|--ls)
            cmd_list_images=1
            ((command_count++))
            shift
            ;;
        --clear-term)
            cmd_clear_term=1
            ((command_count++))
            shift
            ;;
        --clear-id)
            cmd_clear_id="$2"
            ((command_count++))
            shift 2
            ;;
        --clean-cache)
            cmd_clean_cache=1
            ((command_count++))
            shift
            ;;
        --status)
            cmd_show_status=1
            ((command_count++))
            shift
            ;;
        --show-id)
            cmd_show_id="$2"
            if [[ -z "$cmd_show_id" ]]; then
                echo "No id specified" >&2
                exit 1
            fi
            ((command_count++))
            shift 2
            ;;
        --get-cells-per-inch)
            cmd_get_cells_per_inch=1
            ((command_count++))
            shift
            ;;

        # Options used internally.
        --store-pid)
            store_pid="$2"
            shift 2
            ;;
        --store-code)
            store_code="$2"
            shift 2
            ;;
        --tmux-hijack-helper)
            tmux_hijack_helper=1
            shift
            ;;

        -*)
            echo "Unknown option: $1" >&2
            exit 1
            ;;
        *)
            if [[ -n "$file" ]]; then
                echo "Multiple image files are not supported: $file and $1" >&2
                exit 1
            fi
            file="$1"
            shift
            ;;
    esac
done

#####################################################################
# Verify options, compute defaults
#####################################################################

if (( $command_count > 0 )); then
    if (( $command_count > 1 )); then
        echo "Only one command-like option may be specified" >&2
        exit 1
    fi
    if [[ -n "$file" ]]; then
        echo "File cannot be specified together with a command-like option" >&2
        exit 1
    fi
fi

[[ -n "$uploading_method" ]] || uploading_method="auto"

if [[ ! "$uploading_method" =~ ^(direct|file|both|auto)$ ]]; then
    echo "Unknown uploading method: $uploading_method" >&2
    exit 1
fi

# If start_x or start_y is specified, make sure that both are set.
if [[ -n "$start_x" || -n "$start_y" ]]; then
    [[ -n "$start_x" ]] || start_x=0
    [[ -n "$start_y" ]] || start_y=0
fi

# The number of terminal columns starting from the upper left corner. This value
# is used when displaying the status message so that we take only 1 line.
max_terminal_cols="$(tput cols)"
if [[ -n "$start_x" ]]; then
    max_terminal_cols="$(( "$max_terminal_cols" - "$start_x" + 1 ))"
fi

# Write max_terminal_cols spaces to `eraser`. It will be used to erase the status line.
printf -v eraser '%0.s ' $(seq 1 "$max_terminal_cols")

# Compute the maximum number of rows and columns if these values were not
# specified.
if [[ -z "$max_cols" ]]; then
    max_cols="$max_terminal_cols"
fi
if [[ -z "$max_rows" ]]; then
    max_rows="$(tput lines)"
    if [[ -n "$start_y" ]]; then
        max_rows="$(( "$max_rows" - "$start_y" + 1 ))"
    fi
    if (( max_rows > 255 )); then
        max_rows=255
    fi
fi

if (( "$max_rows" <= 0 )) || (( "$max_cols" <= 0 )); then
    echo "Max rows ($max_rows) and max cols ($max_cols) cannot be <= 0" >&2
    exit 1
fi

#####################################################################
# Logging, status and error reporting functions
#####################################################################

# A utility function to print logs
echolog() {
    if [[ -n "$log" ]]; then
        (flock 1; echo "$$ $(date +%s.%3N) $1") >> "$log"
    fi
}

# A utility function to display what the script is doing (on tty).
echostatus() {
    echolog "$1"
    if [[ -z "$quiet" ]]; then
        # Clear the current line
        if [[ -z "$start_x" ]]; then
            echo -ne "\r" > "$tty"
            echo -n "${eraser}" > "$tty"
            echo -ne "\r" > "$tty"
        else
            # If -x/-y are specified, move to the upper left corner first.
            echo -en "\e[${start_y};${start_x}H" > "$tty"
            echo -n "${eraser}" > "$tty"
            echo -en "\e[${start_y};${start_x}H" > "$tty"
        fi
        # And display the status. Truncate it if it's too long.
        echo -n "$1" | colrm "$max_terminal_cols" > "$tty"
    fi
}

# Display a message, both as the status and to $err.
echomessage() {
    if [[ -z "$err" ]]; then
        echostatus ""
        echo "$1" >> /dev/stderr
        echolog "$1"
    else
        echostatus "$1"
        echo "$1" >> "$err"
    fi
}

# Write something to $out.
echoout() {
    echo "$1" >> "$out"
}

# Display an error message, both as the status and to $err, prefixed with
# "error:".
echoerr() {
    echomessage "error: $1"
}

#####################################################################
# Some basic initialization
#####################################################################

echolog ""

echolog "max_cols: $max_cols"
echolog "max_rows: $max_rows"

[[ -z "$save_info" ]] || > "$save_info"
[[ -z "$out" ]] || > "$out"

# Store the pid of the current process if requested. This is needed for tmux
# hijacking so that the original script can wait for the uploading process.
if [[ -n "$store_pid" ]]; then
    echolog "Storing $$ to $store_pid"
    echo "$$" > "$store_pid"
fi

check_keypress() {
    if [[ -n "$abort_on_keypress" ]]; then
        read_character=""
        if read -n 1 -t 0.001 read_character < "$tty"; then
            if [[ -n "$read_character" ]]; then
                echoerr "Aborted on key press"
                exit 1
            fi
        fi
    fi
}

check_keypress

#####################################################################
# Detecting tmux and figuring out the actual terminal name
#####################################################################

# The name of the terminal, used to adjust to the specific flavor of the
# protocol (like whether we need to convert to PNG).
actual_term="$TERM"

# Some id of the terminal. Used to figure out whether some image has already
# been uploaded to the terminal without querying the terminal itself. Without
# tmux we just use the window id of the terminal which should somewhat uniquely
# identify the instance of the terminal.
terminal_id="$TERM-$WINDOWID"

# Some id of the session. Each session contains its own "namespace" of image
# ids, i.e. if two processes belong to the same session and load different
# images, these images have to be assigned to different image ids. Without tmux
# we just use the terminal id since we can't (easily) reattach a session to a
# different terminal. For tmux see below.
session_id="$terminal_id"

# This variable indicates whether we are inside tmux.
inside_tmux=""
if [[ -n "$TMUX" ]] && [[ "$TERM" =~ "screen" ]]; then
    inside_tmux="1"
    # Get the actual current terminal name from tmux.
    actual_term="$(tmux display-message -p "#{client_termname}")"
    # There doesn't seem to be a nice way to reliably get the current WINDOWID
    # of the terminal we are attached to (please correct me if I'm wrong). So we
    # use the last client pid of tmux as terminal id.
    terminal_id="tmux-client-$(tmux display-message -p "#{client_pid}")"
    # For the session id we use the tmux server pid with tmux session id.
    session_id="tmux-$(tmux display-message -p "#{pid}-#{session_id}")"
fi

# Replace non-alphabetical chars with '-' to make them suitable for dir names.
terminal_id="$(sed 's/[^0-9a-zA-Z]/-/g' <<< "$terminal_id")"
session_id="$(sed 's/[^0-9a-zA-Z]/-/g' <<< "$session_id")"

# Make sure that the cache dir contains session and terminal subdirs.
[[ -n "$cache_dir" ]] || cache_dir="$HOME/.cache/tupimage"
session_dir_256="$cache_dir/sessions/${session_id}-8bit_ids"
terminal_dir_256="$cache_dir/terminals/${terminal_id}-8bit_ids"
session_dir_24bit="$cache_dir/sessions/${session_id}-24bit_ids"
terminal_dir_24bit="$cache_dir/terminals/${terminal_id}-24bit_ids"

mkdir -p "$cache_dir/cache/" 2> /dev/null
mkdir -p "$session_dir_256" 2> /dev/null
mkdir -p "$terminal_dir_256" 2> /dev/null
mkdir -p "$session_dir_24bit" 2> /dev/null
mkdir -p "$terminal_dir_24bit" 2> /dev/null

touch "$session_dir_256" "$terminal_dir_256" \
    "$session_dir_24bit" "$terminal_dir_24bit"

echolog "terminal_id=$terminal_id"
echolog "session_id=$session_id"

#####################################################################
# Choosing the uploading method
#####################################################################

if [[ "$uploading_method" =~ ^(auto)$ ]]; then
    if [[ -n "$SSH_CLIENT" || -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
        echolog "Look like we are in ssh, using direct uploading"
        uploading_method="direct"
    else
        uploading_method="both"
    fi
fi

#####################################################################
# Helper function for displaying the image placeholder
#####################################################################

display_image() {
    local image_id="$1"
    local cols="$2"
    local rows="$3"
    rowcolumn_diacritics=("\U305" "\U30d" "\U30e" "\U310" "\U312" "\U33d" "\U33e"
        "\U33f" "\U346" "\U34a" "\U34b" "\U34c" "\U350" "\U351" "\U352" "\U357"
        "\U35b" "\U363" "\U364" "\U365" "\U366" "\U367" "\U368" "\U369" "\U36a"
        "\U36b" "\U36c" "\U36d" "\U36e" "\U36f" "\U483" "\U484" "\U485" "\U486"
        "\U487" "\U592" "\U593" "\U594" "\U595" "\U597" "\U598" "\U599" "\U59c"
        "\U59d" "\U59e" "\U59f" "\U5a0" "\U5a1" "\U5a8" "\U5a9" "\U5ab" "\U5ac"
        "\U5af" "\U5c4" "\U610" "\U611" "\U612" "\U613" "\U614" "\U615" "\U616"
        "\U617" "\U657" "\U658" "\U659" "\U65a" "\U65b" "\U65d" "\U65e" "\U6d6"
        "\U6d7" "\U6d8" "\U6d9" "\U6da" "\U6db" "\U6dc" "\U6df" "\U6e0" "\U6e1"
        "\U6e2" "\U6e4" "\U6e7" "\U6e8" "\U6eb" "\U6ec" "\U730" "\U732" "\U733"
        "\U735" "\U736" "\U73a" "\U73d" "\U73f" "\U740" "\U741" "\U743" "\U745"
        "\U747" "\U749" "\U74a" "\U7eb" "\U7ec" "\U7ed" "\U7ee" "\U7ef" "\U7f0"
        "\U7f1" "\U7f3" "\U816" "\U817" "\U818" "\U819" "\U81b" "\U81c" "\U81d"
        "\U81e" "\U81f" "\U820" "\U821" "\U822" "\U823" "\U825" "\U826" "\U827"
        "\U829" "\U82a" "\U82b" "\U82c" "\U82d" "\U951" "\U953" "\U954" "\Uf82"
        "\Uf83" "\Uf86" "\Uf87" "\U135d" "\U135e" "\U135f" "\U17dd" "\U193a"
        "\U1a17" "\U1a75" "\U1a76" "\U1a77" "\U1a78" "\U1a79" "\U1a7a" "\U1a7b"
        "\U1a7c" "\U1b6b" "\U1b6d" "\U1b6e" "\U1b6f" "\U1b70" "\U1b71" "\U1b72"
        "\U1b73" "\U1cd0" "\U1cd1" "\U1cd2" "\U1cda" "\U1cdb" "\U1ce0" "\U1dc0"
        "\U1dc1" "\U1dc3" "\U1dc4" "\U1dc5" "\U1dc6" "\U1dc7" "\U1dc8" "\U1dc9"
        "\U1dcb" "\U1dcc" "\U1dd1" "\U1dd2" "\U1dd3" "\U1dd4" "\U1dd5" "\U1dd6"
        "\U1dd7" "\U1dd8" "\U1dd9" "\U1dda" "\U1ddb" "\U1ddc" "\U1ddd" "\U1dde"
        "\U1ddf" "\U1de0" "\U1de1" "\U1de2" "\U1de3" "\U1de4" "\U1de5" "\U1de6"
        "\U1dfe" "\U20d0" "\U20d1" "\U20d4" "\U20d5" "\U20d6" "\U20d7" "\U20db"
        "\U20dc" "\U20e1" "\U20e7" "\U20e9" "\U20f0" "\U2cef" "\U2cf0" "\U2cf1"
        "\U2de0" "\U2de1" "\U2de2" "\U2de3" "\U2de4" "\U2de5" "\U2de6" "\U2de7"
        "\U2de8" "\U2de9" "\U2dea" "\U2deb" "\U2dec" "\U2ded" "\U2dee" "\U2def"
        "\U2df0" "\U2df1" "\U2df2" "\U2df3" "\U2df4" "\U2df5" "\U2df6" "\U2df7"
        "\U2df8" "\U2df9" "\U2dfa" "\U2dfb" "\U2dfc" "\U2dfd" "\U2dfe" "\U2dff"
        "\Ua66f" "\Ua67c" "\Ua67d" "\Ua6f0" "\Ua6f1" "\Ua8e0" "\Ua8e1" "\Ua8e2"
        "\Ua8e3" "\Ua8e4" "\Ua8e5" "\Ua8e6" "\Ua8e7" "\Ua8e8" "\Ua8e9" "\Ua8ea"
        "\Ua8eb" "\Ua8ec" "\Ua8ed" "\Ua8ee" "\Ua8ef" "\Ua8f0" "\Ua8f1" "\Uaab0"
        "\Uaab2" "\Uaab3" "\Uaab7" "\Uaab8" "\Uaabe" "\Uaabf" "\Uaac1" "\Ufe20"
        "\Ufe21" "\Ufe22" "\Ufe23" "\Ufe24" "\Ufe25" "\Ufe26" "\U10a0f" "\U10a38"
        "\U1d185" "\U1d186" "\U1d187" "\U1d188" "\U1d189" "\U1d1aa" "\U1d1ab"
        "\U1d1ac" "\U1d1ad" "\U1d242" "\U1d243" "\U1d244")

    local row_string=""
    if [[ -n "$less_diacritics" ]]; then
        for idx in $(seq 2 "$cols"); do
            row_string="${row_string}"
            printf -v row_string "%s\UEEEE" "$row_string"
        done
    fi

    # Each line starts with the escape sequence to set the foreground color to
    # the image id, unless --noesc is specified.
    line_start=""
    line_end=""
    if [[ -z "$noesc" ]]; then
        if [[ -n "$use_256" ]]; then
            line_start="$(echo -en "\e[38;5;${image_id}m")"
            line_end="$(echo -en "\e[39;m")"
        else
            blue="$(( "$image_id" % 256 ))"
            green="$(( ("$image_id" / 256) % 256 ))"
            red="$(( ("$image_id" / 65536) % 256 ))"
            line_start="$(echo -en "\e[38;2;${red};${green};${blue}m")"
            line_end="$(echo -en "\e[39;m")"
        fi
    fi

    # Clear the status line.
    echostatus

    # If we are requested to display the image at the given absolute
    # coordinates, we will use ANSI cursor movement codes, otherwise just append
    # \n to line_end.
    if [[ -z "$start_x" ]]; then
        printf -v line_end '%s\n' "$line_end"
    fi

    # Fill the output with characters representing the image
    for y in `seq 0 $(expr $rows - 1)`; do
        if [[ $((y % 10)) -eq 0 ]]; then
            check_keypress
        fi
        # If we are using absolute positioning, explicitly move the cursor.
        if [[ -n "$start_x" ]]; then
            echo -en "\e[$(("$start_y" + "$y"));${start_x}H"
        fi
        echo -n "$line_start"
        if [[ -n "$less_diacritics" ]]; then
            # In the less diacritics mode specify the row only in the first
            # cell, and the use just \UEEEE.
            printf "\UEEEE${rowcolumn_diacritics[$y]}%s" "$row_string"
        else
            for x in `seq 0 $(expr $cols - 1)`; do
                # Note that when $x is out of bounds, the column diacritic will
                # be empty, meaning that the column should be guessed by the
                # terminal.
                printf "\UEEEE${rowcolumn_diacritics[$y]}${rowcolumn_diacritics[$x]}"
            done
        fi
        printf '%s' "$line_end"
    done >> "$out"
}

#####################################################################
# Helper functions for cache dir clean-up
#####################################################################

# Deletes session and terminal dirs and lock files that are too old.
delete_stale_dirs() {
    for directory in "$cache_dir/sessions"/* "$cache_dir/terminals"/*; do
        local age="$((($(date +%s) - $(date +%s -r "$directory")) / 86400))"
        if (( "$age" > "$max_days_of_inactivity" )); then
            echostatus "Deleting $age days old $directory"
            rm -r "$directory"
        fi
    done
}

# Deletes $2 oldest files from $1.
delete_oldest_files() {
    local directory="$1"
    local num_delete="$2"
    echostatus "Deleting $num_delete files from $directory"
    # Delete converted png files first
    for file in $(ls -1t "$directory" | tail -$num_delete); do
        if [[ "$file" =~ ^.*\.converted\.png$ ]]; then
            rm "$directory/$file"
            ((num_delete--))
        fi
    done
    if (( "$num_delete" > 0 )); then
        for file in $(ls -1t "$directory" | tail -$num_delete); do
            rm "$directory/$file"
        done
    fi
}

# If there are more than $2 files in $1, deletes $3 oldest files.
delete_files_if_too_many() {
    local directory="$1"
    local max_files="$2"
    local num_delete="$3"
    if (( "$(ls -1 "$directory" | wc -l)" > "$max_files" )); then
        delete_oldest_files "$directory" "$num_delete"
    fi
}

# If there are more than $2 Kbytes in $1, deletes $3 oldest files.
delete_files_if_too_large() {
    local directory="$1"
    local max_kb="$2"
    local num_delete="$3"
    while (( "$(du -s "$directory" | cut -f1)" > "$max_kb" )); do
        delete_oldest_files "$directory" "$num_delete"
    done
}

# Performs cache clean-up: removes stale terminal and session dirs, deletes old
# image files, removes old ids if there are too many of them.
cleanup_cache() {
    delete_stale_dirs
    for directory in "$session_dir_256" "$session_dir_24bit" \
                     "$terminal_dir_256" "$terminal_dir_24bit"; do
        delete_files_if_too_many "$directory" "$max_ids" "$num_ids_to_delete"
    done
    delete_files_if_too_many "$cache_dir/cache" \
        "$max_cached_images" "$num_images_to_delete"
    delete_files_if_too_large "$cache_dir/cache" \
        "$max_cached_images_size" "$num_images_to_delete"
}

#####################################################################
# Creating a temp dir and adjusting the terminal state
#####################################################################

# Create a temporary directory to store the chunked image.
tmpdir="$(mktemp -d)"

if [[ ! "$tmpdir" || ! -d "$tmpdir" ]]; then
    echoerr "Can't create a temp dir"
    exit 1
fi

# We will need to disable echo during image uploading, otherwise the response
# from the terminal containing the image id will get echoed. We will restore the
# terminal settings on exit unless we get brutally killed.
stty_orig="$(stty -g < "$tty")"

disable_echo() {
    stty -echo < "$tty"
    # Disable ctrl-z. Pressing ctrl-z during image uploading may cause some
    # horrible issues otherwise.
    stty susp undef < "$tty"
}

restore_echo() {
    stty $stty_orig < "$tty"
}

# Utility to read response from the terminal that we don't need anymore. (If we
# don't read it it may end up being displayed which is not pretty).
consume_errors() {
    while read -r -d '\' -t 0.1 term_response < "$tty"; do
        echolog "Consuming unneeded response: $(sed 's/\x1b/^[/g' <<< "$term_response")"
    done
}

# On exit restore terminal settings, consume possible errors from the terminal
# and remove the temporary directory.
cleanup() {
    consume_errors
    restore_echo
    [[ -z "$tmpdir" ]] || rm "$tmpdir/"* 2> /dev/null
    rmdir "$tmpdir" || echolog "Could not remove $tmpdir"
}

# Register the cleanup function to be called on the EXIT signal.
trap cleanup EXIT TERM

#####################################################################
# Helper functions for image uploading
#####################################################################

# Functions to emit the start and the end of a graphics command.
if [[ -n "$inside_tmux" ]]; then
    # If we are in tmux we have to wrap the command in Ptmux.
    graphics_command_start='\ePtmux;\e\e_G'
    graphics_command_end='\e\e\\\e\\'
else
    graphics_command_start='\e_G'
    graphics_command_end='\e\\'
fi

start_gr_command() {
    echo -en "$graphics_command_start" > "$tty"
}
end_gr_command() {
    echo -en "$graphics_command_end" > "$tty"
}

# Send a graphics command with the correct start and end
gr_command() {
    start_gr_command
    echo -en "$1" > "$tty"
    end_gr_command
    if [[ -n "$log" ]]; then
        local command="$(echo -en "${graphics_command_start}$1${graphics_command_end}")"
        echolog "SENDING COMMAND: $(sed 's/\x1b/^[/g' <<< "$command")"
    fi
}

# Show the invalid terminal response message.
invalid_terminal_response() {
    echoerr "Invalid terminal response: $(sed 's/\x1b/^[/g' <<< "$term_response")"
}

# Get a response from the terminal and store it in term_response,
# returns 1 if there is no response.
get_terminal_response() {
    local response_timeout="$1"
    [[ -n "$response_timeout" ]] || response_timeout="$default_timeout"
    term_response=""
    term_response_printable=""
    term_response_ok=""
    # -r means backslash is part of the line
    # -d '\' means \ is the line delimiter
    # -t ... is timeout in seconds
    if ! read -s -r -d '\' -t "$response_timeout" term_response < "$tty"; then
        if [[ -z "$term_response" ]]; then
            term_response_printable="No response from terminal"
        else
            invalid_terminal_response
            term_response_printable="Invalid response from terminal"
        fi
        return 1
    fi
    term_response_printable="$(sed 's/\x1b/^[/g' <<< "$term_response")"
    echolog "term_response: $term_response_printable"
    regex='.*_G.*;OK.*'
    if [[ "$term_response" =~ $regex ]]; then
        term_response_ok=1
    fi
}

# Uploads an image to the terminal. If $terminal_dir and $img_instance are
# specified, acquires the lock and adds the image to the list of images known to
# be uploaded to the terminal.
# Usage: upload_image $image_id $file $cols $rows [$terminal_dir] [$img_instance]
upload_image() {
    local image_id="$1"
    local file="$2"
    local cols="$3"
    local rows="$4"
    local terminal_dir="$5"
    local img_instance="$6"

    if [[ -n "$terminal_dir" ]] && [[ -n "$img_instance" ]]; then
        (
            flock --timeout "$default_timeout" 9 || \
                { echoerr "Could not acquire a lock on $terminal_dir.lock"; \
                  exit 1; }
            rm "$terminal_dir/$image_id" 2> /dev/null
            if upload_image "$image_id" "$file" "$cols" "$rows"; then
                echo "$img_instance" > "$terminal_dir/$image_id"
            else
                exit 1
            fi
        ) 9>"$terminal_dir.lock" || return 1
        return 0
    fi

    if [[ -z "$tmpdir" ]]; then
        echoerr "Temporary dir hasn't been created"
        return 1
    fi

    rm "$tmpdir/"* 2> /dev/null

    if [[ "$actual_term" == *kitty* ]]; then
        # Check if the image is a png, and if it's not, try to convert it.
        if ! (file "$file" | grep -q "PNG image"); then
            local png_file="${file}.converted.png"
            if [[ ! -f "$png_file" ]]; then
                echostatus "Converting the image to png"
                if ! convert "$file" "$png_file" || \
                        ! [[ -f "$png_file" ]]; then
                    echoerr "Cannot convert the image to png"
                    return 1
                fi
            fi
            file="$png_file"
        fi
    fi

    if [[ "$uploading_method" == "file" || "$uploading_method" == "both" ]]; then
        # base64-encode the filename
        echo -n "$file" | base64 -w0 > "$tmpdir/filename"
    fi

    if [[ "$uploading_method" == "direct" || "$uploading_method" == "both" ]]; then
        # base64-encode the file and split it into chunks. The size of each
        # graphics command shouldn't be more than 4096, so we set the size of an
        # encoded chunk to be 3968, slightly less than that.
        echostatus "base64-encoding and chunking the image"
        cat "$file" | base64 -w0 | split -b "$chunk_size" - "$tmpdir/chunk_"
    fi

    # Write the size of the image in bytes to the "size" file.
    wc -c < "$file" > "$tmpdir/size"

    # Tmux may cause some instability, try two times as a workaround.
    local attempts=1
    if [[ -n "$inside_tmux" ]]; then
        attempts=2
    fi

    for attempt in $(seq 1 $attempts); do
        if upload_image_impl "$image_id" "$tmpdir" "$cols" "$rows"; then
            return 0
        fi
    done
    return 1
}

# Checks if inside the active tmux pane.
tmux_is_active_pane() {
    local tmux_active="$(tmux display-message -t $TMUX_PANE \
                            -p "#{window_active}#{pane_active}")"
    if [[ "$tmux_active" == "11" ]]; then
        return 0
    else
        return 1
    fi
}

# Queries whether the given id is known by the terminal. Returns
# - 0 if reuploading is needed,
# - 1 if unknown (no response or in inactive tmux pane),
# - 2 if reuploading is not needed.
# Usage: image_needs_reuploading "$image_id" "$cols" "$rows"
image_needs_reuploading() {
    local image_id="$1"
    local cols="$2"
    local rows="$3"
    if [[ -n "$inside_tmux" ]] && ! tmux_is_active_pane; then
        # If we are in tmux, but not in an active pain, we can't get the
        # response quickly, so assume that we don't need reuploading.
        return 1
    fi
    echostatus "Checking if image with id $image_id needs reuploading"
    # We check if the id is known by recreating the virtual instance. Currently
    # it's always assumed to be of placement_id=1.
    gr_command "a=p,U=1,p=1,i=$image_id,c=${cols},r=${rows}"
    # Use the shorter timeout. If we don't get a response, assume that we don't
    # need reuploading.
    get_terminal_response 0.5 || return 1
    if [[ -n "$term_response_ok" ]]; then
        echolog "Image is known by the terminal"
        return 2
    fi
    echolog "Image needs reuploading"
    return 0
}

# Uploads a (possibly already chunked) image to the terminal.
# Usage: upload_image_impl $image_id $tmpdir $cols $rows
upload_image_impl() {
    local image_id="$1"
    local tmpdir="$2"
    local cols="$3"
    local rows="$4"

    # Check if we are in the active tmux pane. Uploading images from inactive
    # panes is impossible, so we either need to fail or to hijack focus by
    # creating a new pane.
    if [[ -n "$inside_tmux" ]]; then
        if ! tmux_is_active_pane; then
            hijack_tmux "$image_id" "$tmpdir" "$cols" "$rows"
            return $?
        fi
    fi

    # Read the original file size from the "size" file
    local size_info=""
    local total_size=""
    if [[ -e "$tmpdir/size" ]]; then
        total_size="$(cat "$tmpdir/size")"
        size_info=",S=$total_size"
    fi

    # Some versions of tmux may drop packets if the terminal is too slow to
    # process them. Use a delay as a workaround. The issue should be fixed in
    # newer versions of tmux, see https://github.com/tmux/tmux/issues/3001
    if [[ -n "$inside_tmux" ]]; then
        sleep 0.1
    fi

    # Try sending the filename if there is the encoded filename
    if [[ -e "$tmpdir/filename" ]]; then
        echostatus "Trying file-based uploading"
        disable_echo
        gr_command "a=T,U=1,i=$image_id,f=100,t=f,c=${cols},r=${rows}${size_info};$(cat "$tmpdir/filename")"

        echostatus "Awaiting terminal response"
        get_terminal_response
        restore_echo
        if [[ -n "$term_response_ok" ]]; then
            return 0
        fi

        echoerr "File-based uploading error: $term_response_printable"
    fi

    # Now try chunked uploading if there are chunks
    if [[ -z "$(echo "$tmpdir/chunk_"*)" ]]; then
        return 1
    fi
    chunk_i=0
    start_time="$(date +%s%3N)"
    speed=""

    # Issue a command indicating that we want to start data transmission for a
    # new image.
    # a=T    the action is to transmit data and create placement
    # U=1    the placement is defined by Unicode symbols (extension)
    # i=$image_id
    # f=100  PNG. st will ignore this field, for kitty we support only PNG.
    # t=d    transmit data directly
    # c=,r=  width and height in cells
    # s=,v=  width and height in pixels (not used here)
    # o=z    use compression (not used here)
    # m=1    multi-chunked data
    # S=     original file size
    disable_echo
    gr_command "a=T,U=1,i=$image_id,f=100,t=d,c=${cols},r=${rows},m=1${size_info}"

    # Transmit chunks and display progress.
    for chunk in "$tmpdir/chunk_"*; do
        echolog "Uploading chunk $chunk"
        chunk_i=$((chunk_i+1))
        if [[ $((chunk_i % 10)) -eq 1 ]]; then
            check_keypress
            # Check if we are still in the active pane
            if [[ -n "$inside_tmux" ]]; then
                if ! tmux_is_active_pane; then
                    echoerr "Tmux pane became inactive, aborting the upload"
                    return 1
                fi
            fi
            # Do not compute the speed too often
            if [[ $((chunk_i % 100)) -eq 1 ]]; then
                # We use +%s%3N to show time in milliseconds
                curtime="$(date +%s%3N)"
                timediff="$((curtime - start_time))"
                if [[ "$timediff" -ne 0 ]]; then
                    # We multiply by 3 and divide by 4 because chunks are
                    # base64-encoded and we want to show speed in terms of the
                    # original image size.
                    # We multiply by 1000 to convert from ms to s.
                    # We divide by 1024 to convert from bytes to Kbytes.
                    speed="$(((chunk_i - 1)*chunk_size*1000*3/4/1024 / timediff)) K/s"
                fi
            fi
            echostatus "$((chunk_i*chunk_size*3/4/1024))/$((total_size / 1024))K [$speed]"
        fi
        # The uploading of the chunk goes here.
        start_gr_command
        echo -en "i=$image_id,m=1;" > "$tty"
        cat $chunk > "$tty"
        end_gr_command
    done

    # Tell the terminal that we are done.
    gr_command "i=$image_id,m=0"

    echostatus "Awaiting terminal response"
    get_terminal_response
    restore_echo
    if [[ -z "$term_response_ok" ]]; then
        echoerr "Uploading error: $term_response_printable"
        return 1
    fi
    return 0
}

# Creates a tmux pane and uploads an already chunked image to the terminal.
# Usage: hijack_tmux $image_id $tmpdir $cols $rows
hijack_tmux() {
    local image_id="$1"
    local tmpdir="$2"
    local cols="$3"
    local rows="$4"

    if [[ -z "$tmux_hijack_allowed" ]]; then
        echoerr "Not in active pane and tmux hijacking is not allowed"
        return 1
    fi

    echostatus "Not in active pane, hijacking tmux"
    local tmp_pid="$(mktemp)"
    local tmp_ret="$(mktemp)"
    local tmp_err="$(mktemp)"
    echolog "tmp_pid=$tmp_pid"
    touch "$tmp_err"
    # Run a helper in a new pane
    tmux split-window -l 1 "$script_fullname" \
        -c "$cols" \
        -r "$rows" \
        -e "$tmp_err" \
        -l "$log" \
        -f "$tmpdir" \
        --id "$image_id" \
        --store-pid "$tmp_pid" \
        --store-code "$tmp_ret" \
        --tmux-hijack-helper
    if [[ $? -ne 0 ]]; then
        return 1
    fi
    # The process we've created should write its pid to the specified file. It's
    # not always quick.
    for iter in $(seq 10); do
        sleep 0.1
        local pid_to_wait="$(cat $tmp_pid)"
        if [[ -n "$pid_to_wait" ]]; then
            break
        fi
    done
    if [[ -z "$pid_to_wait" ]]; then
        echoerr "Can't create a tmux hijacking process"
        return 1
    fi
    echolog "Waiting for the process $pid_to_wait"
    # Wait for the process to finish.
    # tail --pid=$pid_to_wait -f /dev/null
    while true; do
        sleep 0.1
        if ! kill -0 "$pid_to_wait" 2> /dev/null; then
            break
        fi
    done
    ret_code="$(cat $tmp_ret)"
    echolog "Process $pid_to_wait finished with code $ret_code"
    # Display errors from the helper
    if [[ "$ret_code" != 0 ]]; then
        echomessage "$(cat "$tmp_err")"
    fi

    rm "$tmp_pid" 2> /dev/null || echolog "Could not rm $tmp_pid"
    rm "$tmp_ret" 2> /dev/null || echolog "Could not rm $tmp_ret"
    rm "$tmp_err" 2> /dev/null || echolog "Could not rm $tmp_err"

    [[ -n "$ret_code" ]] || ret_code="1"
    return "$ret_code"
}

#####################################################################
# Running the tmux hijack helper if requested.
#####################################################################

if [[ -n "$tmux_hijack_helper" ]]; then
    # Do not allow any more hijack attempts.
    tmux_hijack_allowed=""
    upload_image_impl "$image_id" "$file" "$cols" "$rows"
    ret_code="$?"
    echo "$ret_code" > "$store_code"
    exit "$ret_code"
fi

#####################################################################
# Handling the clear-term command
#####################################################################

if [[ -n "$cmd_clear_term" ]]; then
    for terminal_dir in "$terminal_dir_256" "$terminal_dir_24bit"; do
        echomessage "Clearing $terminal_dir"
        (
            flock --timeout "$default_timeout" 9 || \
                { echoerr "Could not acquire a lock on $terminal_dir.lock"; \
                  exit 1; }
            rm "$terminal_dir"/* 2> /dev/null
            # Delete all images (if this command fails, e.g. because of tmux, we
            # don't care).
            gr_command "a=d,q=2"
            exit 0
        ) 9>"$terminal_dir.lock" || exit 1
    done
    exit 0
fi

#####################################################################
# Handling the clear-id command
#####################################################################

if [[ -n "$cmd_clear_id" ]]; then
    for terminal_dir in "$terminal_dir_256" "$terminal_dir_24bit"; do
        if [[ -e "$terminal_dir/$cmd_clear_id" ]]; then
            (
                flock --timeout "$default_timeout" 9 || \
                    { echoerr "Could not acquire a lock on $terminal_dir.lock"; \
                      exit 1; }
                rm "$terminal_dir/$cmd_clear_id" 2> /dev/null
                # Delete the image (if this command fails, e.g. because of tmux,
                # we don't care).
                gr_command "a=d,d=I,i=${cmd_clear_id},q=2"
                exit 0
            ) 9>"$terminal_dir.lock" || exit 1
            exit 0
        fi
    done
    exit 1
fi

#####################################################################
# Handling the clean-cache command
#####################################################################

if [[ -n "$cmd_clean_cache" ]]; then
    cleanup_cache
    exit 0
fi

#####################################################################
# Handling the status command
#####################################################################

if [[ -n "$cmd_show_status" ]]; then
    imgs_count="$(ls -1 "$cache_dir/cache" | wc -l)"
    imgs_size_total="$(du -sh "$cache_dir/cache" | cut -f1)"
    echomessage "$imgs_count images ($imgs_size_total) in $cache_dir/cache"
    for directory in "$session_dir_256" "$session_dir_24bit" \
                     "$terminal_dir_256" "$terminal_dir_24bit"; do
        echomessage "$(ls -1 "$directory" | wc -l) instances in $directory"
    done
    broken_count=0
    for inst_file in "$session_dir_256"/*; do
        id="$(head -1 "$inst_file")"
        if [[ ! -e "$terminal_dir_256/$id" ]]; then
            ((broken_count++))
        fi
    done
    for inst_file in "$session_dir_24bit"/*; do
        id="$(head -1 "$inst_file")"
        if [[ ! -e "$terminal_dir_24bit/$id" ]]; then
            ((broken_count++))
        fi
    done
    if (( "$broken_count" > 0 )); then
        echomessage "There are $broken_count images that need fixing, try running:"
        echomessage "$script_name --fix"
    fi
    exit 0
fi

#####################################################################
# Handling the get-resolution command
#####################################################################

# Tries to infer rows_per_inch and cols_per_inch by querying the terminal and
# reading Xft.dpi
get_cells_per_inch() {
    cols_per_inch=""
    rows_per_inch=""
    # Query the terminal to get the dimensions of a cell in pixels
    echolog "Getting cell width and height"
    if [[ -n "$inside_tmux" ]]; then
        echo -en '\ePtmux;\e\e[16t\e\\' > "$tty"
    else
        echo -en '\e[16t' > "$tty"
    fi
    term_response=""
    if ! read -s -r -d 't' -t "$default_timeout" term_response < "$tty"; then
        invalid_terminal_response
        return 1
    fi
    local cell_width=""
    local cell_height=""
    read -r cell_height cell_width < \
        <(sed -n 's/.*6;\([0-9]*\);\([0-9]*\)/\1 \2/p' <<< "$term_response")
    if [[ -z "$cell_height" || -z "$cell_width" ]]; then
        invalid_terminal_response
        return 1
    fi
    echolog "cell width: $cell_width  cell height: $cell_height"

    # Using Xft.dpi as a sane value for screen resolution.
    screen_dpi="$(xrdb -query 2> /dev/null | grep 'Xft\.dpi:' | cut -f 2)"
    echolog "The value of Xft.dpi is $screen_dpi"
    if [[ -z "$screen_dpi" ]]; then
        screen_dpi=96
        echolog "Using 96 as the default screen resolution"
    fi
    cols_per_inch="$(bc <<< "scale=2;($screen_dpi)/($cell_width)")"
    rows_per_inch="$(bc <<< "scale=2;($screen_dpi)/($cell_height)")"
    echolog "cols per inch: $cols_per_inch  rows per inch: $rows_per_inch"
}

if [[ -n "$cmd_get_cells_per_inch" ]]; then
    get_cells_per_inch
    echo "$cols_per_inch $rows_per_inch $screen_dpi"
    exit $?
fi

#####################################################################
# Handling the reupload command
#####################################################################

reupload_instance() {
    local inst="$1"
    local id="$2"
    local inst_parts=($(echo "$inst" | tr "_" "\n"))
    local md5="${inst_parts[0]}"
    local cols="${inst_parts[1]}"
    local rows="${inst_parts[2]}"
    local cached_file="$cache_dir/cache/$md5"

    if [[ ! -e "$cached_file" ]]; then
        echoerr "Could not find the image in cache: $cached_file"
        return 1
    fi

    if (( "$id" < 256 )); then
        local session_dir="$session_dir_256"
        local terminal_dir="$terminal_dir_256"
    else
        local session_dir="$session_dir_24bit"
        local terminal_dir="$terminal_dir_24bit"
    fi

    upload_image "$id" "$cached_file" "$cols" "$rows" "$terminal_dir" "$inst"
    return $?
}

if [[ -n "$reupload" ]]; then
    reupload_ids_failed=()
    ids_left="$last_n"
    reupload_ids_specified=""
    [[ ${#reupload_ids[@]} == 0 ]] || reupload_ids_specified=1

    # Iterate over all image instances starting from the newest one and reupload
    # them if they are in `reupload_ids`.
    for inst_file in $(ls -t "$session_dir_256"/* "$session_dir_24bit"/*); do
        if [[ -n "$last_n" ]]; then
            if (( "$ids_left" == 0 )); then
                break
            fi
            ((ids_left--))
        fi
        inst="$(basename "$inst_file")"
        inst_parts=($(echo "$inst" | tr "_" "\n"))
        inst_cols="${inst_parts[1]}"
        inst_rows="${inst_parts[2]}"
        [[ -e "$inst_file" ]] || continue
        id="$(head -1 "$inst_file")"
        # If no ID list was specified, check if the id is known to be uploaded
        # to the terminal.
        if [[ -z "$reupload_ids_specified" ]]; then
            if [[ -n "$force_upload" ]] ||
                    ([[ ! -e "$terminal_dir_256/$id" ]] &&
                     [[ ! -e "$terminal_dir_24bit/$id" ]]) ||
                    image_needs_reuploading "$id" "$inst_cols" "$inst_rows"; then
                echomessage "Trying to reupload $inst with id $id ($(date -r "$inst_file"))"
                reupload_instance "$inst" "$id"
                if [[ $? -ne 0 ]]; then
                    reupload_ids_failed+=("$id")
                else
                    echomessage "Successfully reuploaded id $id"
                fi
            fi
            continue
        fi
        if [[ ${#reupload_ids[@]} == 0 ]]; then
            break
        fi
        # Otherwise check if the id is in the list of IDs to reupload.
        for idx in "${!reupload_ids[@]}"; do
            if [[ "${reupload_ids[idx]}" == "$id" ]]; then
                echomessage "Trying to reupload $inst with id $id"
                reupload_instance "$inst" "$id"
                if [[ $? -ne 0 ]]; then
                    reupload_ids_failed+=("$id")
                else
                    echomessage "Successfully reuploaded id $id"
                fi
                unset 'reupload_ids[idx]'
                break
            fi
        done
    done

    if [[ ${#reupload_ids_failed[@]} != 0 ]]; then
        echoerr "Reuploading failed for IDs: ${reupload_ids_failed[*]}"
        exit 1
    fi

    # If --last was specified, we can't reliably report non-found IDs.
    if [[ -z "$last_n" ]] && [[ ${#reupload_ids[@]} != 0 ]]; then
        echoerr "Could not find IDs: ${reupload_ids[*]}"
        exit 1
    fi

    echomessage "Successfully reuploaded all images"

    exit 0
fi

#####################################################################
# Handling the show id command
#####################################################################

if [[ -n "$cmd_show_id" ]]; then
    # If rows, columns and --no-upload are specified, just display the
    # placeholder.
    if [[ -n "$rows" && -n "$cols" && -n "$no_upload" ]]; then
        display_image "$cmd_show_id" "$cols" "$rows"
        exit 0
    fi

    if (( "$cmd_show_id" < 256 )); then
        use_256="1"
    else
        use_256=""
    fi

    if [[ -n "$use_256" ]]; then
        session_dir="$session_dir_256"
        terminal_dir="$terminal_dir_256"
    else
        session_dir="$session_dir_24bit"
        terminal_dir="$terminal_dir_24bit"
    fi

    if [[ -z "$force_upload" ]] && [[ -e "$terminal_dir/$cmd_show_id" ]]; then
        instance="$(head -1 "$terminal_dir/$cmd_show_id")"
        if [[ -z "$instance" ]]; then
            echoerr "File $terminal_dir/$cmd_show_id exists but is empty"
        fi
    fi

    if [[ -z "$instance" ]]; then
        for inst_file in "$session_dir"/*; do
            [[ -e "$inst_file" ]] || continue
            [[ "$(head -1 "$inst_file")" == "$cmd_show_id" ]] || continue
            instance="$(basename "$inst_file")"
            if [[ -z "$no_upload" ]]; then
                reupload_instance "$instance" "$cmd_show_id"
            fi
            break
        done
    fi

    if [[ -z "$instance" ]]; then
        echoerr "Could not find image with id $cmd_show_id"
        exit 1
    fi

    inst_parts=($(echo "$instance" | tr "_" "\n"))
    md5="${inst_parts[0]}"
    [[ -n "$cols" ]] || cols="${inst_parts[1]}"
    [[ -n "$rows" ]] || rows="${inst_parts[2]}"
    display_image "$cmd_show_id" "$cols" "$rows"
    exit 0
fi

#####################################################################
# Handling the ls command
#####################################################################

if [[ -n "$cmd_list_images" ]]; then
    ids_left="$last_n"
    # Iterate over all image instances starting from the newest one.
    for inst_file in $(ls -t "$session_dir_256"/* "$session_dir_24bit"/*); do
        if [[ -n "$last_n" ]]; then
            if (( "$ids_left" == 0 )); then
                break
            fi
            ((ids_left--))
        fi
        if [[ ! -e "$inst_file" ]]; then
            echoout "File doesn't exist: $inst_file"
            continue
        fi
        inst="$(basename "$inst_file")"
        inst_parts=($(echo "$inst" | tr "_" "\n"))
        md5="${inst_parts[0]}"
        im_cols="${inst_parts[1]}"
        im_rows="${inst_parts[2]}"
        id="$(head -1 "$inst_file")"
        echoout "id: $id  cols: $im_cols  rows: $im_rows  md5sum: $md5"
        if [[ ! -e "$terminal_dir_256/$id" ]] &&
                [[ ! -e "$terminal_dir_24bit/$id" ]]; then
            echoout "$(tput bold)IMAGE NEEDS REUPLOADING!$(tput sgr0)"
        fi
        [[ -n "$cols" ]] && im_cols="$cols"
        [[ -n "$rows" ]] && im_rows="$rows"
        display_image "$id" "$im_cols" "$im_rows"
        echoout ""
    done
    exit 0
fi

#####################################################################
# Compute the number of rows and columns
#####################################################################

# Check if the file exists.
if [[ -z "$file" ]]; then
    echoerr "File not specified"
    exit 1
fi
if ! [[ -f "$file" ]]; then
    echoerr "File not found: $file (pwd: $(pwd))"
    exit 1
fi

echolog "Image file: $file (pwd: $(pwd))"

# Compute a formula with bc and round to the nearest integer.
bc_round() {
    echo "$(LC_NUMERIC=C printf %.0f "$(echo "scale=2;($1) + 0.5" | bc)")"
}

if [[ -z "$cols" || -z "$rows" ]]; then
    # Default values of rows per inch and columns per inch.
    [[ -n "$cols_per_inch" ]] || cols_per_inch=12.0
    [[ -n "$rows_per_inch" ]] || rows_per_inch=6.0
    # Get the size of the image and its resolution
    props=($(identify -format '%w %h %x %y' -units PixelsPerInch "$file"))
    if [[ "${#props[@]}" -ne 4 ]]; then
        echoerr "Couldn't get result from identify"
        exit 1
    fi
    if [[ -n "$override_ppi" ]]; then
        props[2]="$override_ppi"
        props[3]="$override_ppi"
    fi
    echolog "Image pixel width: ${props[0]} pixel height: ${props[1]}"
    echolog "Image x ppi: ${props[2]} y ppi: ${props[3]}"
    echolog "Columns per inch: ${cols_per_inch} Rows per inch: ${rows_per_inch}"
    opt_cols_expr="(${props[0]}*${cols_per_inch}/${props[2]})"
    opt_rows_expr="(${props[1]}*${rows_per_inch}/${props[3]})"
    cols_auto_computed=""
    rows_auto_computed=""
    if [[ -z "$cols" && -z "$rows" ]]; then
        # If columns and rows are not specified, compute the optimal values
        # using the information about rows and columns per inch.
        cols="$(bc_round "$opt_cols_expr")"
        rows="$(bc_round "$opt_rows_expr")"
        cols_auto_computed=1
        rows_auto_computed=1
    elif [[ -z "$cols" ]]; then
        # If only one dimension is specified, compute the other one to match the
        # aspect ratio as close as possible.
        cols="$(bc_round "${opt_cols_expr}*${rows}/${opt_rows_expr}")"
        cols_auto_computed=1
    elif [[ -z "$rows" ]]; then
        rows="$(bc_round "${opt_rows_expr}*${cols}/${opt_cols_expr}")"
        rows_auto_computed=1
    fi

    echolog "Image size before applying min/max columns: $cols, rows: $rows"
    # Make sure that automatically computed rows and columns are within some
    # sane limits
    if [[ -n "$cols_auto_computed" ]] && (( cols > max_cols )); then
        rows="$(bc_round "$rows * $max_cols / $cols")"
        cols="$max_cols"
    fi
    if [[ -n "$rows_auto_computed" ]] && (( rows > max_rows )); then
        cols="$(bc_round "$cols * $max_rows / $rows")"
        rows="$max_rows"
    fi
    if (( cols < 1 )); then
        cols=1
    fi
    if (( rows < 1 )); then
        rows=1
    fi
fi

rows="$((10#$rows))"
cols="$((10#$cols))"

echolog "Image size columns: $cols, rows: $rows"

# Save the number of rows and columns.
[[ -z "$save_info" ]] || echo -e "columns\t$cols\nrows\t$rows" >> "$save_info"

#####################################################################
# Helper functions for finding image ids
#####################################################################

# Checks if the given string is an integer within the correct id range.
is_image_id_correct() {
    if [[ "$1" =~ ^[0-9]+$ ]]; then
        if [[ -n "$use_256" ]]; then
            if (( "$1" < 256 )) && (( "$1" > 0 )); then
                return 0
            fi
        else
            if (( "$1" >= 256 )) && (( "$1" < 16777216 )); then
                return 0
            fi
        fi
    fi
    echoerr "$1 is incorrect"
    return 1
}

# Finds an image id for the instance $img_instance.
find_image_id() {
    local inst_file
    # Try to find an existing session image id corresponding to the instance.
    inst_file="$session_dir/$img_instance"
    if [[ -e "$inst_file" ]]; then
        image_id="$(head -1 "$inst_file")"
        if ! is_image_id_correct "$image_id"; then
            echoerr "Found invalid image_id $image_id in $inst_file, please remove it manually"
            return 1
        else
            touch "$inst_file"
            echolog "Found an existing image id $image_id"
            return 0
        fi
    fi
    # If there is no image id corresponding to the instance, try to find a free
    # image id.
    if [[ -n "$use_256" ]]; then
        local id
        local ids_array=($(seq 0 255))
        # Load ids and mark occupied ids with "0" (0 is an invalid id anyway).
        for inst_file in "$session_dir"/*; do
            id="$(head -1 "$inst_file")"
            if ! is_image_id_correct "$id"; then
                echoerr "Found invalid image_id $id in $inst_file, please remove it manually"
                return 1
            else
                ids_array[$id]="0"
            fi
        done
        # Try to find an array element that is not "0".
        for id in "${ids_array[@]}"; do
            if [[ "$id" != "0" ]]; then
                image_id="$id"
                echolog "Found a free image id $image_id"
                return 0
            fi
        done
        # On failure we need to reassign the id of the oldest image.
        local oldest_file=""
        for inst_file in "$session_dir"/*; do
            if [[ -z $oldest_file || $inst_file -ot $oldest_file ]]; then
                oldest_file="$inst_file"
            fi
        done
        image_id="$(head -1 "$inst_file")"
        echolog "Recuperating the id $image_id from $oldest_file"
        rm "$oldest_file"
        return 0
    else
        local ids_array=()
        # Load ids into the array.
        for inst_file in "$session_dir"/*; do
            id="$(head -1 "$inst_file")"
            if ! is_image_id_correct "$id"; then
                echoerr "Found invalid image_id $id in $inst_file, please remove it manually"
                return 1
            else
                ids_array+=("$id")
            fi
        done
        image_id=""
        # Generate a random id until we find one that is not in use.
        while [[ -z "$image_id" ]]; do
            image_id="$(shuf -i 256-16777215 -n 1)"
            # Check that the id is not in use
            for id in "${ids_array[@]}"; do
                if [[ "$image_id" == "$id" ]]; then
                    image_id=""
                    break
                fi
            done
        done
        return 0
    fi
}

#####################################################################
# Assigning the image id
#####################################################################

# If the id is explicitly specified, set the $use_256 variable accordingly and
# then check that the id is correct.
if [[ -n "$image_id" ]]; then
    if (( "$image_id" < 256 )); then
        use_256="1"
    else
        use_256=""
    fi
    if ! is_image_id_correct "$image_id"; then
        echoerr "The specified image id $image_id is not correct"
        exit 1
    fi
fi

# 8-bit and 24-bit image ids live in different namespaces. We use different
# session and terminal directories to store information about them.
if [[ -n "$use_256" ]]; then
    session_dir="$session_dir_256"
    terminal_dir="$terminal_dir_256"
else
    session_dir="$session_dir_24bit"
    terminal_dir="$terminal_dir_24bit"
fi

# Compute md5sum and copy the file to the cache dir.
img_md5="$(md5sum "$file" | cut -f 1 -d " ")"
echolog "Image md5sum: $img_md5"

cached_file="$cache_dir/cache/$img_md5"
if [[ ! -e "$cached_file" ]]; then
    cp "$file" "$cached_file"
else
    touch "$cached_file"
fi

# Use the cached file instead of file now
file="$cached_file"

# Image instance is an image with its positioning attributes: columns, rows and
# any other attributes we may add in the future (alignment, scale mode, etc).
# Each image id corresponds to a single image instance.
img_instance="${img_md5}_${cols}_${rows}"

if [[ -n "$image_id" ]]; then
    echolog "Using the specified image id $image_id"
    (
        flock --timeout "$default_timeout" 9 || \
            { echoerr "Could not acquire a lock on $session_dir.lock"; exit 1; }
        # If there is already an image with this id, it must be forgotten.
        for inst_file in "$session_dir"/*; do
            id="$(head -1 "$inst_file")"
            if (( "$id" == "$image_id" )); then
                echolog "Removing $inst_file to avoid id clash"
                rm "$inst_file"
            fi
        done
        echo "$image_id" > "$session_dir/$img_instance"
    ) 9>"$session_dir.lock" || exit 1
else
    # Find an id for the image. We want to avoid reuploading, and at the same
    # time we want to minimize image id collisions.
    echolog "Searching for a free image id"
    (
        flock --timeout "$default_timeout" 9 || \
            { echoerr "Could not acquire a lock on $session_dir.lock"; exit 1; }
        # Find the image id (see the function definition below).
        image_id=""
        find_image_id
        if [[ -z "$image_id" ]]; then
            echoerr "Failed to find an image id"
            exit 1
        fi
        # If it hasn't been loaded, create the instance file.
        if [[ ! -e "$session_dir/$img_instance" ]]; then
            echo "$image_id" > "$session_dir/$img_instance"
        fi
    ) 9>"$session_dir.lock" || exit 1

    image_id="$(head -1 "$session_dir/$img_instance")"

    echolog "Found an image id $image_id"
fi

# Save the image id and md5sum.
[[ -z "$save_info" ]] || echo -e "id\t$image_id\nmd5sum\t$img_md5" >> "$save_info"

#####################################################################
# Image uploading
#####################################################################

if [[ -z "$no_upload" ]]; then
    # Check if this instance has already been uploaded to this terminal with the
    # found image id.
    # TODO: Also check date and reupload if too old.
    if [[ -z "$force_upload" ]] &&
       [[ -e "$terminal_dir/$image_id" ]] &&
       [[ "$(head -1 "$terminal_dir/$image_id")" == "$img_instance" ]] &&
       ! image_needs_reuploading "$image_id" "$cols" "$rows"; then
        echolog "Image already uploaded"
    else
        upload_image "$image_id" "$cached_file" "$cols" "$rows" \
            "$terminal_dir" "$img_instance"
    fi
fi

#####################################################################
# Maybe clean the cache from time to time
#####################################################################

if (( $RANDOM % 100 < "$cleanup_probability" )); then
    echostatus "Cleaning up the cache dir"
    cleanup_cache
fi

#####################################################################
# Printing the image placeholder
#####################################################################

display_image "$image_id" "$cols" "$rows"
echolog "Finished displaying the image"
exit 0
