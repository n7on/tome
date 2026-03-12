# Source environment variables
[[ -f "$(dirname "${BASH_SOURCE[0]}")/.env" ]] && source "$(dirname "${BASH_SOURCE[0]}")/.env"

# Source library
source "$(dirname "${BASH_SOURCE[0]}")/lib/io.sh"

# Source domain modules
for file in "$(dirname "${BASH_SOURCE[0]}")"/*/*.sh; do
    [[ "$file" != *"/lib/"* ]] && source "$file"
done
