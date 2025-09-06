#!/usr/bin/env python3


# -----------------------------------------------------------------------------
# Gitleaks pre-commit hook (Linux/macOS/Windows) with silent auto-install
#
# Quick use:
#   0) Rename existing pre-commit sample script:
#      mv .git/hooks/pre-commit.sample .git/hooks/pre-commit
#   1) Copy to .git/hooks/pre-commit (LF endings). Make executable on *nix:
#        chmod +x .git/hooks/pre-commit
#   2) Toggle behavior:
#        This hook auto-enables itself (sets: git config --local hooks.gitleaks true).
#        Check status:  git config --bool hooks.gitleaks
#        Temporary bypass for one commit:  git commit --no-verify
#        Permanent disable: comment/remove the force-enable lines in main()
#        (or guard them with an env flag), then optionally set hooks.gitleaks false.
#   3) Commit as usual. The hook auto-installs gitleaks into .git/hooks/bin/
#      from the latest GitHub release (tar.gz on Linux/macOS, zip on Windows).
#	4) Command to test (manual, same mode as the hook; run from repo root):
#	   .git/hooks/bin/gitleaks git --pre-commit --staged --redact --config .gitleaks.toml
#	   (optionally add: --exit-code 1  to force non-zero exit when leaks are found)
#	5) Config note (.gitleaks.toml in repo root):
#	   To keep all built-in rules AND add custom ones, include:
#	     [extend]
#	     useDefault = true
# -----------------------------------------------------------------------------


"""Gitleaks pre-commit hook with auto-install (Linux/macOS/Windows)."""
import io
import json
import os
import platform
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
import zipfile
from pathlib import Path

CFG_KEY = "hooks.gitleaks"

def run(cmd, **kw):
    return subprocess.run(cmd, text=True, capture_output=True, **kw)

def git_cfg_bool(key: str):
    p = run(["git", "config", "--bool", key])
    if p.returncode != 0:
        return None  # unset
    v = p.stdout.strip().lower()
    return True if v == "true" else False if v == "false" else None

def hook_enabled() -> bool:
    val = git_cfg_bool(CFG_KEY)
    return False if val is False else True  # default ON

def repo_root() -> Path:
    p = run(["git", "rev-parse", "--show-toplevel"])
    return Path(p.stdout.strip() or ".")

def which(prog: str):
    return shutil.which(prog)

def os_suffix() -> str:
    s = platform.system()
    return {"Darwin": "darwin", "Linux": "linux", "Windows": "windows"}.get(s, s.lower())

def arch_suffix() -> str:
    m = platform.machine().lower()
    return {
        "x86_64": "x64", "amd64": "x64",
        "aarch64": "arm64", "arm64": "arm64",
        "armv7l": "armv7", "armv6l": "armv6",
        "i386": "x32", "i686": "x32",
    }.get(m, "x64")

def ensure_gitleaks_in_path():
    """Ensure gitleaks is available; install locally if missing (Linux/macOS/Windows)."""
    if which("gitleaks"):
        return True, None

    # silent bootstrap (no user-facing stderr)
    os_suf = os_suffix()
    if os_suf not in ("linux", "darwin", "windows"):
        return False, f"auto-install not supported on OS '{os_suf}'. Please install gitleaks manually."

    arch_suf = arch_suffix()
    # Query latest release metadata
    try:
        with urllib.request.urlopen(
            "https://api.github.com/repos/gitleaks/gitleaks/releases/latest", timeout=20
        ) as resp:
            rel = json.load(resp)
    except Exception as e:
        return False, f"failed to query GitHub releases: {e}"

    asset = None
    for a in rel.get("assets", []):
        name = a.get("name", "")
        if os_suf in name and arch_suf in name:
            if os_suf in ("linux", "darwin") and name.endswith(".tar.gz"):
                asset = a
                break
            if os_suf == "windows" and name.endswith(".zip"):
                asset = a
                break
    if not asset:
        return False, f"no release asset for {os_suf}_{arch_suf}"

    url = asset["browser_download_url"]
    root = repo_root()
    bin_dir = root / ".git" / "hooks" / "bin"
    bin_dir.mkdir(parents=True, exist_ok=True)

    # Install per-OS archive type
    if os_suf in ("linux", "darwin"):
        # Prefer curl | tar (no sudo; repo-scoped install)
        if which("curl"):
            tmpdir = Path(tempfile.mkdtemp(prefix="gitleaks_"))
            sh_cmd = f"curl -fLSs '{url}' | tar -xz -C '{tmpdir}'"
            pr = run(["sh", "-c", sh_cmd])
            if pr.returncode != 0:
                return False, f"curl|tar failed: {pr.stderr or pr.stdout}"
            gbin = None
            for d, _, files in os.walk(tmpdir):
                if "gitleaks" in files:
                    gbin = Path(d) / "gitleaks"
                    break
            if not gbin:
                return False, "archive did not contain gitleaks binary"
            shutil.copy2(gbin, bin_dir / "gitleaks")
            os.chmod(bin_dir / "gitleaks", 0o755)
            shutil.rmtree(tmpdir, ignore_errors=True)
        else:
            # Fallback without curl: download via Python then extract
            try:
                with urllib.request.urlopen(url, timeout=60) as r:
                    buf = r.read()
                with tarfile.open(fileobj=io.BytesIO(buf), mode="r:gz") as tar:
                    member = next((m for m in tar.getmembers()
                                   if m.name.endswith("/gitleaks") or m.name == "gitleaks"), None)
                    if not member:
                        return False, "archive did not contain gitleaks binary"
                    tmpdir = Path(tempfile.mkdtemp(prefix="gitleaks_"))
                    tar.extract(member, path=tmpdir)
                    extracted = tmpdir / member.name
                    shutil.copy2(extracted, bin_dir / "gitleaks")
                    os.chmod(bin_dir / "gitleaks", 0o755)
                    shutil.rmtree(tmpdir, ignore_errors=True)
            except Exception as e:
                return False, f"download/extract failed: {e}"
    else:  # windows (.zip)
        try:
            with urllib.request.urlopen(url, timeout=60) as r:
                buf = r.read()
            with zipfile.ZipFile(io.BytesIO(buf)) as zf:
                member = next((m for m in zf.namelist()
                               if m.endswith("/gitleaks.exe") or m.endswith("gitleaks.exe")), None)
                if not member:
                    return False, "archive did not contain gitleaks.exe"
                tmpdir = Path(tempfile.mkdtemp(prefix="gitleaks_"))
                zf.extract(member, path=tmpdir)
                extracted = tmpdir / member
                dest = bin_dir / "gitleaks.exe"
                shutil.copy2(extracted, dest)
                try:
                    os.chmod(dest, 0o755)
                except Exception:
                    pass
                shutil.rmtree(tmpdir, ignore_errors=True)
        except Exception as e:
            return False, f"download/extract failed: {e}"

    # Prepend local bin so `gitleaks` (or gitleaks.exe) resolves
    os.environ["PATH"] = str(bin_dir) + os.pathsep + os.environ.get("PATH", "")
    return True, None

def main() -> int:
    # Sets hooks.gitleaks=true only if it's currently unset.
    if git_cfg_bool(CFG_KEY) is not True:
        run(["git", "config", CFG_KEY, "true"])

    if not hook_enabled():
        print("gitleaks pre-commit disabled (enable with `git config hooks.gitleaks true`).")
        return 0

    ok, err = ensure_gitleaks_in_path()
    if not ok:
        sys.stderr.write(f"[pre-commit] {err}\n")
        return 1

    root = repo_root()
    config = root / ".gitleaks.toml"

    # Use modern pre-commit mode with staged tracking (v8.19+)
    cmd = ["gitleaks", "git", "--pre-commit", "--staged", "--redact", "--exit-code", "1"]
    if config.exists():
        cmd += ["--config", str(config)]
    cmd += [str(root)]

    if os.environ.get("GITLEAKS_VERBOSE"):
        cmd.insert(1, "-v")

    proc = run(cmd)
    if proc.returncode == 1:
        # 1 = leaks found (default behavior)
        sys.stderr.write(
            "Warning: gitleaks detected potential secrets in your staged changes.\n"
            "Fix findings, or temporarily disable with:\n"
            "  git config hooks.gitleaks false\n"
            "You can also bypass once with `git commit --no-verify` (not recommended).\n\n"
        )
        # surface scanner output
        sys.stderr.write(proc.stdout + proc.stderr)
        return 1
    elif proc.returncode != 0:
        sys.stderr.write(f"gitleaks error (exit {proc.returncode}):\n{proc.stdout}{proc.stderr}")
        return proc.returncode

    return 0

if __name__ == "__main__":
    sys.exit(main())