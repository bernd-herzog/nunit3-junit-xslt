# nunit3-junit-xslt

> [!WARNING]
> **⚠️ This project is vibe coded.** An AI agent wrote it — end to end, from
> schema archaeology to the last comment. There was no manual coding
> involved, only intent, review and a lot of "make it prettier".
> It nevertheless works wonderfully: every conversion is validated against
> `junit.xsd`, and the demo suite exercises the full range of NUnit result
> shapes. Use it, fork it, trust it — or read it first. You cannot go wrong
> with any of the four.

# 👉 **[nunit3-to-junit.xslt — the converter](nunit3-to-junit.xslt)** 👈

That's the file you came for. Everything else here is demo, proof and
validation scaffolding.

## Why this exists

The obvious starting point for NUnit3 → JUnit conversion is the official
[nunit/nunit-transforms](https://github.com/nunit/nunit-transforms) collection.
It is archived now (issues and PRs are no longer accepted) and in practice it
did not work reliably enough to build on — so this repository exists: one
self-contained stylesheet, the schema it targets, and a test setup that
proves every conversion validates against that schema. No third-party
transform pipeline required.

An XSLT 1.0 stylesheet that converts **NUnit3** result files (written by
`nunit3-console`, `dotnet test --logger`, VSTest ...) into the **Apache Ant
JUnit XML format**, plus a demo test project that produces a report covering
the full range of NUnit result shapes.

The conversion is validated against
[`junit.xsd`](junit.xsd) (the Ant/Windy Road schema) and verified with a
real-world NUnit report (`nunit3-example.xml`, SharpZipLib).

## Usage

**In the test run** — `nunit3-console` applies XSLT transforms as part of
`--result`; repeat the option to keep the raw report and write the JUnit
report in one pass:

```
nunit3-console.exe my.tests.dll \
    --result=TestResult.xml;format=nunit3 \
    --result=junit.xml;transform=/path/to/nunit3-to-junit.xslt
```

On bash, quote the option values — the semicolon separates `format`/
`transform` for NUnit, not for your shell:

```
dotnet nunit3-console.dll my.tests.dll \
    --result="TestResult.xml;format=nunit3" \
    --result="junit.xml;transform=/path/to/nunit3-to-junit.xslt"
```

**After the test run** — any XSLT 1.0 processor applies the stylesheet to an
existing NUnit3 report:

```
xsltproc nunit3-to-junit.xslt TestResult.xml > junit.xml
xmllint --noout --schema junit.xsd junit.xml    # optional: prove it validates
```

## Demo in this repository

```
./run-console.sh      # build demo tests, write TestResult.xml (nunit3)
./convert.sh          # convert to junit-*.xml and validate against junit.xsd
```

Requirements: a .NET SDK (net10.0 project), `xsltproc` (libxslt) and
`xmllint` (libxml2-utils).

**Tested with** `NUnit 3.14.0` and `NUnit.ConsoleRunner.NetCore 3.22.0`
(nunit3-console engine 3.22) on .NET 10 / Linux. Both the runner's direct
`--result=…;transform=…` mode and post-run conversion with `xsltproc` and
.NET's `XslCompiledTransform` were verified to produce schema-valid output.
The stylesheet is plain XSLT 1.0, so any NUnit3 report producer
(`dotnet test --logger nunit`, VSTest, the Windows console runner ...)
should feed it equally well.

## Mapping

| NUnit3 | JUnit | Notes |
|---|---|---|
| `test-run` | `testsuites` | |
| leaf `test-suite[type=TestFixture]` | `testsuite` | parameterized fixtures nest; only leaf fixtures become suites so nothing is counted twice |
| `test-case result="Failed"` | `failure` | `type` = NUnit exception name |
| `test-case label="Error"` / `"Invalid"` | `error` | exception / invalid test setup rather than assertion |
| `test-case result="Warning"` | `failure` | JUnit has no warning state; counted in `failures` |
| `test-case result="Skipped"` | `skipped` | reason from `reason/message` or `reason/text` |
| `output` | `system-out` | JUnit has no per-test output; each block is tagged `[testname]` |
| `environment` | `properties` | one property per environment attribute |

Schema details handled: `properties`, `system-out` and `system-err` are
required children of `testsuite` in that order; the timestamp must be ISO
8601 without timezone; only one `failure`/`error`/`skipped` per `testcase`,
so several NUnit `<failure>` elements (`Assert.Multiple`) are merged into
one. `system-err` is always empty because the NUnit3 format merges all write
streams into a single `<output>` element.

## Files

```
nunit3-to-junit.xslt    the converter (XSLT 1.0, works with libxslt/xsltproc)
junit.xsd               Ant JUnit schema (Windy Road)
TestResult.xsd          official NUnit3 schema (reference, not xmllint-able)
junit-example.xml       minimal valid JUnit example
nunit3-example.xml      real NUnit3 report (SharpZipLib) as test input
run-console.sh          demo: build tests and write TestResult.xml
convert.sh              demo: convert + schema validation
tests/                  NUnit demo project exercising report edge cases
```

## Caveats

* The official NUnit3 XSD validates with .NET but not with `xmllint`
  ("content model not deterministic"); it is included for reference only.
* Warnings being reported as failures is a deliberate choice — change the
  `result="Warning"` branch in the stylesheet if your CI prefers otherwise.

## License

The code in this repository is MIT licensed (see [LICENSE](LICENSE)), with
two exceptions among the reference files: `junit.xsd` is Apache License 2.0
(Windy Road Technology, the Apache Ant JUnit schema) and `nunit3-example.xml`
is a test report from [SharpZipLib](https://github.com/icsharpcode/SharpZipLib)
(MIT).

