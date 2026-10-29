#!/usr/bin/env bash
#
# Reproducer: with invokedynamic, a cast of a GroovyObject that already has the target type calls getMetaClass()
# on it (Selector$CastSelector.castAndSetGuards -> Selector$MethodSelector.setGuards). With classic call sites the
# same cast calls nothing. A Spring class-based proxy of a Groovy class forwards getMetaClass() to its target, so
# `Widget widget = context.getBean('widget')` throws ScopeNotActiveException for a step-scoped bean outside a step.
#
# Usage: ./run.sh <groovy-version> [<groovy-version> ...]   e.g. ./run.sh 5.1.3 6.0.0
#   Jars are looked up in ~/.m2/repository and the Gradle cache. Classic call sites on Groovy 6 need groovy-callsite.
set -uo pipefail
cd "$(dirname "$0")"

find_jar() { # find_jar <module> <version>
    find "${HOME}/.m2/repository/org/apache/groovy/$1/$2" "${HOME}/.gradle/caches/modules-2/files-2.1/org.apache.groovy/$1/$2" \
        -name "$1-$2.jar" 2>/dev/null | head -1
}

for version in "${@:-6.0.0}"; do
    groovy_jar=$(find_jar groovy "${version}")
    callsite_jar=$(find_jar groovy-callsite "${version}")
    if [ -z "${groovy_jar}" ]; then
        echo "${version}: groovy jar not found"; continue
    fi
    echo "== Groovy ${version}"
    for indy in true false; do
        java -Dgroovy.target.indy=${indy} -cp "${groovy_jar}${callsite_jar:+:${callsite_jar}}" groovy.ui.GroovyMain CastCallsGetMetaClass.groovy 2>&1 \
            | grep -v '^Picked up JAVA_TOOL_OPTIONS' | sed 's/^/   /'
    done
done
