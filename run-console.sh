#!/usr/bin/env bash
#
# run-console.sh — builds the demo test assembly and runs it with the
#                  NUnit3 Console Runner, writing TestResult.xml (nunit3).
#
# Requires: .NET SDK (net10.0 project). The runner itself is fetched as a
# NuGet tool package by `dotnet build` — nothing to install.

set -euo pipefail
cd "$(dirname "$0")"

RUNNER="$HOME/.nuget/packages/nunit.consolerunner.netcore/3.22.0/tools/net8.0/any/nunit3-console.dll"
ASM="tests/bin/Release/net10.0/NunitDemo.Tests.dll"
OUT="TestResult.xml"

dotnet build tests -c Release --nologo -v q

dotnet "$RUNNER" "$ASM" --result="$OUT;format=nunit3"
