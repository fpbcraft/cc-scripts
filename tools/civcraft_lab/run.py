#!/usr/bin/env python3
"""Run explicit, versioned seeded match configurations."""
import argparse
import json
from pathlib import Path

from runner import write_run


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--config', type=Path, required=True, help='JSON list of match configurations')
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--workers', type=int, default=1)
    parser.add_argument('--backend', choices=('lua53', 'luajit21'),
                        help='Override runtimeBackend in every configuration; default keeps Lua 5.3')
    args = parser.parse_args()
    if not 1 <= args.workers <= 6:
        parser.error('Use 1–6 workers initially; benchmark memory/thermals before increasing')
    configs = json.loads(args.config.read_text())
    if not isinstance(configs, list) or not configs:
        parser.error('Configuration must be a nonempty list')
    if args.backend:
        configs = [config | {'runtimeBackend': args.backend} for config in configs]
    record = write_run(configs, args.output, args.workers)
    counts = {}
    for match in record['matches']:
        counts[match['status']] = counts.get(match['status'], 0) + 1
    print(json.dumps({'matches': len(configs), 'statusCounts': counts,
                      'elapsedSeconds': record['elapsedSeconds'], 'output': str(args.output)}))


if __name__ == '__main__':
    main()
