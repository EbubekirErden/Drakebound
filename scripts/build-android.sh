#!/bin/bash
set -euo pipefail
PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
export JAVA_HOME="${JAVA_HOME:-/Library/Java/JavaVirtualMachines/openjdk-21.jdk/Contents/Home}"
export ANDROID_HOME="${ANDROID_HOME:-$HOME/Library/Android/sdk}"
cd "$PROJECT_ROOT/android"
if [ "$#" -eq 0 ]; then set -- :app:assembleDebug :app:testDebugUnitTest; fi
bash ./gradlew --console=plain "$@"
