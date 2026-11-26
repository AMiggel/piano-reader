import Foundation
import Observation

@Observable
final class Metronome {
    /// Tiempo actual dentro del compás (0 = primero); -1 = detenido.
    private(set) var beat = -1

    /// (número de clic desde que arrancó, momento programado del clic en systemUptime).
    @ObservationIgnored var onBeat: ((Int, TimeInterval) -> Void)?
    @ObservationIgnored private var timer: DispatchSourceTimer?
    @ObservationIgnored private let queue = DispatchQueue(label: "metronome", qos: .userInteractive)

    func start(bpm: Int, meter: Meter, click: Bool) {
        stop()
        var count = 0
        var first: TimeInterval = 0
        let interval = 60.0 / Double(max(bpm, 20))
        let beats = meter.beats
        let accents = meter.accents
        let timer = DispatchSource.makeTimerSource(flags: .strict, queue: queue)
        timer.schedule(deadline: .now() + 0.2, repeating: interval, leeway: .milliseconds(1))
        timer.setEventHandler { [weak self] in
            let number = count
            if number == 0 { first = ProcessInfo.processInfo.systemUptime }
            let time = first + Double(number) * interval
            let index = number % beats
            count += 1
            if click { SoundEngine.shared.click(accent: accents.contains(index)) }
            DispatchQueue.main.async {
                guard let self, self.timer != nil else { return }
                self.beat = index
                self.onBeat?(number, time)
            }
        }
        self.timer = timer
        timer.resume()
    }

    func stop() {
        timer?.cancel()
        timer = nil
        beat = -1
    }

    deinit {
        timer?.cancel()
    }
}
