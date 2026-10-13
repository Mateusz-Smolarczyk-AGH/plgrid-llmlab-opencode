#!/usr/bin/env python3
import argparse
import json
import os


def load_projects(path):
    try:
        with open(path) as f:
            projects = json.load(f).get("projects", [])
    except (FileNotFoundError, json.JSONDecodeError):
        projects = []
    return [p for p in projects if p.get("host_path") and p.get("container_path")]


def main():
    parser = argparse.ArgumentParser(
        description="Render docker-compose.override.yml from projects.json."
    )
    parser.add_argument("--projects", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    projects = load_projects(args.projects)

    if not projects:
        if os.path.exists(args.out):
            os.remove(args.out)
        print(f"No projects registered; removed {args.out}")
        return

    lines = ["services:", "  cyfrocode:", "    volumes:"]
    for project in projects:
        lines.append(f"      - {project['host_path']}:{project['container_path']}:z")

    with open(args.out, "w") as f:
        f.write("\n".join(lines) + "\n")

    print(f"Rendered {args.out} ({len(projects)} project mounts)")


if __name__ == "__main__":
    main()
