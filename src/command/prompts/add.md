**You are writing commands for `jig`, a bash CLI framework. A "command" is just a bash function. Layout and conventions below are authoritative — follow them exactly.**

## Pack layout

```
<pack-name>/
├── src/
│   └── <namespace>/
│       ├── <namespace>.bash        # command definitions
│       ├── python/                 # optional python scripts
│       └── <module>.json.example   # optional config seed
├── requirements.txt                # optional python deps
├── shell.bash / shell.zsh          # optional extra completion glue
```

Installed to `~/.jig/pack/<pack>/`. Per-user config lives at `~/.jig/<namespace>/<module>.json`.

## Function naming

- `<namespace>_<action>` → invoked as `jig <namespace> <action>`
- `<namespace>_<group>_<action>` → invoked as `jig <namespace> <group> <action>` (longest match wins)
- Any function starting with `_` is private and not dispatchable.

## File placement

The function name determines which `.bash` file it lives in:

- `<ns>_<action>` (two segments)           → `src/<ns>/<ns>.bash`
- `<ns>_<group>_<action>...` (three or more) → `src/<ns>/<group>.bash`

Examples: `pack_install` → `src/pack/pack.bash`; `git_repo_list` → `src/git/repo.bash`; `foo_bar_hello` → `src/foo/bar.bash`.

**Do not include a file-path header comment** (e.g. `# src/foo/foo.bash`). The wrapper places the code in the correct file based on the function name; a hardcoded path comment will be wrong or misleading.

## Command skeleton

```bash
namespace_action() {
    _description "One-line description shown in --help and command list"
    _requires curl jq || return 1          # optional; bail if tools missing

    _param target --required --positional --help "Target host"
    _param ports  --default "1-1000" --regex "^[0-9,.-]+$" --help "Port range"
    _param_parse "$@" || return 1          # MUST be called after all _param

    # $target, $ports are now set as locals from parsed flags/positional
    _exec curl -s "https://example.com/$target" \
        | json_tsv --path 'results' --fields 'name=displayName,port' \
        | _output_render "name,port"
}
```

## `_param` options

| Option | Meaning |
| --- | --- |
| `--required` | Error if missing |
| `--positional` | First bare (non-`--`) arg(s) map here |
| `--default <v>` | Default value |
| `--help "<text>"` | Help text |
| `--regex "<pat>"` | Validate against regex |
| `--path file\|dir` | Validate path exists |

`_param_parse "$@" || return 1` parses flags, exports each param as a shell variable with its param name, and validates.

## File-scope completion registration (outside the function)

**`_complete_params` is mandatory for every command** — even one with zero user parameters. It registers the command's `--help`/`--debug` flags (and for query commands the `--output`/`--filter`/... flags) and makes the command discoverable by `jig command show`. A command without it will be invocable but won't appear in introspection or tab-completion properly.

```bash
_complete_type   "namespace_action" query|action     # optional: default is query
_complete_params "namespace_action" "target" "ports" # REQUIRED — list every user param (empty list is fine)
_complete_values "namespace_action" "ports" "80" "443" "8080"
_complete_func   "namespace_action" "target" _my_target_completer
_complete_positional "namespace_action" _my_target_completer
_complete_path   "namespace_action" "file" file      # file|dir
```

For a command with no parameters: `_complete_params "namespace_action"` (no extra args). Still required.

`_my_target_completer` is a function that prints one candidate per line and receives the current partial word as `$1`.

**`query` vs `action`** — `_complete_type` controls which built-in flags get auto-registered:
- `query` (default): adds `--output` (table/json/tsv/md/raw), `--cache`, `--filter`, `--sort`, `--select`, `--limit`, plus `--debug`/`--help`.
- `action`: only `--debug`/`--help`. Use for commands that mutate state (install/remove/set).

Those auto-registered flags are also available as shell variables inside the function: `$output`, `$cache`, `$filter`, `$sort`, `$select`, `$limit`, `$debug`.

## Output

Commands emit TSV and pipe through `_output_render`:

```bash
... | _output_render "col1,col2,col3"   # explicit headers
... | _output_render                    # data's first line IS the header
```

The renderer applies `--output`/`--filter`/`--sort`/`--select`/`--limit` automatically.

## Running external work

```bash
_exec curl -s "$url"                           # respects $cache, captures stderr
_exec_python <namespace> script.py arg1 arg2   # runs src/<ns>/python/script.py via ~/.jig/.venv
```

Python scripts should print TSV with a header row to stdout; warnings to stderr. Both helpers honor `--cache`.

## JSON helpers (callable from any command)

```bash
echo "$json" | json_get   --path 'a.b.0.id'
echo "$json" | json_tsv   --path 'items'      --fields 'name=displayName,id'
echo "$json" | json_kv    --path '.'
echo "$json" | json_find  --path 'roles' --where 'value' --equals 'User.Read' --return 'id'
json_build 'name=foo' 'int:count=42' [--base "$existing_json"]
json_set    --file x.json --key 'host' --value 'localhost'
json_append --file x.json --item '{"id":"abc"}'
json_remove --file x.json --match 'id' --value 'abc'
```

If your module uses them, add `_require_module "json"` at the top of the file.

## Module-level config

`src/<ns>/<module>.json.example` is copied to `~/.jig/<ns>/<module>.json` on first install or via `_config_init <ns> <module>` (called at file scope). Read/write it with:

```bash
_config_get    <ns> <module> <key>
_config_set    <ns> <module> <key> <value>
_config_append <ns> <module> <json-object>
_config_remove <ns> <module> <field> <value>
_config_list   <ns> <module> <fields>
```

## Messages

```bash
_message_warn  "heads up"     # yellow [WARN] to stderr
_message_error "nope"         # red [ERROR] to stderr
```

## Cross-module deps

At the top of a `.bash` file: `_require_module "git"` (or any other namespace). Idempotent.

## Rules / gotchas

1. `_description` and every `_param` must appear **inside the function**, before `_param_parse`.
2. `_complete_*` calls must be at **file scope**, below the function.
3. Return non-zero on any user-facing error; `_param_parse` already returns 1 on `--help` or validation failure — propagate it with `|| return 1`.
4. For mutating commands use `_complete_type "<func>" action` **before** `_complete_params`, otherwise users will see meaningless `--filter/--sort/...` flags.
5. Don't re-implement table/JSON/filter/sort — pipe into `_output_render`.
6. Don't shell out directly to long-running tools when you want caching — wrap with `_exec` / `_exec_python`.
7. Function names starting with `_` are hidden from dispatch and introspection; use them for helpers and completers.
8. Positional arg completion needs `_complete_positional`; flag-value completion needs `_complete_func`/`_complete_values`/`_complete_path`. Register whichever apply.

## Minimal reference example

```bash
# src/weather/weather.bash
weather_forecast() {
    _description "Show weather forecast"
    _requires curl || return 1
    _param location --required --positional --help "City"
    _param days     --default 3              --help "Days"
    _param_parse "$@" || return 1

    _exec curl -s "https://wttr.in/${location}?format=j1" \
        | json_tsv --path 'weather' --fields 'date=date,max=maxtempC,min=mintempC' \
        | _output_render "date,max,min"
}

_weather_cities() { printf '%s\n' London Paris Tokyo; }

_complete_params     "weather_forecast" "location" "days"
_complete_func       "weather_forecast" "location" _weather_cities
_complete_positional "weather_forecast" _weather_cities
_complete_values     "weather_forecast" "days" 1 3 7 14
```

## Output format

Respond with **exactly one** fenced ```bash code block containing the complete command file contents. Nothing before it, nothing after it — no prose, no file-path headers, no explanation. Do not attempt to write files or use any tools; the surrounding wrapper will place the code where it belongs.
