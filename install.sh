#!/usr/bin/env bash
#
# Agentforce Vision - one-command installer
# Deploys the Salesforce metadata, seeds Knowledge, and publishes + activates
# the Vireon Support Agent into an org you already have.
#
# Usage (from a clone):
#   ./install.sh -o <org-alias-or-username>
#
# Usage (directly from GitHub):
#   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/sfdc-brendan/AgentforceVision/main/install.sh)" -- -o <org>
#
# Flags:
#   -o <org>         Target org alias or username (defaults to your sf default org)
#   -b <branch>      Branch to clone when run via curl (default: main)
#   --skip-knowledge Skip seeding/publishing the sample Knowledge articles
#   --skip-agent     Deploy metadata only; do not publish/activate the agent
#   -h, --help       Show this help
#
set -euo pipefail

REPO_URL="https://github.com/sfdc-brendan/AgentforceVision.git"
AGENT_API_NAME="Vireon_Support_Agent"
PERMSET="Agentforce_Vision"
KNOWLEDGE_APEX="scripts/apex/create_vireon_knowledge.apex"
AGENT_FILE="force-app/main/default/aiAuthoringBundles/${AGENT_API_NAME}/${AGENT_API_NAME}.agent"
PLACEHOLDER="__AGENTFORCE_SERVICE_AGENT_USER__"

ORG=""
BRANCH="main"
SKIP_KNOWLEDGE=0
SKIP_AGENT=0

# ---------- pretty output ----------
if [ -t 1 ]; then
  BOLD="$(printf '\033[1m')"; DIM="$(printf '\033[2m')"; RED="$(printf '\033[31m')"
  GRN="$(printf '\033[32m')"; YLW="$(printf '\033[33m')"; BLU="$(printf '\033[36m')"; RST="$(printf '\033[0m')"
else
  BOLD=""; DIM=""; RED=""; GRN=""; YLW=""; BLU=""; RST=""
fi
step() { printf "\n${BOLD}${BLU}==>${RST} ${BOLD}%s${RST}\n" "$1"; }
ok()   { printf "  ${GRN}OK${RST} %s\n" "$1"; }
warn() { printf "  ${YLW}!${RST}  %s\n" "$1"; }
die()  { printf "\n${RED}ERROR:${RST} %s\n" "$1" >&2; exit 1; }

usage() { sed -n '3,18p' "$0" | sed 's/^# \{0,1\}//'; exit 0; }

# ---------- args ----------
while [ $# -gt 0 ]; do
  case "$1" in
    -o) ORG="${2:-}"; shift 2 ;;
    -b) BRANCH="${2:-main}"; shift 2 ;;
    --skip-knowledge) SKIP_KNOWLEDGE=1; shift ;;
    --skip-agent) SKIP_AGENT=1; shift ;;
    -h|--help) usage ;;
    *) die "Unknown argument: $1 (use -h for help)" ;;
  esac
done

# ---------- locate or clone the repo ----------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]:-$0}")" 2>/dev/null && pwd || true)"
if [ -n "$SCRIPT_DIR" ] && [ -f "$SCRIPT_DIR/sfdx-project.json" ]; then
  cd "$SCRIPT_DIR"
else
  step "Fetching Agentforce Vision from GitHub"
  command -v git >/dev/null 2>&1 || die "git is required to install from GitHub."
  TMP="$(mktemp -d)"
  git clone --depth 1 -b "$BRANCH" "$REPO_URL" "$TMP/AgentforceVision" >/dev/null 2>&1 \
    || die "Could not clone $REPO_URL (branch $BRANCH)."
  cd "$TMP/AgentforceVision"
  ok "Cloned to $TMP/AgentforceVision"
fi
[ -f "$AGENT_FILE" ] || die "Run this from the AgentforceVision project root (missing $AGENT_FILE)."

# ---------- preflight: CLI ----------
step "Checking prerequisites"
command -v sf >/dev/null 2>&1 || die "Salesforce CLI (sf) not found. Install: https://developer.salesforce.com/tools/salesforcecli"
command -v python3 >/dev/null 2>&1 || die "python3 is required by this installer."
ok "sf CLI: $(sf --version 2>/dev/null | head -1)"

# ---------- resolve org ----------
if [ -z "$ORG" ]; then
  ORG="$(sf config get target-org --json 2>/dev/null | python3 -c 'import json,sys;
try:
    v=json.load(sys.stdin)["result"][0].get("value","")
    print(v or "")
except Exception:
    print("")' || true)"
fi
[ -n "$ORG" ] || die "No target org. Pass -o <org>, or run 'sf org login web' and set a default."
ORG_USER="$(sf org display -o "$ORG" --json 2>/dev/null | python3 -c 'import json,sys; print(json.load(sys.stdin)["result"]["username"])' 2>/dev/null || true)"
[ -n "$ORG_USER" ] || die "Could not connect to org '$ORG'. Authorize it first: sf org login web -a $ORG"
ok "Target org: $ORG ($ORG_USER)"

# ---------- preflight: Lightning Knowledge ----------
step "Verifying org features"
if sf sobject describe -s Knowledge__kav -o "$ORG" --json >/dev/null 2>&1; then
  ok "Lightning Knowledge is enabled (Knowledge__kav present)."
else
  die "Lightning Knowledge is not enabled in this org.
  Enable it in Setup > Knowledge Settings (and create a Knowledge-enabled user), then re-run.
  This installer cannot enable org features for you."
fi
if ! sf data query -o "$ORG" -q "SELECT Id FROM BotDefinition LIMIT 1" >/dev/null 2>&1; then
  warn "Could not confirm Agentforce is enabled. If publish fails, verify Agentforce + a Service Agent license in Setup."
fi

# ---------- detect Agentforce Service Agent user ----------
AGENT_USER=""
if [ "$SKIP_AGENT" -eq 0 ]; then
  step "Detecting the Agentforce Service Agent user"
  AGENT_USER="$(sf data query -o "$ORG" --json 2>/dev/null \
    -q "SELECT Username FROM User WHERE Profile.Name = 'Einstein Agent User' AND IsActive = true ORDER BY CreatedDate DESC" \
    | python3 -c 'import json,sys
try:
    recs=[r["Username"] for r in json.load(sys.stdin)["result"]["records"]]
except Exception:
    recs=[]
pref=[u for u in recs if u.lower().startswith("serviceagent")]
print((pref or recs or [""])[0])' 2>/dev/null || true)"
  if [ -n "$AGENT_USER" ]; then
    ok "Agent user: $AGENT_USER"
  else
    warn "Could not auto-detect an 'Einstein Agent User'."
    printf "  Enter the Agentforce Service Agent username to use: "
    read -r AGENT_USER </dev/tty || true
    [ -n "$AGENT_USER" ] || die "An Agentforce Service Agent user is required to publish the agent.
  Find it in Setup > Users (Profile = 'Einstein Agent User'), or re-run with --skip-agent to deploy metadata only."
  fi

  # Substitute the placeholder in the .agent bundle; restore on exit.
  cp "$AGENT_FILE" "$AGENT_FILE.installbak"
  restore_agent() { [ -f "$AGENT_FILE.installbak" ] && mv -f "$AGENT_FILE.installbak" "$AGENT_FILE"; }
  trap restore_agent EXIT
  AGENT_USER="$AGENT_USER" python3 - "$AGENT_FILE" "$PLACEHOLDER" <<'PY'
import os, sys
path, placeholder = sys.argv[1], sys.argv[2]
with open(path, "r", encoding="utf-8") as f:
    data = f.read()
data = data.replace(placeholder, os.environ["AGENT_USER"])
with open(path, "w", encoding="utf-8") as f:
    f.write(data)
PY
  ok "Bound agent to $AGENT_USER"
fi

# ---------- deploy ----------
step "Deploying metadata"
sf project deploy start -d force-app -o "$ORG" -w 30 || die "Metadata deploy failed. See errors above."
ok "Metadata deployed."

# ---------- permission set ----------
step "Assigning the $PERMSET permission set"
if sf org assign permset -n "$PERMSET" -o "$ORG" >/dev/null 2>&1; then
  ok "Permission set assigned to $ORG_USER."
else
  warn "Permission set may already be assigned (continuing)."
fi

# ---------- knowledge ----------
if [ "$SKIP_KNOWLEDGE" -eq 0 ]; then
  step "Seeding sample Knowledge articles"
  sf apex run -f "$KNOWLEDGE_APEX" -o "$ORG" >/dev/null 2>&1 \
    && ok "Knowledge articles created and published." \
    || warn "Knowledge seeding reported an issue. Verify a Knowledge-enabled user and Knowledge Settings."
else
  warn "Skipping Knowledge seeding (--skip-knowledge)."
fi

# ---------- publish + activate agent ----------
if [ "$SKIP_AGENT" -eq 0 ]; then
  step "Publishing the $AGENT_API_NAME agent"
  sf agent publish authoring-bundle -n "$AGENT_API_NAME" -o "$ORG" --skip-retrieve \
    || die "Agent publish failed. Confirm Agentforce is enabled and the Service Agent user is valid."
  ok "Agent published."
  step "Activating the agent"
  sf agent activate -n "$AGENT_API_NAME" -o "$ORG" \
    && ok "Agent activated." \
    || warn "Activation reported an issue; activate manually in Agent Builder if needed."
else
  warn "Skipping agent publish/activate (--skip-agent)."
fi

# ---------- done ----------
printf "\n${GRN}${BOLD}Agentforce Vision installed.${RST}\n"
cat <<EOF

Next steps:
  1. Test the agent from the CLI:
       sf agent preview -n ${AGENT_API_NAME} -o ${ORG} --use-live-actions
  2. Upload one of the sample photos in demo-assets/vision-samples/ to a record
     (or attach it in an Agent/Messaging chat) and ask the agent to analyze it.
  3. To let customers chat with it, connect a channel (Enhanced Messaging /
     Messaging for Web, or the Agent API) in Setup.

Docs: https://github.com/sfdc-brendan/AgentforceVision
EOF
