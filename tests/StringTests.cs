using System.Threading.Tasks;
using NUnit.Framework;

namespace NunitDemo.Tests.Strings
{
    // parameterized fixture: the class runs once per TestFixture argument
    [TestFixture("alpha")]
    [TestFixture("")]
    [Category("Strings")]
    public class StringTests
    {
        private readonly string _seed;

        public StringTests(string seed) => _seed = seed;

        [Test]
        public void LengthMatches()
            => Assert.That(_seed.Length, Is.EqualTo(string.IsNullOrEmpty(_seed) ? 0 : 5));

        // deliberate assertion failure
        [Test]
        public void FailsWithComparison()
            => Assert.That("hello world", Has.Length.EqualTo(5), "text has the wrong length");

        // deliberate exception -> <failure> with exception type (JUnit: error)
        [Test]
        public void FailsWithException()
        {
            var values = new[] { "a" };
            _ = values[5]; // IndexOutOfRangeException
        }

        [Test]
        public async Task AsyncTestRuns()
        {
            await Task.Delay(10);
            TestContext.Progress.WriteLine("running...");
            Assert.That(await Task.FromResult("ok"), Is.EqualTo("ok"));
        }

        [Test]
        [Repeat(2)]
        public void RepeatsTwice()
            => Assert.That(_seed, Is.Not.Null);

        // generic test method with TestCase arguments of different types
        [Test]
        [TestCase(5)]
        [TestCase("text")]
        public void GenericTest<T>(T value)
            => Assert.That(value, Is.Not.Null);
    }
}
