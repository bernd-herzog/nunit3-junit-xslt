using System;
using NUnit.Framework;

namespace NunitDemo.Tests.Platform
{
    [TestFixture]
    public class SkippedTests
    {
        [Test]
        [Platform("win")]
        public void WindowsOnly()
            => Assert.Pass();

        [Test]
        [Platform("linux")]
        public void LinuxOnly()
            => Assert.Pass();

        [Test]
        public void SkippedAtRuntime()
            => Assert.Ignore("skipped at runtime");

        // [Retry(n)] means n attempts in total: attempt 1 fails on purpose,
        // attempt 2 succeeds and the test case is reported as passed
        [Test]
        [NonParallelizable]
        [Retry(2)]
        public void RetryEventuallySucceeds()
        {
            if (++_retryTakes == 1)
                Assert.Fail("first attempt fails deliberately");
            Assert.Pass("retry succeeded");
        }
        private static int _retryTakes;
    }

    // a throwing OneTimeSetUp blocks every test in the fixture
    [TestFixture]
    public class BrokenSetupTests
    {
        [OneTimeSetUp]
        public void OneTimeSetUp() => throw new InvalidOperationException("setup is broken");

        [Test]
        public void BlockedByBrokenSetup()
            => Assert.Pass();
    }
}
