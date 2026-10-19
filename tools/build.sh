#!/usr/bin/env bash
# Compile, merge and package the mod.
#
#   tools/build.sh                     # -> dist/TargetPortal.dll and dist/TargetPortal-<version>.zip
#   tools/build.sh --release           # Release instead of Debug
#   tools/build.sh --install <profile> # also copy the DLL into a Gale profile for testing
#
# Debug is the default because upstream ships Debug builds to Thunderstore, which keeps our IL
# directly comparable with official releases.
set -euo pipefail
. "$(dirname "$0")/env.sh"

CONFIG=Debug
INSTALL_PROFILE=""
while [ $# -gt 0 ]; do
	case "$1" in
		--release) CONFIG=Release ;;
		--install) INSTALL_PROFILE="${2:?--install needs a Gale profile name}"; shift ;;
		*) die "unknown argument: $1" ;;
	esac
	shift
done

[ -x "$TOOLS_DIR/dotnet/dotnet" ] && [ -d "$GAMEPATH" ] || die "build environment missing, run tools/setup.sh first"

MANAGED_DLL="$(readlink -f "$GAMEPATH/valheim_Data/Managed/assembly_valheim.dll")"
[ "$(date -r "$MANAGED_DLL" '+%F %T')" = "$(cat "$GAMEPATH/assembly_valheim.mtime" 2>/dev/null)" ] \
	|| die "Valheim was updated since the publicized assemblies were made, run tools/setup.sh again"

VERSION="$(mod_version)"
MANIFEST_VERSION="$(sed -n 's/.*"version_number": *"\([^"]*\)".*/\1/p' "$REPO/thunderstore/manifest.json")"
[ "$VERSION" = "$MANIFEST_VERSION" ] || die "ModVersion in TargetPortal.cs ($VERSION) does not match thunderstore/manifest.json ($MANIFEST_VERSION)"

echo "== compile TargetPortal $VERSION ($CONFIG)"
rm -rf "$PROJECT_DIR/bin" "$PROJECT_DIR/obj"
dotnet msbuild "$PROJECT_DIR/TargetPortal.csproj" -nologo -v:minimal \
	-p:Configuration="$CONFIG" -p:GamePath="$GAMEPATH" -p:TargetFrameworkRootPath="$REFASM/"

# Same inputs and switches as TargetPortal/ILRepack.targets, which only runs on Windows.
echo "== merge ServerSync, Groups and Guilds APIs into TargetPortal.dll"
OUT="$PROJECT_DIR/bin/$CONFIG"
rm -rf "$DIST_DIR"; mkdir -p "$DIST_DIR"
(cd "$OUT" && ilrepack /internalize /parallel \
	/lib:"$OUT" /lib:"$GAMEPATH/valheim_Data/Managed" /lib:"$GAMEPATH/BepInEx/core" \
	/out:"$DIST_DIR/TargetPortal.dll" \
	TargetPortal.dll ServerSync.dll GroupsAPI.dll GuildsAPI.dll) | grep -Ev '^INFO:' || true
[ -f "$DIST_DIR/TargetPortal.dll" ] || die "ILRepack produced no output"

echo "== package"
STAGE="$DIST_DIR/package"
mkdir -p "$STAGE"
cp "$DIST_DIR/TargetPortal.dll" "$REPO/thunderstore/manifest.json" "$REPO/thunderstore/icon.png" "$REPO/thunderstore/README.md" "$STAGE/"
ZIP="$DIST_DIR/TargetPortal-$VERSION.zip"
(cd "$STAGE" && python3 -c 'import sys, zipfile
with zipfile.ZipFile(sys.argv[1], "w", zipfile.ZIP_DEFLATED) as z:
	for f in sys.argv[2:]: z.write(f)' "$ZIP" manifest.json icon.png README.md TargetPortal.dll)
sha256sum "$DIST_DIR/TargetPortal.dll"
echo "built $ZIP"

if [ -n "$INSTALL_PROFILE" ]; then
	DEST="$GALE_PROFILES/$INSTALL_PROFILE/BepInEx/plugins/TargetPortal"
	[ -d "$GALE_PROFILES/$INSTALL_PROFILE" ] || die "no Gale profile '$INSTALL_PROFILE' in $GALE_PROFILES"
	[ -d "$GALE_PROFILES/$INSTALL_PROFILE/BepInEx/plugins/Smoothbrain-TargetPortal" ] \
		&& echo "warning: the official Smoothbrain-TargetPortal is also in this profile; disable it, both use the same GUID" >&2
	mkdir -p "$DEST"
	cp "$STAGE"/* "$DEST/"
	echo "installed into $DEST"
fi
