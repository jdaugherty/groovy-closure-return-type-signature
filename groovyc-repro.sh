#!/usr/bin/env bash
# The same difference with groovyc alone, no build tool involved. Uses groovyc from the PATH, or the command in
# the GROOVYC environment variable. Any Groovy 4 or 5 version shows it.
set -euo pipefail
cd "$(dirname "$0")"
GROOVYC=${GROOVYC:-groovyc}
command -v "${GROOVYC%% *}" > /dev/null || { echo "groovyc not found; put it on the PATH or set GROOVYC"; exit 1; }

SRC=lib/src/main/groovy/example
OUT=build/groovyc
rm -rf "$OUT"
mkdir -p "$OUT/together" "$OUT/first" "$OUT/second"

echo "== Svc compiled together with Res"
$GROOVYC -d "$OUT/together" "$SRC/Up.groovy" "$SRC/Res.groovy" "$SRC/Util.groovy" "$SRC/Svc.groovy"
echo "== Svc compiled against the compiled Res"
$GROOVYC -d "$OUT/first" "$SRC/Up.groovy" "$SRC/Res.groovy" "$SRC/Util.groovy"
$GROOVYC -d "$OUT/second" -cp "$OUT/first" "$SRC/Svc.groovy"

echo
echo "== doCall of Svc\$_load_closure1, compiled together then against the compiled Res:"
javap -p -cp "$OUT/together" 'example.Svc$_load_closure1' | grep 'doCall'
echo "   ---"
javap -p -cp "$OUT/second" 'example.Svc$_load_closure1' | grep 'doCall'
