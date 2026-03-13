# Grim

A lightweight bash framework for clean CLI tools with parameters, validation, logging, and auto-completion.

## Quick Start

```bash
# Source the framework
source src/init.bash
```
## Hello World Example

```bash
# Custom completer: suggest system users for --name
_greet_user_completer() {
    compgen -u -- "$1"
}

greet() {
    _grim_command_init name greeting="Hello"
    _grim_command_parse "$@"
    _grim_command_validate name --required || return 1
    _grim_command_output_set "greeting,name" '{print greeting "\t" name}'
    _grim_command_run printf "%s\t%s\n" "$greeting" "$name" | _grim_command_output_render
}

# Register parameters and completions
_grim_command_set_params greet name greeting
_grim_command_set_completer greet name _greet_user_completer
_grim_command_set_values greet greeting Hello Hi Hey

# (Optional) You always get --output_format and --dry_run for free
# _grim_command_set_values greet output_format table json csv
# _grim_command_set_values greet dry_run true false
```

**Usage:**
```bash
source src/init.bash
greet --name World                # [INFO] Hello, World!
greet --name Alice --greeting Hi  # [INFO] Hi, Alice!
greet --name <TAB>                # auto-completes system users for --name
greet --greeting <TAB>            # auto-completes: Hello, Hi, Hey
greet --output_format <TAB>       # auto-completes: table, json, csv
greet --output_format json        # {"greeting": "Hello", "name": "World"}
greet --output_format csv         # greeting,name\nHello,World
greet --dry_run true              # dry run mode
```

## Core Functions

**Parameters & Registration:**
- `_grim_command_init param1 param2=default` — Declare parameters (adds output_format, dry_run by default)
- `_grim_command_parse "$@"` — Parse arguments into variables
- `_grim_command_set_params func param1 param2 ...` — Register parameters for completion
- `_grim_command_set_values func param value1 value2 ...` — Static completions
- `_grim_command_set_completer func param completer_func` — Function completions
- `_grim_command_validate param --required --regex "pattern" --path [file|dir]` — Validate
- `_grim_command_requires jq az` — Check dependencies exist
- `_grim_command_filter "item1 item2" "$prefix"` — Filter completion items

**Messages:**
- `_grim_log_warn "message"`
- `_grim_log_error "message"`

## Configuration

Create `.env`:
```bash
cp example.env .env
# Edit with your values
```

All `*.env` files are sourced automatically.

## Project Structure

```
src/
├── init.bash
├── grim/
│   ├── command.bash
│   └── log.bash
└── module_namespace/
    ├── module1.bash              
    └── module2.bash
```
Add new modules in `src/` — they load automatically when sourced via `src/init.bash`. Modules are named after their position in the project structure. So in this example, module1 functions would be named `module_namespace.module1.function_name`



