"""Apply the Supabase migrations to a throwaway local PostgreSQL database and run the SQL tests.

Usage (from the repo's lms/ folder), after copying .env.example to .env in this folder:
    python tests/supabase-local/run.py          # migrations + tests
    python tests/supabase-local/run.py --seed   # migrations + seed.sql

Creates (and afterwards drops) a database called gtapex_supabase_test. Needs psql on PATH or PostgreSQL 18
in its default Windows location. This only checks the SQL; Supabase Auth, Storage and Edge Functions are stubbed.
"""
import os
import shutil
import subprocess
import sys
from pathlib import Path
from urllib.parse import urlparse

HERE = Path(__file__).resolve().parent
SUPABASE = HERE.parent.parent / "supabase"
DB = "gtapex_supabase_test"
PSQL = shutil.which("psql") or r"C:\Program Files\PostgreSQL\18\bin\psql.exe"


def psql(url, *args, check=True):
    u = urlparse(url)
    env = dict(os.environ, PGPASSWORD=u.password or "")
    base = [PSQL, "-h", u.hostname or "localhost", "-p", str(u.port or 5432), "-U", u.username or "postgres",
            "-v", "ON_ERROR_STOP=1", "-q", "-X", "-t", "-A"]
    return subprocess.run(base + list(args), env=env, check=check, text=True, capture_output=True)


def main():
    urls = [a for a in sys.argv[1:] if not a.startswith("--")]
    if urls:
        admin_url = urls[0]
    else:
        env_file = HERE / ".env"
        found = [l.split("=", 1)[1].strip() for l in env_file.read_text(encoding="utf-8").splitlines() if l.startswith("TEST_DATABASE_URL=")] if env_file.exists() else []
        if not found:
            sys.exit("Copy tests/supabase-local/.env.example to .env and set TEST_DATABASE_URL.")
        admin_url = found[0]
    test_url = admin_url.rsplit("/", 1)[0] + "/" + DB
    psql(admin_url, "-d", urlparse(admin_url).path.lstrip("/") or "postgres", "-c", f"drop database if exists {DB}")
    psql(admin_url, "-d", urlparse(admin_url).path.lstrip("/") or "postgres", "-c", f"create database {DB}")
    keep = "--keep" in sys.argv
    try:
        files = [HERE / "00_supabase_stub.sql", *sorted((SUPABASE / "migrations").glob("*.sql"))]
        if "--seed" in sys.argv:  # load the starter content instead of running the tests (they expect an empty database)
            files.append(SUPABASE / "seed.sql")
        else:
            files += sorted(HERE.glob("test_*.sql"))
        for f in files:
            r = psql(test_url, "-d", DB, "-f", str(f), check=False)
            out = (r.stdout + r.stderr).strip()
            status = "ok " if r.returncode == 0 else "FAIL"
            print(f"[{status}] {f.relative_to(SUPABASE.parent)}")
            if out:
                print("   " + out.replace("\n", "\n   "))
            if r.returncode != 0:
                sys.exit(1)
        print("All migrations and tests passed.")
    finally:
        if not keep:
            psql(admin_url, "-d", urlparse(admin_url).path.lstrip("/") or "postgres", "-c", f"drop database if exists {DB}", check=False)


if __name__ == "__main__":
    main()
