import os

package enum Log {
    package static let subsystem = "io.github.biubiu.BiuBiu"
    package static let app = Logger(subsystem: subsystem, category: "app")
    package static let sources = Logger(subsystem: subsystem, category: "sources")
    package static let persistence = Logger(subsystem: subsystem, category: "persistence")
}
