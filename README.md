# Tome

A bash CLI framework for building clean, consistent command-line tools — with typed parameters, validation, output formatting, caching, and tab completion built in.

## Setup

**Requirements:** bash, python3

```bash
git clone <repo> tome
cd tome
bash setup.bash
```

Add to `~/.bashrc`:
```bash
export PATH="/path/to/tome/bin:$PATH"
source <(tome completion bash)
```

## Usage

```bash
tome nmap scan quick localhost
tome azure context list --output json
tome note add "my note #tag"
```

## Output formats

All commands support `--output`:

| Format | Description |
| --- | --- |
| `table` | Aligned table (default) |
| `json` | JSON array |
| `tsv` | Tab-separated values |
| `md` | Markdown table |
| `raw` | Unprocessed output |

## Output pipeline

All commands support these flags to slice and filter results:

```bash
tome azure context list --filter name=prod       # exact match (wildcards supported)
tome azure context list --filter name~prod       # contains match
tome azure context list --sort -name             # sort descending
tome azure context list --select name,id         # pick columns
tome azure context list --limit 10               # first N rows
```

## Caching

```bash
tome azure graph query my_query --cache          # cache for 300s (default)
tome azure graph query my_query --cache 3600     # cache for 1 hour
tome cache clear                                 # clear all cached results
```

## Available commands

See [COMMANDS.md](COMMANDS.md) for the full command reference.

## Adding commands

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new modules and commands.
