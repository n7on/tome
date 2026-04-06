# Grim

A bash CLI framework for building clean, consistent command-line tools — with typed parameters, validation, output formatting, caching, and tab completion built in.

## Setup

**Requirements:** bash, python3

```bash
git clone <repo> grim
cd grim
bash setup.bash
```

Add to `~/.bashrc`:
```bash
source /path/to/grim/init.bash
```

## Usage

After sourcing `init.bash`, commands are available directly in your shell:

```bash
nmap_scan_quick localhost
azure_context_list --output json
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
azure_context_list --filter name=prod       # exact match (wildcards supported)
azure_context_list --filter name~prod       # contains match
azure_context_list --sort -name             # sort descending
azure_context_list --select name,id         # pick columns
azure_context_list --limit 10               # first N rows
```

## Caching

```bash
azure_graph_query my_query --cache          # cache for 300s (default)
azure_graph_query my_query --cache 3600     # cache for 1 hour
grim_cache_clear                            # clear all cached results
```

## Vim integration

Add to your `.vimrc`:

```vim
source /path/to/grim/vim/grim.vim
```

This adds a `:Grim` command with tab completion. The first argument completes command names, subsequent arguments complete `--flags`:

```vim
:Grim nmap_scan_quick localhost
:Grim azure_context_list --output json
```

Output opens in a scratch split.

## Available commands

See [COMMANDS.md](COMMANDS.md) for the full command reference.

## Adding commands

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new modules and commands.
