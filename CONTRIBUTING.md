# Contributing

## Project structure

```
setup.bash              — one-time setup (creates venv, installs Python deps)
bin/tome                — binary entry point
init.bash               — sources all modules (used by bin/tome)
src/
├── _cache/             — cache implementation
├── _complete/          — completion registration
├── _config/            — module config helpers
├── _exec/              — command execution helpers
├── _message/           — warn/error output
├── _output/            — output rendering (table, json, tsv, md, raw)
│   └── python/         — render.py
└── _param/             — parameter declaration and parsing
src/<namespace>/        — command modules (azure/, nmap/, note/, ...)
├── <module>.bash       — command definitions
└── python/             — Python scripts called from commands
~/.tome/
├── <namespace>/        — per-module config files (JSON)
└── .cache/             — cached command output
```

## Creating a module

Create a directory under `src/` and add a `.bash` file. It will be loaded automatically.

```
src/
└── weather/
    └── weather.bash
```

Functions are named `<namespace>_<action>`, e.g. `weather_forecast`, `weather_current`.

## Anatomy of a command

```bash
weather_forecast() {
    _requires curl || return 1

    _param location --required --positional --help "City name or coordinates"
    _param days     --default 3 --help "Number of days"
    _param_parse "$@" || return 1

    _exec curl -s "https://wttr.in/$location?format=j1" \
        | json_tsv --path 'weather' --fields 'date=date,max=maxtempC,min=mintempC' \
        | _output_render "date,max,min"
}

_complete_params "weather_forecast" "Show weather forecast" "location" "days"
```

## Parameter declaration

Declare parameters inside the function body, before `_param_parse`:

```bash
_param <name> [options...]
```

| Option | Description |
| --- | --- |
| `--required` | Fail with an error if not provided |
| `--positional` | Accept as the first non-flag argument |
| `--default <value>` | Default value if not provided |
| `--help "<text>"` | Description shown in `--help` output |
| `--regex "<pattern>"` | Validate value against a regex |
| `--path file\|dir` | Validate that the value is an existing file or directory |

After declaring parameters, always call:

```bash
_param_parse "$@" || return 1
```

This parses flags, assigns positional args, validates, and exports each parameter as a local variable.

## Output rendering

Commands produce TSV and pipe it through `_output_render`:

```bash
# Pass column headers as a comma-separated string
some_command | awk '{print $1 "\t" $2}' | _output_render "name,value"
```

The renderer handles `--output`, `--filter`, `--sort`, `--select`, and `--limit` automatically.

If your data already includes a header row (e.g. from a Python script), omit the argument:

```bash
_exec_python mymodule extract.py "$arg" | _output_render
```

## Running external commands

```bash
# Run a command with caching and stderr capture
_exec curl -s "$url"

# Run a Python script from src/<namespace>/python/
_exec_python azure extract.py "$arg"
```

Both respect `--cache` automatically.

## Checking dependencies

```bash
_requires curl jq nmap || return 1
_requires_az_extension resource-graph || return 1
```

## Caching

The `--cache` flag is handled transparently by `_exec` and `_exec_python`. No extra work needed in commands.

Users can pass `--cache` (uses 300s default) or `--cache <seconds>` for a custom TTL.

## Tab completion

Register each command at file scope (outside the function body):

```bash
# Basic: list the parameter names the command accepts
_complete_params "weather_forecast" "Show weather forecast" "location" "days"

# Static value list for a parameter
_complete_values "weather_forecast" "days" 1 3 7 14

# Dynamic completer function (prints one value per line)
_weather_location_complete() {
    printf '%s\n' "London" "New York" "Tokyo"
}
_complete_func "weather_forecast" "location" _weather_location_complete
```

`_complete_params` takes the function name, a description, and the parameter names the command uses. The framework params (`--output`, `--filter`, `--sort`, etc.) are included automatically.

## Python scripts

For complex data transforms, put Python scripts in `src/<namespace>/python/` and call them with `_exec_python`:

```bash
_exec_python weather forecast.py "$location" "$days" \
    | _output_render
```

Scripts should write TSV (with a header row) to stdout. Use `print(..., file=sys.stderr)` for warnings — tome will show them only on failure or with `--debug`.

## Module config files

For modules that need configuration, store it as JSON in `~/.tome/<namespace>/<module>.json`. Use `_config_init` to create it from an example on first use:

```bash
# At file scope in your module
_config_init weather config
```

This copies `src/weather/config.json.example` to `~/.tome/weather/config.json` on first use.

Read and write config values with:

```bash
local api_key
api_key=$(_config_get weather config api_key)

_config_set weather config api_key "$new_key"
```

## Messages

```bash
_message_warn "Something looks off"    # yellow [WARN] to stderr
_message_error "Something went wrong"  # red [ERROR] to stderr
```

## Full example

```bash
# src/weather/weather.bash

weather_forecast() {
    _requires curl || return 1

    _param location --required --positional --help "City name"
    _param days     --default 3             --help "Number of days to show"
    _param_parse "$@" || return 1

    _exec curl -s "https://wttr.in/${location}?format=j1" \
        | json_tsv --path 'weather' --fields 'date=date,max=maxtempC,min=mintempC' \
        | _output_render "date,max,min"
}

_weather_complete_location() {
    printf '%s\n' "London" "Paris" "Tokyo" "New York"
}

_complete_params "weather_forecast" "Show weather forecast" "location" "days"
_complete_func   "weather_forecast" "location" _weather_complete_location
```

```bash
weather_forecast London                          # table (default)
weather_forecast London --output json            # JSON array
weather_forecast London --days 7 --filter max~2  # filtered
weather_forecast London --cache 3600             # cached for 1 hour
weather_forecast --help                          # show parameter help
```
