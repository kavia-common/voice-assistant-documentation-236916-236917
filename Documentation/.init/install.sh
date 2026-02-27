#!/usr/bin/env bash
set -euo pipefail

# Workspace from container info
WS="/tmp/kavia/workspace/code-generation/voice-assistant-documentation-236916-236917/Documentation"
cd "$WS"

# Ensure pip is usable
if ! command -v python3 >/dev/null 2>&1; then
  echo "ERROR: python3 not found" >&2; exit 2
fi
if ! python3 -m pip --version >/dev/null 2>&1; then
  echo "ERROR: python3 -m pip not usable" >&2; exit 2
fi

# Persist PATH addition for user installs via /etc/profile.d, idempotent
PROFILE_FILE=/etc/profile.d/docs_env.sh
if [ ! -f "$PROFILE_FILE" ]; then
  sudo sh -c 'cat > /etc/profile.d/docs_env.sh <<\'EOF\'
# Ensure user-local python bin is on PATH for user installs
if [ -d "${HOME}/.local/bin" ]; then
  case ":$PATH:" in
    *":${HOME}/.local/bin:") ;;
    *) PATH="${HOME}/.local/bin:${PATH}" ; export PATH ;;
  esac
fi
EOF'
fi
# Export into current shell so immediately available
if [ -d "$HOME/.local/bin" ]; then
  export PATH="$HOME/.local/bin:${PATH:-}"
fi

# Install optional packages preferring --user
pkgs=(sphinx-rtd-theme sphinx-linkcheck)
for p in "${pkgs[@]}"; do
  if python3 -m pip show "$p" >/dev/null 2>&1; then
    continue
  fi
  # Try user install first
  if python3 -m pip install --user --upgrade --quiet --no-warn-script-location "$p"; then
    export PATH="$HOME/.local/bin:${PATH:-}"
    continue
  fi
  # user install failed, attempt sudo/system install if sudo available
  if sudo -n true 2>/dev/null; then
    sudo python3 -m pip install --upgrade --quiet --no-warn-script-location "$p"
  else
    echo "ERROR: cannot install $p (user install failed and no sudo)" >&2
    exit 3
  fi
done

# Idempotently set html_theme to sphinx_rtd_theme in source/conf.py if theme installed
if python3 -m pip show sphinx-rtd-theme >/dev/null 2>&1; then
  PY="$WS/source/conf.py"
  if [ -f "$PY" ]; then
    cp -a "$PY" "$PY.bak" || true
    python3 - <<'PYCODE' "$PY"
import io,sys,re
p=sys.argv[1]
with io.open(p,'r',encoding='utf-8') as f:
    lines=f.readlines()
out=[]
found=False
for ln in lines:
    s=ln.lstrip()
    if s.startswith('#'):
        out.append(ln); continue
    # match html_theme assignments: allow variations of quoting and spacing
    if re.match(r"\s*html_theme\s*=", ln):
        out.append("html_theme = 'sphinx_rtd_theme'\n")
        found=True
    else:
        out.append(ln)
if not found:
    out.append('\nhtml_theme = '\"'sphinx_rtd_theme'\"'\n'.replace("'\"'", "'"))
# The above replacement ensures a simple single-quoted insertion
with io.open(p,'w',encoding='utf-8') as f:
    f.writelines(out)
PYCODE
  fi
fi

# Validate sphinx-build available
if ! command -v sphinx-build >/dev/null 2>&1; then
  echo "ERROR: sphinx-build not found on PATH" >&2; exit 4
fi

# Success
exit 0
