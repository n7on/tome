# Encrypt a file using AES-256-CBC
# Usage: openssl_encrypt_file --input secret.txt --output secret.enc --password mypass
openssl_encrypt_file() {
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
# Usage: openssl_encrypt_decrypt --input secret.enc --output secret.txt --password mypass
openssl_encrypt_decrypt() {
    _grim_command_requires openssl || return 1

    _grim_command_init input output password cipher=aes-256-cbc
    _grim_command_parse "$@"

    _grim_command_validate input --required --path file || return 1
    _grim_command_validate password --required || return 1

    _grim_command_default output "${input%.enc}"

    local cmd=(openssl enc -d -"${cipher}" -pbkdf2 -in "$input" -out "$output" -pass "pass:${password}")

    _grim_command_run "${cmd[@]}"
}

_grim_command_set_params "openssl_encrypt_file" "input" "output" "password" "cipher"
_grim_command_set_params "openssl_encrypt_decrypt" "input" "output" "password" "cipher"

_grim_command_set_values "openssl_encrypt_file" "cipher" \
    "aes-256-cbc" "aes-128-cbc" "aes-256-gcm" "chacha20-poly1305"
_grim_command_set_values "openssl_encrypt_decrypt" "cipher" \
    "aes-256-cbc" "aes-128-cbc" "aes-256-gcm" "chacha20-poly1305"
