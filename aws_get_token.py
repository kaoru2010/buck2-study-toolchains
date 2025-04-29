#!/usr/bin/env python3
# file: get_token.py
import argparse, json, subprocess, sys

def main() -> None:
    p = argparse.ArgumentParser(
        description="CodeArtifact 認証トークンを取得して JSON で出力")
    p.add_argument("--domain", required=True)
    p.add_argument("--domain-owner", required=True)
    p.add_argument("--profile", default=None)
    args = p.parse_args()

    cmd = [
        "aws", "codeartifact", "get-authorization-token",
        "--domain", args.domain,
        "--domain-owner", args.domain_owner,
        "--query", "authorizationToken",
        "--output", "text",
    ]
    if args.profile:
        cmd.extend(["--profile", args.profile])

    try:
        token = subprocess.check_output(cmd, text=True).strip()
    except subprocess.CalledProcessError as e:
        print("aws コマンドが失敗しました:", e, file=sys.stderr)
        sys.exit(e.returncode)

    json.dump({"resources": [{"token": token}]}, sys.stdout)
    sys.stdout.write("\n")

if __name__ == "__main__":
    main()