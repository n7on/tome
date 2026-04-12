# rig

A bash CLI framework for building clean, consistent command-line tools — with typed parameters, tab completion, output formatting, filtering, and caching built in.

## Requirements

- bash
- python3 + venv

## Setup

```bash
git clone https://github.com/n7on/rig ~/Source/rig
rig setup
```

Add to `~/.bashrc` or `~/.zshrc`:

```bash
export PATH="$HOME/Source/rig/bin:$PATH"
source <(rig completion bash)   # or zsh
```

## Plugins

Rig ships with only the core framework. Commands are added via packs:

```bash
rig pack install https://github.com/n7on/rig-microsoft
rig pack install https://github.com/n7on/rig-note
rig pack install https://github.com/n7on/rig-export
rig pack install https://github.com/n7on/rig-general
```

List installed packs:

```bash
rig pack list
```

Update or remove:

```bash
rig pack update
rig pack remove rig-note
```

## Output formats

All commands support `--output_format`:

| Format | Description |
| --- | --- |
| `table` | Aligned table (default) |
| `json` | JSON array |
| `tsv` | Tab-separated values |
| `md` | Markdown table |
| `raw` | Unprocessed output |

## Filtering and sorting

```bash
rig pack list --filter pack=built-in
rig pack list --filter namespace~az
rig pack list --sort namespace
rig pack list --select namespace
rig pack list --limit 5
```

## Caching

```bash
rig <command> --cache          # cache for 300s (default)
rig <command> --cache 3600     # cache for 1 hour
rig cache clear                # clear all cached results
```

## Writing packs

See [CONTRIBUTING.md](CONTRIBUTING.md).
