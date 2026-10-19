# Shared paths for the build scripts. Sourced, not run.
#
# Machine-specific overrides go in tools/local.env (gitignored), e.g.:
#   VALHEIM_DIR=/path/to/steamapps/common/Valheim
#   BEPINEX_CORE=/path/to/BepInEx/core

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROJECT_DIR="$REPO/TargetPortal"
TOOLS_DIR="$REPO/.tools"          # everything downloaded or generated lives here (gitignored)
DIST_DIR="$REPO/dist"             # build output (gitignored)

[ -f "$REPO/tools/local.env" ] && . "$REPO/tools/local.env"

# The Valheim install the reference assemblies come from. Only read, never written. Defaults to the
# usual Steam locations; a game in another Steam library needs VALHEIM_DIR in tools/local.env.
if [ -z "${VALHEIM_DIR:-}" ]; then
	for v in "$HOME/.local/share/Steam/steamapps/common/Valheim" "$HOME/.steam/steam/steamapps/common/Valheim"; do
		[ -d "$v" ] && VALHEIM_DIR="$v" && break
	done
	VALHEIM_DIR="${VALHEIM_DIR:-$HOME/.local/share/Steam/steamapps/common/Valheim}"
fi

# BepInEx/core with BepInEx.dll and 0Harmony.dll. The game folder has no BepInEx when mods are
# managed by Gale/r2modman, so fall back to an unpacked BepInExPack_Valheim download.
if [ -z "${BEPINEX_CORE:-}" ]; then
	for c in "$VALHEIM_DIR/BepInEx/core" "$HOME"/Downloads/denikson-BepInExPack_Valheim-*/BepInExPack_Valheim/BepInEx/core; do
		[ -f "$c/BepInEx.dll" ] && BEPINEX_CORE="$c" && break
	done
fi

GALE_PROFILES="${GALE_PROFILES:-$HOME/.local/share/com.kesomannen.gale/valheim/profiles}"

# The csproj expects $(GamePath)/valheim_Data/Managed/publicized_assemblies and
# $(GamePath)/BepInEx/core. Steam on Linux spells it Valheim_Data, and the publicized assemblies
# are generated, so setup.sh assembles this fake game folder out of symlinks instead.
GAMEPATH="$TOOLS_DIR/gamepath"
REFASM="$TOOLS_DIR/refasm/build"  # .NET Framework 4.8 reference assemblies

export DOTNET_ROOT="$TOOLS_DIR/dotnet"
export PATH="$TOOLS_DIR/dotnet:$TOOLS_DIR/bin:$PATH"
export DOTNET_CLI_TELEMETRY_OPTOUT=1 DOTNET_NOLOGO=1 DOTNET_SKIP_FIRST_TIME_EXPERIENCE=1
# assembly-publicizer targets an older runtime than the one installed.
export DOTNET_ROLL_FORWARD=LatestMajor

die() { echo "error: $*" >&2; exit 1; }

mod_version() { sed -n 's/.*ModVersion = "\([^"]*\)".*/\1/p' "$PROJECT_DIR/TargetPortal.cs"; }
