import Foundation

let allTests: [TestCase] =
    ModelTests.tests
    + IgnoreRulesTests.tests
    + ActivityClassifierTests.tests
    + TimeGroupingTests.tests
    + ActivityStoreTests.tests
    + PinStoreTests.tests

let failed = TestKit.run(allTests, filter: CommandLine.arguments.dropFirst().first)
exit(failed == 0 ? 0 : 1)
