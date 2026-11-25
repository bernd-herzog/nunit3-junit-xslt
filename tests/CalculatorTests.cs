using NUnit.Framework;
using System.Collections.Generic;

namespace NunitDemo.Tests.Math
{
    [TestFixture]
    [Category("Calc")]
    public class CalculatorTests
    {
        private int _acc;

        [OneTimeSetUp]
        public void OneTimeSetUp() => _acc = 100;

        [SetUp]
        public void SetUp() => TestContext.Out.WriteLine("SetUp ran");

        [TearDown]
        public void TearDown() => TestContext.Out.WriteLine("TearDown ran");

        [Test]
        public void AddsTwoNumbers()
        {
            Console.WriteLine("mock service: adding 2 + 3"); // ends up as <output> in the XML
            Assert.That(2 + 3, Is.EqualTo(5));
        }

        [Test]
        [TestCase(1, 1, 2)]
        [TestCase(2, 2, 4, TestName = "Doubles twos")]
        [TestCase(0, 0, 0, Category = "NullCase")]
        [TestCase(-5, 5, 0, Description = "Opposites cancel out")]
        public void TestCaseAddition(int a, int b, int expected)
            => Assert.That(a + b, Is.EqualTo(expected));

        [Test]
        public void RangeParameterized([Range(1, 3)] int n)
            => Assert.That(n, Is.GreaterThan(0));

        private static IEnumerable<int> SquareNumbers => new[] { 1, 4, 9 };

        [Test]
        [TestCaseSource(nameof(SquareNumbers))]
        public void TestCaseSourceProperty(int n)
            => Assert.That(System.Math.Sqrt(n), Is.EqualTo(System.Math.Sqrt(n)));

        private static IEnumerable<TestCaseData> DivisionCases()
        {
            yield return new TestCaseData(10, 2).Returns(5);
            yield return new TestCaseData(7, 2).Returns(3).SetArgDisplayNames("7", "2").SetCategory("Integer");
            yield return new TestCaseData(9, 3).Returns(3).SetName("NineOverThree");
        }

        [Test]
        [TestCaseSource(nameof(DivisionCases))]
        public int TestCaseSourceWithReturns(int a, int b) => a / b;

        // produces several NUnit <failure> children in one test case
        [Test]
        public void AssertMultipleWithTwoFailures()
        {
            Assert.Multiple(() =>
            {
                Assert.That(1, Is.EqualTo(2), "first assertion");
                Assert.That("a", Is.EqualTo("b"), "second assertion");
            });
        }

        [Test]
        [Ignore("demo: never executed")]
        public void Ignored()
            => Assert.Fail("must never run");

        [Test]
        [Explicit("demo: runs only when selected explicitly")]
        public void ExplicitTest()
            => Assert.Pass();

        // result="Warning", not Failed — needs a mapping decision downstream
        [Test]
        public void WarningInsteadOfFailure()
            => Assert.Warn("just a warning");
    }
}
