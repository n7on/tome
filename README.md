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
export PATH="/path/to/grim/bin:$PATH"
source <(grim completion bash)
```

## Usage

```bash
grim nmap scan quick localhost
grim azure context list --output json
grim note add "my note #tag"
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
grim azure context list --filter name=prod       # exact match (wildcards supported)
grim azure context list --filter name~prod       # contains match
grim azure context list --sort -name             # sort descending
grim azure context list --select name,id         # pick columns
grim azure context list --limit 10               # first N rows
```

## Caching

```bash
grim azure graph query my_query --cache          # cache for 300s (default)
grim azure graph query my_query --cache 3600     # cache for 1 hour
grim cache clear                                 # clear all cached results
```

## Vim integration

Add to your `.vimrc`:

```vim
source /path/to/grim/vim/grim.vim
```

This adds a `:Grim` command with tab completion. The first argument completes command names, subsequent arguments complete `--flags`:

```vim
:Grim nmap scan quick localhost
:Grim azure context list --output json
```

Output opens in a scratch split.

## Available commands

See [COMMANDS.md](COMMANDS.md) for the full command reference.

## Adding commands

See [CONTRIBUTING.md](CONTRIBUTING.md) for how to create new modules and commands.
