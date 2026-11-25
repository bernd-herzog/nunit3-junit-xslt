using System;
using NUnit.Framework;

namespace NunitDemo.Tests.Chaos;

// Deliberately exotic cases: every write stream, special characters in
// failure messages, [Repeat], [Combinatorial], retry — the edge cases a
// NUnit3 to JUnit converter has to handle.

[TestFixture, Category("Chaos")]
public class StreamsAndChaos
{
    private static int retries;

    // every write path must end up in the report's <output>
    [Test, Category("Output")]
    public void WritesToAllStreams()
    {
        Console.Out.WriteLine("classic Console.Out line");
        Console.Error.WriteLine("classic Console.Error line");

        TestContext.Out.WriteLine("TestContext.Out line");
        TestContext.Progress.WriteLine("TestContext.Progress line");
        TestContext.Error.WriteLine("TestContext.Error line");
    }

    // < & > and quotes and umlauts inside message and values:
    // exercises XML escaping in the converted report
    [Test, Category("Output")]
    public void FailsWithSpecialCharacters()
    {
        Assert.That("<a> & 'b' — äöü", Is.EqualTo("x<y> & \"z\" — ßÄÖ"),
                    "message containing < & > \" and umlauts äöü");
    }

    // 2x2 argument matrix, one combination fails on purpose
    [Test]
    [Combinatorial]
    public void CombinatorialMatrix([Values(true, false)] bool flag,
                                    [Values(0, 10)] int value)
    {
        if (!flag && value == 10)
        {
            Assert.Fail("this combination fails deliberately");
        }
    }

    [Test, Repeat(3), Category("Output")]
    public void ThreeRepeats()
    {
        TestContext.Progress.WriteLine("repeat round");
        Assert.That(2 + 2, Is.EqualTo(4));
    }

    // [Retry(n)] means n attempts in total, not n attempts on top of the first
    [Test, Retry(3), Category("Chaos")]
    public void RetryCountsUp()
    {
        if (++retries != 3)
        {
            Assert.Fail($"attempt {retries} — expected to fail");
        }

        Assert.Pass("retry succeeded");
    }

    [Test, Explicit("manual only"), Category("Output")]
    public void OnlyWhenExplicit()
    {
        Console.WriteLine("shows up as an Explicit skip in the report");
    }
}
