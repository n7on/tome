
_COLOR_RESET=$'\033[0m'
_COLOR_YELLOW=$'\033[33m'
_COLOR_RED=$'\033[31m'

_message_warn() {
    echo "${_COLOR_YELLOW}[WARN]${_COLOR_RESET} $1" >&2
}

_message_error() {
    echo "${_COLOR_RED}[ERROR]${_COLOR_RESET} $1" >&2
}
