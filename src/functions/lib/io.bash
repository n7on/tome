

# Color codes
_COLOR_RESET=$'\033[0m'
_COLOR_BLUE=$'\033[34m'
_COLOR_YELLOW=$'\033[33m'
_COLOR_RED=$'\033[31m'

function io_timestamp() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')]"
}

function io_info() {
    echo "${_COLOR_BLUE}$(io_timestamp) [INFO]${_COLOR_RESET} $1"
}

function io_warn() {
    echo "${_COLOR_YELLOW}$(io_timestamp) [WARN]${_COLOR_RESET} $1" >&2
}

function io_error() {
    echo "${_COLOR_RED}$(io_timestamp) [ERROR]${_COLOR_RESET} $1" >&2
}

function io_die() {
    io_error "$1"
    exit 1
}