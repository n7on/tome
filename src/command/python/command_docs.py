"""Generate command documentation from tome source files.

Parses bash files for _description, _param,
and _complete_params calls to build command metadata.

Usage:
    command_docs.py <src_dir> [--format table|json|md] [--command <name>]
"""

import argparse
import os
import re
import sys


def parse_source_files(src_dir):
    """Parse all bash files to extract command metadata."""
    commands = {}

    for root, dirs, files in os.walk(src_dir):
        # Skip _* framework dirs
        if os.path.basename(root).startswith("_"):
            continue
        for fname in sorted(files):
            if not fname.endswith(".bash"):
                continue
            path = os.path.join(root, fname)
            module = os.path.basename(root)
            parse_file(path, module, commands)

    return commands


def parse_file(path, module, commands):
    """Parse a single bash file for command metadata."""
    with open(path) as f:
        lines = f.readlines()

    current_func = None

    for line in lines:
        line = line.strip()

        # Detect function definition
        m = re.match(r'^(\w+)\s*\(\)\s*\{', line)
        if m:
            name = m.group(1)
            # Skip internal/private functions
            if name.startswith("_"):
                continue
            current_func = name
            if name not in commands:
                commands[name] = {
                    "name": name,
                    "module": module,
                    "description": "",
                    "params": [],
                }
            continue

        # Parse _complete_params for description (file scope)
        m = re.match(r'_complete_params\s+"(\w+)"\s+"([^"]+)"', line)
        if m:
            func_name, desc = m.group(1), m.group(2)
            if func_name in commands:
                commands[func_name]["description"] = desc
            continue


        if not current_func:
            continue

        # Parameter
        m = re.match(r'_param\s+(\w+)(.*)', line)
        if m:
            pname = m.group(1)
            rest = m.group(2)

            param = {"name": pname, "required": False, "positional": False, "default": "", "help": ""}

            if "--required" in rest:
                param["required"] = True
            if "--positional" in rest:
                param["positional"] = True

            dm = re.search(r'--default\s+"([^"]*)"', rest) or re.search(r"--default\s+'([^']*)'", rest) or re.search(r'--default\s+(\S+)', rest)
            if dm:
                val = dm.group(1)
                # Skip shell expressions — not useful in docs
                if not val.startswith("$("):
                    param["default"] = val

            hm = re.search(r'--help\s+"([^"]*)"', rest)
            if hm:
                param["help"] = hm.group(1)

            commands[current_func]["params"].append(param)
            continue

        # End of function body (next function or end of params section)
        if re.match(r'_param_parse', line):
            current_func = None
            continue


def format_list_tsv(commands):
    """Output command list as TSV with headers."""
    print("command,module,description")
    for cmd in sorted(commands.values(), key=lambda c: c["name"]):
        display = cmd["name"].replace("_", " ")
        print(f"{display}\t{cmd['module']}\t{cmd['description']}")


def format_show_tsv(cmd):
    """Output command params as TSV with headers."""
    print("param,required,positional,default,help")
    for p in sorted(cmd["params"], key=lambda p: p["name"]):
        print(f"{p['name']}\t{'yes' if p['required'] else ''}\t{'yes' if p['positional'] else ''}\t{p['default']}\t{p['help']}")


def format_docs_md(commands, bin="tome"):
    """Output full markdown documentation."""
    print("# Grim Commands")
    print()
    print(f"Grim is a bash CLI framework. Run commands using `{bin}`:")
    print()
    print("```bash")
    print(f"{bin} nmap scan quick localhost")
    print(f"{bin} azure graph query my_query --output json")
    print(f"{bin} note add \"my note #tag\"")
    print("```")
    print()

    # Group by module
    modules = {}
    for cmd in commands.values():
        modules.setdefault(cmd["module"], []).append(cmd)

    for module in sorted(modules):
        print(f"## {module}")
        print()

        for cmd in sorted(modules[module], key=lambda c: c["name"]):
            print(f"### `{cmd['name'].replace('_', ' ')}`")
            print()
            if cmd["description"]:
                print(cmd["description"])
                print()

            # Filter out framework params for docs
            framework_params = {"output", "cache", "filter", "sort", "select", "limit", "debug", "help"}
            params = [p for p in cmd["params"] if p["name"] not in framework_params]

            if params:
                print("| Parameter | Required | Description |")
                print("| --- | --- | --- |")
                for p in sorted(params, key=lambda p: p["name"]):
                    desc_parts = []
                    if p["help"]:
                        desc_parts.append(p["help"])
                    if p["default"]:
                        desc_parts.append(f"Default: `{p['default']}`")
                    if p["positional"]:
                        desc_parts.append("Positional")
                    desc = ". ".join(desc_parts)
                    print(f"| `--{p['name']}` | {'yes' if p['required'] else ''} | {desc} |")
                print()

    # Add framework params section
    print("## Framework Parameters")
    print()
    print("All commands support these parameters:")
    print()
    print("| Parameter | Description |")
    print("| --- | --- |")
    print("| `--output` | Output format: `table`, `json`, `tsv`, `raw`, `md`. Default: `table` |")
    print("| `--cache` | Cache TTL in seconds. Use bare `--cache` for 300s default |")
    print("| `--filter` | Filter rows: `COL=value` (exact/wildcard) or `COL~value` (contains) |")
    print("| `--sort` | Sort by column. Prefix with `-` for descending |")
    print("| `--select` | Comma-separated list of columns to include |")
    print("| `--limit` | Limit output to first N rows |")
    print("| `--debug` | Show verbose error output |")


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("src_dir")
    parser.add_argument("--format", default="list", choices=["list", "show", "docs"])
    parser.add_argument("--command", default=None)
    parser.add_argument("--bin", default="tome", dest="bin")
    args = parser.parse_args()

    commands = parse_source_files(args.src_dir)

    if args.format == "list":
        format_list_tsv(commands)
    elif args.format == "show":
        name = args.command.replace(" ", "_") if args.command else None
        if not name or name not in commands:
            print(f"Unknown command: {args.command}", file=sys.stderr)
            sys.exit(1)
        format_show_tsv(commands[name])
    elif args.format == "docs":
        format_docs_md(commands, args.bin)


if __name__ == "__main__":
    main()
