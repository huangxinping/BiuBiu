import Foundation

let allTests: [TestCase] =
    ModelTests.tests

let failed = TestKit.run(allTests, filter: CommandLine.arguments.dropFirst().first)
exit(failed == 0 ? 0 : 1)
