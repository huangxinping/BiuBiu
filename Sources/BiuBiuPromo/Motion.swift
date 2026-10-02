import Foundation

/// Easing and timing helpers. Times are in seconds of the video.
enum Motion {
    static func clamp(_ x: Double, _ low: Double = 0, _ high: Double = 1) -> Double { min(max(x, low), high) }

    /// 0 before `start`, 1 after `start + duration`, linear in between.
    static func progress(_ t: Double, _ start: Double, _ duration: Double) -> Double {
        clamp((t - start) / duration)
    }

    static func easeOut(_ x: Double) -> Double { 1 - pow(1 - x, 3) }
    static func easeIn(_ x: Double) -> Double { x * x * x }
    static func easeInOut(_ x: Double) -> Double { x < 0.5 ? 4 * x * x * x : 1 - pow(-2 * x + 2, 3) / 2 }

    /// Overshoots and settles, like a spring.
    static func spring(_ x: Double, bounce: Double = 1.4) -> Double {
        guard x < 1 else { return 1 }
        return 1 - exp(-6 * x) * cos(x * .pi * 2 * bounce)
    }

    /// A value that eases in at `start` and out at `end` (each over `fade`): for things that come and go.
    static func window(_ t: Double, _ start: Double, _ end: Double, fade: Double = 0.3) -> Double {
        min(easeOut(progress(t, start, fade)), 1 - easeIn(progress(t, end - fade, fade)))
    }

    static func lerp(_ a: Double, _ b: Double, _ x: Double) -> Double { a + (b - a) * x }

    /// A repeatable pseudo-random number in 0..<1 for `seed`.
    static func random(_ seed: Int) -> Double {
        var x = UInt64(bitPattern: Int64(seed)) &* 0x9E37_79B9_7F4A_7C15 &+ 0x632B_E59B_D9B4_E019
        x ^= x >> 30; x = x &* 0xBF58476D1CE4E5B9
        x ^= x >> 27; x = x &* 0x94D049BB133111EB
        x ^= x >> 31
        return Double(x % 1_000_000) / 1_000_000
    }
}

extension CGPoint {
    static func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
    func lerp(to other: CGPoint, _ x: Double) -> CGPoint {
        CGPoint(x: self.x + (other.x - self.x) * x, y: y + (other.y - y) * x)
    }
}
