import Foundation

/// The promo's music and sound effects, synthesized from scratch (no samples, nothing licensed) and timed to `Cue`.
struct Soundtrack {
    static let sampleRate = 48_000.0
    private var music: [[Float]]
    private var effects: [[Float]]
    private var noiseState: UInt32 = 0x1234_5678

    init() {
        let count = Int(Cue.duration * Self.sampleRate)
        music = [[Float](repeating: 0, count: count), [Float](repeating: 0, count: count)]
        effects = music
    }

    // MARK: - Building blocks

    private mutating func noise() -> Double {
        noiseState = noiseState &* 1_664_525 &+ 1_013_904_223
        return Double(noiseState >> 8) / Double(1 << 24) * 2 - 1
    }

    /// Adds `length` seconds starting at `time`; `voice` returns a sample for local time `t`.
    private mutating func add(to bus: WritableKeyPath<Soundtrack, [[Float]]>, at time: Double, length: Double, gain: Double,
                              pan: Double = 0, _ voice: (inout Soundtrack, Double) -> Double) {
        let start = Int(time * Self.sampleRate)
        let count = Int(length * Self.sampleRate)
        let left = Float(gain * min(1, 1 - pan)), right = Float(gain * min(1, 1 + pan))
        let total = self[keyPath: bus][0].count
        for i in 0..<count {
            let index = start + i
            guard index >= 0, index < total else { continue }
            let sample = Float(voice(&self, Double(i) / Self.sampleRate))
            self[keyPath: bus][0][index] += sample * left
            self[keyPath: bus][1][index] += sample * right
        }
    }

    private static func frequency(_ midi: Double) -> Double { 440 * pow(2, (midi - 69) / 12) }

    // MARK: - Drums

    mutating func kick(_ time: Double, gain: Double = 1) {
        var phase = 0.0
        add(to: \.music, at: time, length: 0.45, gain: gain) { _, t in
            phase += 2 * .pi * (45 + 115 * exp(-t * 28)) / Self.sampleRate
            return sin(phase) * exp(-t * 7) + (t < 0.003 ? 0.4 : 0)
        }
    }

    mutating func clap(_ time: Double, gain: Double = 0.5) {
        var low = 0.0
        add(to: \.music, at: time, length: 0.25, gain: gain) { s, t in
            let n = s.noise()
            low += 0.25 * (n - low)
            let bursts = (t < 0.03 ? (sin(t * 2 * .pi * 100) > 0 ? 1.0 : 0.4) : 1.0)
            return (n - low) * exp(-t * 18) * bursts
        }
    }

    mutating func hat(_ time: Double, gain: Double = 0.18, open: Bool = false) {
        var low = 0.0
        add(to: \.music, at: time, length: open ? 0.25 : 0.06, gain: gain, pan: 0.2) { s, t in
            let n = s.noise()
            low += 0.6 * (n - low)
            return (n - low) * exp(-t * (open ? 14 : 70))
        }
    }

    mutating func snareRoll(from start: Double, to end: Double) {
        var time = start
        while time < end {
            let p = (time - start) / (end - start)
            clap(time, gain: 0.15 + 0.35 * p)
            time += p < 0.5 ? 0.125 : 0.0625
        }
    }

    // MARK: - Pitched voices

    mutating func bass(_ midi: Double, _ time: Double, length: Double, gain: Double = 0.42) {
        let f = Self.frequency(midi)
        var phase = 0.0, low = 0.0
        add(to: \.music, at: time, length: length, gain: gain) { _, t in
            phase = (phase + f / Self.sampleRate).truncatingRemainder(dividingBy: 1)
            let saw = phase * 2 - 1
            low += (0.04 + 0.2 * exp(-t * 18)) * (saw - low)
            let env = min(1, t / 0.005) * min(1, (length - t) / 0.02)
            return (low * 0.8 + sin(phase * 2 * .pi) * 0.5) * env
        }
    }

    mutating func pad(_ notes: [Double], _ time: Double, length: Double, gain: Double = 0.1, brightness: Double = 0.06) {
        for (index, midi) in notes.enumerated() {
            for detune in [-0.09, 0.09] {
                let f = Self.frequency(midi + detune)
                var phase = Double(index) * 0.3, low = 0.0
                add(to: \.music, at: time, length: length + 0.6, gain: gain, pan: detune * 6) { _, t in
                    phase = (phase + f / Self.sampleRate).truncatingRemainder(dividingBy: 1)
                    low += brightness * ((phase * 2 - 1) - low)
                    let env = min(1, t / 0.35) * (t > length ? exp(-(t - length) * 6) : 1)
                    return low * env
                }
            }
        }
    }

    mutating func pluck(_ midi: Double, _ time: Double, gain: Double = 0.16, pan: Double = 0) {
        let f = Self.frequency(midi)
        var phase = 0.0, low = 0.0
        add(to: \.music, at: time, length: 0.35, gain: gain, pan: pan) { _, t in
            phase = (phase + f / Self.sampleRate).truncatingRemainder(dividingBy: 1)
            let square = phase < 0.5 ? 1.0 : -1.0
            low += (0.05 + 0.5 * exp(-t * 30)) * (square - low)
            return low * exp(-t * 11)
        }
    }

    // MARK: - Effects

    /// The namesake: a laser "biu", a fast falling chirp.
    mutating func biu(_ time: Double, pan: Double, gain: Double = 0.55) {
        var phase = 0.0
        add(to: \.effects, at: time, length: 0.4, gain: gain, pan: pan) { _, t in
            let f = 180 + 2300 * exp(-t * 16) + 40 * sin(t * 2 * .pi * 35)
            phase += 2 * .pi * f / Self.sampleRate
            return tanh(2.5 * sin(phase)) * min(1, t / 0.002) * exp(-t * 8)
        }
    }

    mutating func boom(_ time: Double, gain: Double = 0.9, length: Double = 1.4) {
        var phase = 0.0, low = 0.0
        add(to: \.effects, at: time, length: length, gain: gain) { s, t in
            phase += 2 * .pi * (32 + 60 * exp(-t * 8)) / Self.sampleRate
            let n = s.noise()
            low += 0.02 * (n - low)
            return sin(phase) * exp(-t * 2.8) + low * 3 * exp(-t * 5)
        }
    }

    mutating func whoosh(_ time: Double, length: Double, gain: Double = 0.35, rising: Bool = false) {
        var low = 0.0
        add(to: \.effects, at: time, length: length, gain: gain, pan: 0) { s, t in
            let x = t / length
            let cutoff = rising ? 0.005 + 0.3 * x * x : 0.02 + 0.25 * sin(x * .pi)
            low += cutoff * (s.noise() - low)
            let env = rising ? x * x : sin(x * .pi)
            return low * env * 3
        }
    }

    mutating func click(_ time: Double, gain: Double = 0.25, pitch: Double = 1800) {
        var phase = 0.0
        add(to: \.effects, at: time, length: 0.05, gain: gain) { s, t in
            phase += 2 * .pi * pitch / Self.sampleRate
            return (sin(phase) * 0.6 + s.noise() * 0.4) * exp(-t * 120)
        }
    }

    mutating func pop(_ time: Double, gain: Double = 0.35) {
        var phase = 0.0
        add(to: \.effects, at: time, length: 0.15, gain: gain) { _, t in
            phase += 2 * .pi * (500 + 900 * min(1, t / 0.05)) / Self.sampleRate
            return sin(phase) * exp(-t * 30)
        }
    }

    mutating func sparkle(_ time: Double, seed: Int, gain: Double = 0.12) {
        for k in 0..<3 {
            let f = 2000 + Double((seed * 7 + k * 13) % 17) * 150
            var phase = 0.0
            add(to: \.effects, at: time + Double(k) * 0.03, length: 0.3, gain: gain, pan: Double(k - 1) * 0.5) { _, t in
                phase += 2 * .pi * f / Self.sampleRate
                return sin(phase) * exp(-t * 14)
            }
        }
    }

    // MARK: - The arrangement

    /// A minor: Am, F, C, G, one chord per bar of 2 seconds.
    private static let chords: [[Double]] = [[57, 60, 64], [57, 60, 65], [55, 60, 64], [55, 59, 62]]
    private static let roots: [Double] = [45, 41, 48, 43]

    private mutating func groove(from start: Double, bars: Int, arp: Bool) {
        for bar in 0..<bars {
            let time = start + Double(bar) * 2
            let chord = bar % 4
            pad(Self.chords[chord], time, length: 2)
            for beat in 0..<4 {
                let b = time + Double(beat) * 0.5
                kick(b)
                if beat % 2 == 1 { clap(b) }
                hat(b + 0.25, open: beat == 3)
                hat(b + 0.125, gain: 0.06)
                hat(b + 0.375, gain: 0.06)
                bass(Self.roots[chord], b, length: 0.22)
                bass(Self.roots[chord] + (beat == 3 ? 7 : 12), b + 0.25, length: 0.2, gain: 0.3)
            }
            if arp {
                let pattern = [0, 1, 2, 1, 2, 0, 1, 2]
                for step in 0..<16 {
                    let note = Self.chords[chord][pattern[step % 8]] + 12 + (step >= 8 && step % 4 == 2 ? 12 : 0)
                    pluck(note, time + Double(step) * 0.125, pan: step % 2 == 0 ? -0.4 : 0.4)
                }
            }
        }
    }

    mutating func compose() {
        // 1. Cold open: a low pad, a clock that speeds up, then the pile-up.
        pad([45, 52, 57], 0, length: 7, gain: 0.09, brightness: 0.02)
        for beat in 0..<14 {
            click(Double(beat) * 0.5, gain: 0.18, pitch: beat % 2 == 0 ? 2600 : 2100)
        }
        var tick = Cue.rainStart
        while tick < Cue.freeze {
            click(tick, gain: 0.12, pitch: 2400)
            tick += 0.25 - 0.15 * (tick - Cue.rainStart) / (Cue.freeze - Cue.rainStart)
        }
        for index in 0..<40 { pop(Cue.rainStart + 2.6 * sqrt(Double(index) / 40) + 0.5, gain: 0.08) }
        whoosh(Cue.rainStart, length: Cue.freeze - Cue.rainStart, gain: 0.3, rising: true)
        boom(Cue.whereIsIt, gain: 0.5, length: 1)

        // 2. Silence, a heartbeat, the shortcut: biu biu.
        kick(Cue.freeze, gain: 0.6)
        kick(Cue.freeze + 0.5, gain: 0.45)
        whoosh(Cue.freeze + 0.2, length: Cue.press - Cue.freeze - 0.2, gain: 0.25, rising: true)
        click(Cue.press - 0.06, gain: 0.4, pitch: 1500)
        biu(Cue.press, pan: -0.4)
        biu(Cue.secondBiu, pan: 0.4)
        boom(Cue.press, gain: 0.7)
        for beat in [8.5, 9.0, 9.5] { kick(beat, gain: 0.5) }
        snareRoll(from: 9.0, to: Cue.drop)
        whoosh(8.8, length: Cue.drop - 8.8, gain: 0.3, rising: true)

        // 3–9. The groove, with the arpeggio from the tabs onward.
        boom(Cue.drop, gain: 0.6)
        groove(from: Cue.drop, bars: 3, arp: false)
        groove(from: 16, bars: 13, arp: true)
        for time in Cue.tabSwitches { click(time - 0.08, gain: 0.3) }
        for time in Cue.typing { click(time - 0.04, gain: 0.3, pitch: 2200) }
        whoosh(Cue.fullScreenIn, length: 0.5, gain: 0.35)
        click(Cue.fullScreenPress - 0.05, gain: 0.35, pitch: 1500)
        biu(Cue.fullScreenPress, pan: 0.2)
        whoosh(Cue.dragStart, length: Cue.drop2 - Cue.dragStart, gain: 0.25)
        pop(Cue.drop2)
        click(Cue.spacePress - 0.05, gain: 0.35, pitch: 1300)
        whoosh(Cue.spacePress + 0.05, length: 0.4, gain: 0.25)
        click(Cue.pinPress - 0.05, gain: 0.35, pitch: 1500)
        pop(Cue.pinPress + 0.15, gain: 0.3)
        click(Cue.rightClick, gain: 0.3)
        click(36.4, gain: 0.15)
        click(Cue.ignoreClick, gain: 0.3)
        whoosh(Cue.ignoreClick, length: 0.35, gain: 0.25)
        click(Cue.ejectClick, gain: 0.35, pitch: 1200)
        boom(Cue.ejectClick + 0.05, gain: 0.25, length: 0.4)

        // 10. Promises: a breakdown with a hit per line.
        pad([45, 52, 57, 60], Cue.stamps[0], length: 4, gain: 0.08, brightness: 0.03)
        for time in Cue.stamps {
            boom(time, gain: 0.55, length: 0.8)
            kick(time, gain: 0.7)
        }
        for index in 0..<10 { sparkle(Cue.hellos + Double(index) * 0.1, seed: index) }

        // 11. One more thing: quiet, then the reveal.
        for (index, note) in [69.0, 72, 76, 72, 69, 72, 76, 79].enumerated() {
            pluck(note, Cue.twist + Double(index) * 0.25, gain: 0.12, pan: index % 2 == 0 ? -0.3 : 0.3)
        }
        pad([57, 60, 64], Cue.twist, length: 3, gain: 0.08)
        sparkle(Cue.twist + 0.6, seed: 3, gain: 0.15)
        whoosh(48.4, length: Cue.finale - 48.4, gain: 0.35, rising: true)
        snareRoll(from: 49.0, to: Cue.finale - 0.15)

        // 12. Finale: biu biu, one last chorus, a long A minor.
        biu(Cue.finale - 0.15, pan: -0.5)
        biu(Cue.finale + 0.1, pan: 0.5)
        boom(Cue.finale + 0.15, gain: 0.9, length: 2)
        groove(from: Cue.finale, bars: 2, arp: true)
        pad([45, 57, 60, 64], 54, length: 1, gain: 0.1)
    }

    // MARK: - Mixdown

    /// Mixes music and effects (with an echo on the effects) into 16-bit stereo WAV data.
    func wav() -> Data {
        let count = music[0].count
        let delay = Int(0.25 * Self.sampleRate)
        var mixed = [[Float]](repeating: [Float](repeating: 0, count: count), count: 2)
        var echo = effects
        for channel in 0..<2 {
            for i in delay..<count {
                echo[channel][i] += echo[1 - channel][i - delay] * 0.3
            }
        }
        var peak: Float = 0
        for channel in 0..<2 {
            for i in 0..<count {
                let fadeOut = Float(min(1, Double(count - i) / (0.6 * Self.sampleRate)))
                let x = (music[channel][i] * 0.8 + effects[channel][i] * 0.8 + echo[channel][i] * 0.25) * fadeOut
                let shaped = tanh(x * 1.3)
                mixed[channel][i] = shaped
                peak = max(peak, abs(shaped))
            }
        }
        // Headroom for the AAC encoder, which overshoots a little.
        let normalize = peak > 0 ? 0.8 / peak : 1
        var data = Data()
        func append<T: FixedWidthInteger>(_ value: T) { withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) } }
        let bytes = UInt32(count * 4)
        data.append(contentsOf: Array("RIFF".utf8)); append(UInt32(36) + bytes)
        data.append(contentsOf: Array("WAVEfmt ".utf8)); append(UInt32(16)); append(UInt16(1)); append(UInt16(2))
        append(UInt32(Self.sampleRate)); append(UInt32(Self.sampleRate * 4)); append(UInt16(4)); append(UInt16(16))
        data.append(contentsOf: Array("data".utf8)); append(bytes)
        data.reserveCapacity(data.count + Int(bytes))
        for i in 0..<count {
            for channel in 0..<2 {
                append(Int16(max(-1, min(1, mixed[channel][i] * normalize)) * 32_767))
            }
        }
        return data
    }
}
