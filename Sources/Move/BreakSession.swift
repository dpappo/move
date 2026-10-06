import AppKit

/// State for one reminder card: the prompt, the guided routine, and the little "done" moment.
@MainActor
final class BreakSession: ObservableObject {
    enum Phase: Equatable { case prompt, guiding, finished }

    @Published private(set) var phase: Phase = .prompt
    @Published private(set) var stepIndex = 0
    @Published private(set) var elapsed: Double = 0
    @Published private(set) var breaksToday = 0
    @Published private(set) var intervalMinutes = 30
    @Published private(set) var staySeated = false
    @Published private(set) var routine = Movement.routine(forBreak: 0)

    var onDone: (() -> Void)?
    var onSnooze: ((Int) -> Void)?

    private var timer: Timer?
    private var stepStarted = Date()

    var step: Movement { routine[stepIndex] }
    var progress: Double { min(1, elapsed / step.seconds) }
    var remainingSeconds: Int { max(0, Int(ceil(step.seconds - elapsed))) }
    var totalMinutesLabel: String {
        let total = routine.reduce(0) { $0 + $1.seconds }
        return "\(Int((total / 60).rounded())) min"
    }

    func prepare() {
        stopTimer()
        phase = .prompt
        stepIndex = 0
        elapsed = 0
        breaksToday = Settings.breaksToday
        intervalMinutes = Settings.intervalMinutes
        staySeated = Settings.staySeated
        routine = Movement.routine(forBreak: breaksToday, seated: staySeated)
    }

    /// Freezes the card in a given state, for rendering README screenshots.
    func stage(_ phase: Phase, step: Int = 0, elapsed: Double = 0, breaksToday: Int, intervalMinutes: Int = 30,
               staySeated: Bool = false) {
        stopTimer()
        self.phase = phase
        self.stepIndex = step
        self.elapsed = elapsed
        self.breaksToday = breaksToday
        self.intervalMinutes = intervalMinutes
        self.staySeated = staySeated
        routine = Movement.routine(forBreak: phase == .finished ? breaksToday - 1 : breaksToday, seated: staySeated)
    }

    /// Picks the routine for this break: in your chair the whole time, or getting on your feet partway.
    func setStaySeated(_ seated: Bool) {
        guard phase == .prompt, seated != staySeated else { return }
        Settings.staySeated = seated
        staySeated = seated
        routine = Movement.routine(forBreak: breaksToday, seated: seated)
    }

    /// Trades one movement for another of the same kind, for this break only.
    func swap(_ movement: Movement) {
        guard phase == .prompt, let i = routine.firstIndex(of: movement),
              let replacement = Movement.alternative(to: movement, in: routine) else { return }
        var steps = routine
        // Sit to stand is also how you get up, so its stand-in still needs that moment first.
        steps[i...i] = movement.posture == .rising ? [Movement.standUp(id: 0), replacement] : [replacement]
        routine = steps.enumerated().map { $0.element.with(id: $0.offset) }
    }

    func canSwap(_ movement: Movement) -> Bool {
        Movement.alternative(to: movement, in: routine) != nil
    }

    func startGuide() {
        phase = .guiding
        begin(step: 0)
        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func skip() {
        advance()
    }

    func markDone() {
        if phase == .guiding { finish() } else { complete() }
    }

    func snooze(minutes: Int) {
        stopTimer()
        onSnooze?(minutes)
    }

    // MARK: Private

    private func begin(step index: Int) {
        stepIndex = index
        elapsed = 0
        stepStarted = Date()
    }

    private func tick() {
        elapsed = Date().timeIntervalSince(stepStarted)
        if elapsed >= step.seconds { advance() }
    }

    private func advance() {
        guard phase == .guiding else { return }
        if stepIndex + 1 < routine.count {
            chime("Tink")
            begin(step: stepIndex + 1)
        } else {
            finish()
        }
    }

    private func finish() {
        stopTimer()
        chime("Glass")
        breaksToday = Settings.breaksToday + 1
        phase = .finished
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.8) { [weak self] in
            guard let self, self.phase == .finished else { return }
            self.complete()
        }
    }

    private func complete() {
        stopTimer()
        onDone?()
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func chime(_ name: String) {
        guard Settings.chimes, let sound = NSSound(named: name)?.copy() as? NSSound else { return }
        sound.volume = 0.25
        sound.play()
    }
}
