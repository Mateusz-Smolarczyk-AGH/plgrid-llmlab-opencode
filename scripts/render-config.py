#!/usr/bin/env python3
import argparse
import copy
import json


def deep_merge(base, overlay):
    for key, value in overlay.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = copy.deepcopy(value)
    return base


def main():
    parser = argparse.ArgumentParser(description="Render an opencode.json from base + profile.")
    parser.add_argument("--base", required=True)
    parser.add_argument("--profile", required=True)
    parser.add_argument("--config-dir", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    with open(args.base) as f:
        config = json.load(f)
    with open(args.profile) as f:
        profile = json.load(f)

    config = deep_merge(config, profile)
    config["instructions"] = [f"{args.config_dir.rstrip('/')}/AGENTS.md"]

    with open(args.out, "w") as f:
        json.dump(config, f, indent=2)
        f.write("\n")

    print(f"Rendered {args.out} (instructions -> {config['instructions'][0]})")


if __name__ == "__main__":
    main()
