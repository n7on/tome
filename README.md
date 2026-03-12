# Grim

A lightweight bash framework for clean CLI tools with parameters, validation, logging, and auto-completion.

## Quick Start

```bash
source src/init.bash
```

## Hello World Example

```bash
greet() {
    _grim_command_init name greeting="Hello"
    _grim_command_parse "$@"
    
    _grim_command_validate name --required || return 1
    
    _grim_log_info "$greeting, $name!"
}

_grim_command_set_complete "greet" "name"
_grim_command_set_complete "greet" "greeting"
```

**Usage:**
```bash
greet --name World              # Hello, World!
greet --name Alice --greeting Hi # Hi, Alice!
greet --<TAB>                   # auto-completes --name and --greeting
```

## Core Functions

**Parameters:**
- `_grim_command_init param1 param2=default` — Declare parameters
- `_grim_command_parse "$@"` — Parse arguments into variables
- `_grim_command_validate param --required --regex "pattern"` — Validate

**Logging:**
- `_grim_log_info "message"` — Blue info message
- `_grim_log_warn "message"` — Yellow warning
- `_grim_log_error "message"` — Red error
- `_grim_log_die "message"` — Error and exit

**Other:**
- `_grim_command_set_complete "func" "param" "completer_func"` — Register completion
- `_grim_command_requires jq az` — Check dependencies exist
- `_grim_command_filter "item1 item2" "$prefix"` — Filter completion items

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
├── init.bash                  # Source this first
├── grim/
│   ├── command.bash          # Parameter & validation
│   └── log.bash              # Logging
└── ms/                        # Your modules
    ├── az.bash              
    └── ado.bash
```

Add new modules in `src/` — they load automatically.
