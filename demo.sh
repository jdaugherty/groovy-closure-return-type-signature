#!/usr/bin/env bash
# Shows that an incremental build changes the signature of the closure class compiled from Svc.groovy although
# Svc.groovy did not change, and that the downstream project's compile task runs because of it. Restores the
# source it edits. Pass Gradle options through, for example: ./demo.sh -PgroovyVersion=5.1.4-SNAPSHOT
set -euo pipefail
cd "$(dirname "$0")"

UTIL=lib/src/main/groovy/example/Util.groovy
CLOSURE='lib/build/classes/groovy/main/example/Svc$_load_closure1.class'
OUT=build/demo
mkdir -p "$OUT"

echo "== 1. Full build: Res and Svc are compiled together"
./gradlew --console=plain -q "$@" clean :app:compileGroovy
cp "$CLOSURE" "$OUT/closure-full.class"

echo
echo "== 2. Change a method body in Util, which Svc uses only inside a method body"
sed -i.bak "s/'loading'/'loading...'/" "$UTIL"
trap 'mv "$UTIL.bak" "$UTIL"' EXIT

echo
echo "== 3. Incremental build: Svc is recompiled against the compiled Res"
./gradlew --console=plain --info "$@" :app:compileGroovy \
    | grep -E "Task :(lib|app):compileGroovy|Incremental compilation of|None of the classes needs to be compiled|is not up-to-date because|Input property 'classpath'" || true
cp "$CLOSURE" "$OUT/closure-incremental.class"

echo
echo "== 4. doCall of Svc\$_load_closure1, full build then incremental build:"
javap -p "$OUT/closure-full.class" | grep 'doCall'
echo "   ---"
javap -p "$OUT/closure-incremental.class" | grep 'doCall'
