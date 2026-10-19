#!/usr/bin/env bash
# One-time (and after every Valheim update) build environment setup. Nothing is installed
# system-wide: the .NET SDK, tools and reference assemblies all go into .tools/.
#
#   tools/setup.sh           # install whatever is missing, rebuild the gamepath
#   tools/setup.sh --force   # also reinstall the SDK and tools
set -euo pipefail
. "$(dirname "$0")/env.sh"

FORCE=0; [ "${1:-}" = "--force" ] && FORCE=1

# Pinned so a build is reproducible. Bump deliberately.
DOTNET_CHANNEL=10.0
PUBLICIZER_VERSION=0.4.3
ILREPACK_VERSION=2.0.48
ILREPACK_TASK_VERSION=2.0.18.2   # must match packages.config and the csproj import
REFASM_VERSION=1.0.3

mkdir -p "$TOOLS_DIR/bin" "$TOOLS_DIR/downloads"
DL="$TOOLS_DIR/downloads"

nuget() { # nuget <id> <version> <dest dir>: fetch and unpack a .nupkg
	local f="$DL/$1.$2.nupkg"
	[ -f "$f" ] || curl -fsSL -o "$f" "https://www.nuget.org/api/v2/package/$1/$2"
	rm -rf "$3"; mkdir -p "$3"; (cd "$3" && unzip -qo "$f")
}

echo "== .NET SDK $DOTNET_CHANNEL"
if [ $FORCE = 1 ] || [ ! -x "$TOOLS_DIR/dotnet/dotnet" ]; then
	curl -fsSL https://dot.net/v1/dotnet-install.sh -o "$DL/dotnet-install.sh"
	bash "$DL/dotnet-install.sh" --channel "$DOTNET_CHANNEL" --install-dir "$TOOLS_DIR/dotnet" --no-path
fi
dotnet --version

echo "== dotnet tools"
tool() { # tool <package> <version> <command>
	if [ $FORCE = 1 ] || [ ! -x "$TOOLS_DIR/bin/$3" ]; then
		dotnet tool uninstall --tool-path "$TOOLS_DIR/bin" "$1" >/dev/null 2>&1 || true
		dotnet tool install --tool-path "$TOOLS_DIR/bin" "$1" --version "$2"
	fi
}
tool BepInEx.AssemblyPublicizer.Cli "$PUBLICIZER_VERSION" assembly-publicizer
tool dotnet-ilrepack "$ILREPACK_VERSION" ilrepack

echo "== .NET Framework 4.8 reference assemblies"
[ $FORCE = 0 ] && [ -d "$REFASM" ] || nuget Microsoft.NETFramework.ReferenceAssemblies.net48 "$REFASM_VERSION" "$TOOLS_DIR/refasm"

echo "== ILRepack MSBuild task (only used on Windows, but the csproj refuses to build without it)"
PKG="$REPO/packages/ILRepack.Lib.MSBuild.Task.$ILREPACK_TASK_VERSION"
[ $FORCE = 0 ] && [ -d "$PKG/build" ] || nuget ILRepack.Lib.MSBuild.Task "$ILREPACK_TASK_VERSION" "$PKG"

echo "== gamepath from $VALHEIM_DIR"
MANAGED=""
for d in "$VALHEIM_DIR/Valheim_Data/Managed" "$VALHEIM_DIR/valheim_Data/Managed"; do
	[ -f "$d/assembly_valheim.dll" ] && MANAGED="$d" && break
done
[ -n "$MANAGED" ] || die "no Valheim_Data/Managed/assembly_valheim.dll under VALHEIM_DIR=$VALHEIM_DIR (set it in tools/local.env)"
[ -n "${BEPINEX_CORE:-}" ] || die "no BepInEx core found; unpack BepInExPack_Valheim from Thunderstore and set BEPINEX_CORE in tools/local.env"

rm -rf "$GAMEPATH"
mkdir -p "$GAMEPATH/valheim_Data/Managed/publicized_assemblies" "$GAMEPATH/BepInEx/core"
ln -s "$MANAGED"/*.dll "$GAMEPATH/valheim_Data/Managed/"
ln -s "$BEPINEX_CORE"/*.dll "$GAMEPATH/BepInEx/core/"
for a in assembly_valheim assembly_utils assembly_guiutils; do
	assembly-publicizer "$MANAGED/$a.dll" -o "$GAMEPATH/valheim_Data/Managed/publicized_assemblies/${a}_publicized.dll" >/dev/null
done
ls "$GAMEPATH/valheim_Data/Managed/publicized_assemblies"

# Record which game build the references came from, so a stale gamepath is easy to spot.
date -r "$MANAGED/assembly_valheim.dll" '+%F %T' > "$GAMEPATH/assembly_valheim.mtime"
echo "== done (assembly_valheim.dll from $(cat "$GAMEPATH/assembly_valheim.mtime"); BepInEx core: $BEPINEX_CORE)"
