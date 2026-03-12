
_GRIM_COLOR_RESET=$'\033[0m'
_GRIM_COLOR_YELLOW=$'\033[33m'
_GRIM_COLOR_RED=$'\033[31m'

grim_message_warn() {
    echo "${_GRIM_COLOR_YELLOW}[WARN]${_GRIM_COLOR_RESET} $1" >&2
}

grim_message_error() {
    echo "${_GRIM_COLOR_RED}[ERROR]${_GRIM_COLOR_RESET} $1" >&2
}


