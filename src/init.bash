for file in "$(dirname "${BASH_SOURCE[0]}")"/../.env*; do
    source "$file"
done

# Source grim utilities first (dependencies)
for file in "$(dirname "${BASH_SOURCE[0]}")/grim"/*.bash; do
    source "$file"
done

# Then source other function modules (excluding grim)
for dir in "$(dirname "${BASH_SOURCE[0]}")"/*; do
    [[ -d "$dir" && "$(basename "$dir")" != "grim" ]] || continue
    for file in "$dir"/*.bash; do
        source "$file"
    done
done
