#!/usr/bin/env bash
# Rebuild a committed API stub (TargetPortal/GuildsAPI.dll or GroupsAPI.dll) from the mod's source.
#
#   tools/rebuild-api-stub.sh guilds [git-ref]
#   tools/rebuild-api-stub.sh groups [git-ref]
#
# The stub is merged into TargetPortal.dll, and while the real mod is absent its code is what runs;
# when the real mod is loaded it takes over. Some stub code (e.g. Guilds' PlayerReference.forOwnPlayer)
# always runs from the stub, so a stub built from old source silently breaks the integration after
# the real mod changes. Rebuild it whenever Guilds/Groups ship a release that touches their API.
set -euo pipefail
. "$(dirname "$0")/env.sh"

case "${1:-}" in
	guilds) NAME=Guilds ;;
	groups) NAME=Groups ;;
	*) die "usage: $0 guilds|groups [git-ref]" ;;
esac
REF="${2:-}"
[ -d "$GAMEPATH" ] || die "run tools/setup.sh first"

SRC="$TOOLS_DIR/src/$NAME"
if [ -d "$SRC/.git" ]; then
	git -C "$SRC" fetch -q origin
else
	git clone -q "https://github.com/blaxxun-boop/$NAME.git" "$SRC"
fi
git -C "$SRC" checkout -q "${REF:-origin/HEAD}"
echo "== $NAME at $(git -C "$SRC" log -1 --format='%h %ad %s' --date=short)"

# Both repos have an "API" configuration that compiles only the public API surface.
PROJ="$SRC/$NAME/$NAME.csproj"

# packages.config style projects refuse to build without their ..\packages\<id>.<version> folders.
for pkg in $(grep -o 'packages\\[^\\]*\\build' "$PROJ" | sed 's/packages\\\(.*\)\\build/\1/' | sort -u); do
	[ -d "$SRC/packages/$pkg" ] && continue
	id="$(echo "$pkg" | sed 's/\.[0-9][0-9.]*$//')"; ver="${pkg#"$id".}"
	mkdir -p "$SRC/packages/$pkg"
	curl -fsSL -o "$SRC/packages/$pkg.nupkg" "https://www.nuget.org/api/v2/package/$id/$ver"
	(cd "$SRC/packages/$pkg" && unzip -qo "../$pkg.nupkg")
done
rm -rf "$SRC/$NAME/bin/API" "$SRC/$NAME/obj"
# Their csproj renames the output with a Windows "move" after building, which fails here; that is
# the only failure tolerated, a real compile error leaves no DLL behind and stops below.
dotnet msbuild "$PROJ" -nologo -v:minimal \
	-p:Configuration=API -p:GamePath="$GAMEPATH" -p:TargetFrameworkRootPath="$REFASM/" \
	|| echo "(msbuild failed; fine if it was only the Windows 'move' step)"

BUILT=""
for f in "$SRC/$NAME/bin/API/${NAME}API.dll" "$SRC/$NAME/bin/API/$NAME.dll"; do
	[ -f "$f" ] && BUILT="$f" && break
done
[ -n "$BUILT" ] || die "no $NAME API DLL was built, see the msbuild errors above"
cp "$BUILT" "$PROJECT_DIR/${NAME}API.dll"
echo "updated TargetPortal/${NAME}API.dll from $NAME $(git -C "$SRC" rev-parse --short HEAD); commit it with that hash in the message"
