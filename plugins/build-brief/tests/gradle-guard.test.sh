#!/usr/bin/env bash
# Tests du hook gradle-guard.py : bash plugins/build-brief/tests/gradle-guard.test.sh
set -u
hook=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/hooks/gradle-guard.py
fails=0

# Faux build-brief dans le PATH : le hook ne dépend pas de celui de la machine.
fake=$(mktemp -d)
trap 'rm -rf "$fake"' EXIT
printf '#!/bin/sh\n[ "$1" = rewrite ] && echo "build-brief $2"\n' > "$fake/build-brief"
chmod +x "$fake/build-brief"
path_with=$fake:/usr/bin:/bin
path_without=/usr/bin:/bin

run() { # run <PATH> <commande> → sortie du hook
  jq -n --arg c "$2" '{tool_name: "Bash", tool_input: {command: $c}}' | PATH=$1 python3 "$hook"
}

expect() { # expect deny|allow <commande> [PATH]
  local out got
  out=$(run "${3:-$path_with}" "$2")
  if printf '%s' "$out" | grep -q '"permissionDecision": "deny"'; then got=deny; else got=allow; fi
  if [ "$got" = "$1" ]; then
    printf 'ok    %-5s %s\n' "$1" "$2"
  else
    printf 'FAIL  %-5s %s (obtenu : %s)\n' "$1" "$2" "$got"; fails=$((fails + 1))
  fi
}

expect deny './gradlew tasks'
expect deny 'gradle build'
expect deny 'cd x && ./gradlew test'
expect deny './gradlew test | tail -50'
expect deny 'FOO=1 gradle build'
expect deny '(cd x; ./gradlew test)'
expect deny '/opt/gradle/bin/gradle build'
expect deny 'time ./gradlew test'
expect deny 'build-brief ./gradlew a && ./gradlew b'
expect deny $'ls\n./gradlew test'
expect deny 'echo $(./gradlew -q properties)'
expect deny './gradlew --stop && ./gradlew test'

expect allow 'build-brief ./gradlew tasks'
expect allow 'build-brief gradle --stacktrace test'
expect allow 'build-brief --mode raw ./gradlew test --info'
expect allow 'cd x && build-brief ./gradlew test | tail'
expect allow 'ls -la'
expect allow 'echo "./gradlew test"'
expect allow 'git commit -m "fix gradle build && ./gradlew"'
expect allow 'grep gradle build.gradle'
expect allow 'cat gradlew'
expect allow 'BUILD_BRIEF_BYPASS=1 ./gradlew test'
expect allow './gradlew --stop'
expect allow 'gradle --version'
expect allow $'cat <<EOF > x.md\n./gradlew test\nEOF'
expect allow 'echo "non fermé'
expect allow './gradlew tasks' "$path_without"

out=$(echo '{"tool_input":{}}' | PATH=$path_with python3 "$hook")
if [ -z "$out" ]; then echo 'ok    allow (entrée sans command)'; else echo 'FAIL  allow (entrée sans command)'; fails=$((fails + 1)); fi

out=$(run "$path_with" './gradlew tasks')
if printf '%s' "$out" | grep -q 'Relancer : build-brief ./gradlew tasks'; then
  echo 'ok    message : commande proposée'
else
  echo "FAIL  message : commande proposée ($out)"; fails=$((fails + 1))
fi

[ "$fails" -eq 0 ] && echo "tous les tests passent" || { echo "$fails échec(s)"; exit 1; }
