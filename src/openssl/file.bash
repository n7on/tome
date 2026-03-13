# Encrypt a file using AES-256-CBC
# Usage: openssl_file_encrypt --input secret.txt --output secret.enc --password mypass
openssl_file_encrypt() {
    _grim_command_requires openssl || return 1

    _grim_command_init input output password cipher=aes-256-cbc
    _grim_command_parse "$@"

    _grim_command_validate input --required --path file || return 1
    _grim_command_validate password --required || return 1

    _grim_command_default output "${input}.enc"

    local cmd=(openssl enc -"${cipher}" -salt -pbkdf2 -in "$input" -out "$output" -pass "pass:${password}")

    _grim_command_run "${cmd[@]}"
}

# Decrypt a file using AES-256-CBC
# Usage: openssl_file_decrypt --input secret.enc --output secret.txt --password mypass
openssl_file_decrypt() {
    _grim_command_requires openssl || return 1

    _grim_command_init input output password cipher=aes-256-cbc
    _grim_command_parse "$@"

    _grim_command_validate input --required --path file || return 1
    _grim_command_validate password --required || return 1

    _grim_command_default output "${input%.enc}"

    local cmd=(openssl enc -d -"${cipher}" -pbkdf2 -in "$input" -out "$output" -pass "pass:${password}")

    _grim_command_run --error "Decryption failed: wrong password or corrupted file" "${cmd[@]}"
}

_grim_command_set_params "openssl_file_encrypt" "input" "output" "password" "cipher"
_grim_command_set_params "openssl_file_decrypt" "input" "output" "password" "cipher"

_grim_command_set_values "openssl_file_encrypt" "cipher" \
    "aes-256-cbc" "aes-128-cbc"
_grim_command_set_values "openssl_file_decrypt" "cipher" \
    "aes-256-cbc" "aes-128-cbc"
