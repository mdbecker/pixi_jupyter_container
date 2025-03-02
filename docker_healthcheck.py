#!/usr/bin/env python3
import json
import os
import subprocess
import datetime
from pathlib import Path
import requests

DEBUG_LOG = Path("/tmp/healthcheck_debug.log")

def log(msg):
    timestamp = datetime.datetime.now().isoformat()
    with open(DEBUG_LOG, "a") as f:
        f.write(f"[{timestamp}] {msg}\n")

try:
    log("Starting health check")

    log("Running subprocess: jupyter --runtime-dir")
    result = subprocess.run(
        ["jupyter", "--runtime-dir"],
        check=True,
        capture_output=True,
        text=True,
        env=dict(os.environ) | {"HOME": "/home/" + os.environ["NB_USER"]},
    )
    runtime_dir = Path(result.stdout.rstrip())
    log(f"Runtime dir: {runtime_dir}")

    log("Searching for server json file")
    json_file = next(runtime_dir.glob("*server-*.json"))
    log(f"Found json file: {json_file}")

    log("Reading json file for URL")
    url = json.loads(json_file.read_bytes())["url"] + "api"
    log(f"Server API URL: {url}")

    log("Making HTTP request to Jupyter API")
    proxies = {"http": "", "https": ""}
    r = requests.get(url, proxies=proxies, verify=False)
    r.raise_for_status()
    log(f"HTTP request succeeded: {r.content}")

    print(r.content)
except Exception as e:
    log(f"Health check failed: {e!r}")
    raise
