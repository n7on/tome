# Writing a rig pack

A pack is a git repository with the following layout:

```
rig-weather/
├── src/
│   └── weather/
│       ├── weather.bash
│       └── python/         — optional Python scripts
├── requirements.txt        — optional Python dependencies
```

Install it with:

```bash
rig pack install https://github.com/you/rig-weather
```

## Project structure (core reference)

```
bin/rig                — binary entry point
src/
├── _cache/             — cache implementation
├── _complete/          — completion registration
├── _config/            — module config helpers
├── _exec/              — command execution helpers
├── _message/           — warn/error output
├── _module/            — module loader (_require_module)
├── _output/            — output rendering (table, json, tsv, md, raw)
│   └── python/         — render.py
└── _param/             — parameter declaration and parsing
~/.rig/
├── pack/               — installed packs
├── <namespace>/        — per-module config files (JSON)
└── .cache/             — cached command output
```

## Anatomy of a command

Functions are named `<namespace>_<action>`, e.g. `weather_forecast`, `weather_current`.

```bash
weather_forecast() {
    _description "Show weather forecast for a location"
    _requires curl || return 1

    _param location --required --positional --help "City name or coordinates"
    _param days     --default 3 --help "Number of days"
    _param_parse "$@" || return 1

    _exec curl -s "https://wttr.in/$location?format=j1" \
        | json_tsv --path 'weather' --fields 'date=date,max=maxtempC,min=mintempC' \
        | _output_render "date,max,min"
}

_complete_params "weather_forecast" "location" "days"
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

## Output rendering

Commands produce TSV and pipe it through `_output_render`:

```bash
some_command | awk '{print $1 "\t" $2}' | _output_render "name,value"
```

The renderer handles `--output_format`, `--filter`, `--sort`, `--select`, and `--limit` automatically.

If your data already includes a header row (e.g. from a Python script), omit the argument:

```bash
_exec_python mymodule extract.py "$arg" | _output_render
```

## Running external commands

```bash
# Run a command (with caching and stderr capture)
_exec curl -s "$url"

# Run a Python script from src/<namespace>/python/
_exec_python weather forecast.py "$arg"
```

Both respect `--cache` automatically.

## Checking dependencies

```bash
_requires curl jq || return 1
```

## Tab completion

Register each command at file scope (outside the function body):

```bash
# List the parameter names the command accepts
_complete_params "weather_forecast" "location" "days"

# Static value list for a parameter
_complete_values "weather_forecast" "days" 1 3 7 14

# Dynamic completer function (prints one value per line)
_weather_location_complete() {
    printf '%s\n' "London" "New York" "Tokyo"
}
_complete_func "weather_forecast" "location" _weather_location_complete
```

## Python scripts

Put Python scripts in `src/<namespace>/python/` and call them with `_exec_python`:

```bash
_exec_python weather forecast.py "$location" "$days" | _output_render
```

Scripts should write TSV (with a header row) to stdout. Use `print(..., file=sys.stderr)` for warnings.

## Module config

For commands that need configuration, store it as JSON in `~/.rig/<namespace>/<module>.json`. Use `_config_init` to create it from an example on first use:

```bash
# At file scope in your module
_config_init weather config
```

This copies `src/weather/config.json.example` to `~/.rig/weather/config.json` on first use.

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
    _description "Show weather forecast for a location"
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

_complete_params "weather_forecast" "location" "days"
_complete_func   "weather_forecast" "location" _weather_complete_location
```

```bash
rig weather forecast London                          # table (default)
rig weather forecast London --output_format json     # JSON array
rig weather forecast London --days 7 --filter max~2  # filtered
rig weather forecast London --cache 3600             # cached for 1 hour
rig weather forecast --help                          # show parameter help
```
