#!/usr/bin/env bash
# Compare two builds method by method, ignoring everything that differs between any two compiles.
#
#   tools/il-diff.sh old.dll new.dll            # methods that were added (>), removed (<) or changed
#   tools/il-diff.sh old.dll new.dll <filter>   # full IL of the matching methods in both, side by side
#
# Typical uses: what does official <version> change compared to the version before (upstream
# sometimes publishes a DLL without pushing the source), and does our build match it.
# Official DLLs are in the Gale cache: ~/.local/share/com.kesomannen.gale/cache/Smoothbrain-TargetPortal/<version>/
set -euo pipefail
. "$(dirname "$0")/env.sh"
[ $# -ge 2 ] || die "usage: $0 old.dll new.dll [method filter]"

PROJ="$REPO/tools/ildump"
[ -f "$PROJ/bin/Release/net10.0/ildump.dll" ] || dotnet build "$PROJ" -c Release -v q -nologo >/dev/null
# Compiler-generated attribute classes: each ILRepack version dedupes them differently.
NOISE='^. (System\.Runtime\.CompilerServices|Microsoft\.CodeAnalysis)\.'
ildump() { dotnet "$PROJ/bin/Release/net10.0/ildump.dll" "$@"; }

if [ $# -ge 3 ]; then
	diff -u --label "$1" --label "$2" <(ildump "$1" "$3") <(ildump "$2" "$3") || true
else
	changes="$(diff <(ildump "$1" | sort) <(ildump "$2" | sort) | grep -E '^[<>]' | grep -Ev "$NOISE" || true)"
	echo "${changes:-no differences in method bodies}"
fi
