import Foundation

/// Thrown by a test that cannot run here (no Spotlight index, say); it is reported, not counted as passed.
struct SkipTest: Error {
    let reason: String
}

struct TestCase {
    let name: String
    let body: @MainActor () throws -> Void

    init(_ name: String, _ body: @escaping @MainActor () throws -> Void) {
        self.name = name
        self.body = body
    }
}

@MainActor
enum TestKit {
    static var currentFailures: [String] = []

    static func record(_ message: String, file: StaticString, line: UInt) {
        let fileName = ("\(file)" as NSString).lastPathComponent
        currentFailures.append("    \(fileName):\(line): \(message)")
    }

    /// Runs the tests whose names contain `filter` (all when nil). Returns the number of failed tests.
    static func run(_ tests: [TestCase], filter: String?) -> Int {
        let selected = tests.filter { filter == nil || $0.name.contains(filter!) }
        var failed = 0, skipped = 0
        for test in selected {
            currentFailures = []
            do {
                try test.body()
            } catch let skip as SkipTest {
                skipped += 1
                print("– \(test.name) (skipped: \(skip.reason))")
                continue
            } catch {
                currentFailures.append("    threw: \(error)")
            }
            if currentFailures.isEmpty {
                print("✓ \(test.name)")
            } else {
                failed += 1
                print("✗ \(test.name)")
                currentFailures.forEach { print($0) }
            }
        }
        print("\n\(selected.count - failed - skipped) passed, \(skipped) skipped, \(failed) failed")
        return failed
    }
}

@MainActor
func expect(_ condition: Bool, _ message: @autoclosure () -> String = "expectation failed",
            file: StaticString = #filePath, line: UInt = #line) {
    if !condition { TestKit.record(message(), file: file, line: line) }
}

@MainActor
func expectEqual<T: Equatable>(_ actual: T, _ expected: T,
                               file: StaticString = #filePath, line: UInt = #line) {
    if actual != expected { TestKit.record("expected \(expected), got \(actual)", file: file, line: line) }
}

/// A fresh temporary directory, removed by the caller with `try? FileManager.default.removeItem(at:)`.
func makeTempDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("BiuBiuTests-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url.resolvingSymlinksInPath()
}
