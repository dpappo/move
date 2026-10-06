import Foundation

struct Movement: Identifiable, Equatable {
    /// Where you are for a movement. Routines start in your chair, because that's where the reminder finds you.
    enum Posture { case seated, rising, standing }

    let id: Int
    let title: String
    let hint: String
    let cue: String
    let symbol: String
    let motion: Motion
    let posture: Posture
    let seconds: Double

    /// The short "stand up" moment between the seated and standing halves; not listed as an exercise.
    var isTransition: Bool { motion == .standUp }

    /// Three routines of about 3 minutes each, rotating break to break. Each one starts with what you can do
    /// in your chair (upper body and neck), then gets you on your feet to wake up the legs, and gives most
    /// of the time to walking. Between them they move the spine every way (back, side, twist).
    static let routines: [[Movement]] = [standAndStretch, reachAndRise, twistAndHinge]

    /// For when you can't get up, say at a table with colleagues: about 2 minutes, all in your chair, small enough
    /// to do without fuss. The legs still get moving, through lifts, marches and extensions under the desk.
    static let seatedRoutines: [[Movement]] = [loosenUp, marchAndReach, twistAndTap]

    static func routine(forBreak index: Int, seated: Bool = false) -> [Movement] {
        let routines = seated ? seatedRoutines : routines
        return routines[index % routines.count]
    }

    /// Every movement you can swap in, each motion once, in routine order (so "Walk around" stands in for all the walks).
    private static let swappable: [Movement] = {
        var seen = Set<Motion>()
        return (routines + seatedRoutines).joined()
            .filter { !$0.isTransition && $0.posture != .rising && seen.insert($0.motion).inserted }
    }()

    /// Something else to do in place of `movement`: in your chair for a chair movement, on your feet otherwise,
    /// and never a motion the routine already has. Swapping again carries on down the list, so it cycles through them all.
    static func alternative(to movement: Movement, in routine: [Movement]) -> Movement? {
        let posture: Posture = movement.posture == .seated ? .seated : .standing
        let candidates = swappable.filter { $0.posture == posture }
        guard !candidates.isEmpty else { return nil }
        let taken = Set(routine.map(\.motion))
        let start = candidates.firstIndex { $0.motion == movement.motion } ?? candidates.count - 1
        return candidates.indices
            .map { candidates[(start + 1 + $0) % candidates.count] }
            .first { !taken.contains($0.motion) }
    }

    static func standUp(id: Int) -> Movement {
        Movement(id: id,
                 title: "Stand up",
                 hint: "The rest is on your feet",
                 cue: "Push your chair back and stand up. The rest is on your feet.",
                 symbol: "figure.stand",
                 motion: .standUp,
                 posture: .rising,
                 seconds: 6)
    }

    private static let standAndStretch: [Movement] = [
        Movement(id: 0,
                 title: "Roll & squeeze shoulders",
                 hint: "Roll back, then squeeze shoulder blades",
                 cue: "A few slow rolls back and down, then squeeze your shoulder blades together and let go.",
                 symbol: "figure.cooldown",
                 motion: .shoulderRolls,
                 posture: .seated,
                 seconds: 25),
        Movement(id: 1,
                 title: "Tuck & turn your neck",
                 hint: "Chin back, then slow turns",
                 cue: "Slide your chin straight back, then turn slowly to look left and right. Keep it easy.",
                 symbol: "figure.mind.and.body",
                 motion: .neckTurns,
                 posture: .seated,
                 seconds: 20),
        standUp(id: 2),
        Movement(id: 3,
                 title: "Stand tall & lean back",
                 hint: "Hands on hips, gentle lean back",
                 cue: "Reach tall, then put your hands on your hips and lean back gently. Repeat a few times.",
                 symbol: "figure.stand",
                 motion: .standTall,
                 posture: .standing,
                 seconds: 20),
        Movement(id: 4,
                 title: "Calf raises",
                 hint: "Up on your toes, down slowly",
                 cue: "Rise onto your toes, then lower slowly. Rest a hand on the desk for balance if you like.",
                 symbol: "figure.step.training",
                 motion: .calfRaises,
                 posture: .standing,
                 seconds: 20),
        Movement(id: 5,
                 title: "Walk around",
                 hint: "A lap, some water, a window",
                 cue: "Take a lap, refill your water, and rest your eyes on something far away.",
                 symbol: "figure.walk",
                 motion: .walk,
                 posture: .standing,
                 seconds: 90),
    ]

    private static let reachAndRise: [Movement] = [
        Movement(id: 0,
                 title: "Ease your neck",
                 hint: "Gentle tilts, look up and down",
                 cue: "Ear toward each shoulder, then look slowly up and down. Only as far as feels easy.",
                 symbol: "figure.mind.and.body",
                 motion: .neckTilts,
                 posture: .seated,
                 seconds: 20),
        Movement(id: 1,
                 title: "Reach & side bend",
                 hint: "Arms up, lean side to side",
                 cue: "Reach both arms overhead, then lean gently to one side and the other. Keep breathing.",
                 symbol: "figure.flexibility",
                 motion: .sideBend,
                 posture: .seated,
                 seconds: 20),
        Movement(id: 2,
                 title: "Sit to stand",
                 hint: "8–10 slow reps, finish on your feet",
                 cue: "Stand up and sit back down, 8 to 10 times, hands off if you can. Finish on your feet.",
                 symbol: "figure.strengthtraining.functional",
                 motion: .sitToStand,
                 posture: .rising,
                 seconds: 20),
        Movement(id: 3,
                 title: "Open your chest",
                 hint: "Hands clasped behind, shoulders back",
                 cue: "Clasp your hands behind you and draw your shoulders back and down. Breathe slowly.",
                 symbol: "figure.arms.open",
                 motion: .chestOpener,
                 posture: .standing,
                 seconds: 25),
        Movement(id: 4,
                 title: "Take a longer walk",
                 hint: "Stairs, a hallway, a window",
                 cue: "Go a little farther: stairs or a hallway. Let your eyes rest on something far away.",
                 symbol: "figure.stairs",
                 motion: .walk,
                 posture: .standing,
                 seconds: 90),
    ]

    private static let twistAndHinge: [Movement] = [
        Movement(id: 0,
                 title: "Twist your upper back",
                 hint: "Arms crossed, slow turns",
                 cue: "Cross your arms over your chest and turn slowly left and right. Let your head follow.",
                 symbol: "figure.core.training",
                 motion: .twist,
                 posture: .seated,
                 seconds: 20),
        Movement(id: 1,
                 title: "Stretch your wrists",
                 hint: "Palm up, then palm down",
                 cue: "Arm out, gently pull your fingers back with your palm up, then down. Switch arms.",
                 symbol: "hand.raised",
                 motion: .wristStretch,
                 posture: .seated,
                 seconds: 20),
        standUp(id: 2),
        Movement(id: 3,
                 title: "Open your hips",
                 hint: "Step back, tuck under, ease forward",
                 cue: "Step one foot back, tuck your hips under, and ease forward. 10 seconds each side.",
                 symbol: "figure.yoga",
                 motion: .hipOpener,
                 posture: .standing,
                 seconds: 20),
        Movement(id: 4,
                 title: "Hip hinges",
                 hint: "Hips back, long spine, stand tall",
                 cue: "Hands on thighs, send your hips back with a long spine, then stand tall. 8 to 10 times.",
                 symbol: "figure.strengthtraining.traditional",
                 motion: .hipHinge,
                 posture: .standing,
                 seconds: 20),
        Movement(id: 5,
                 title: "Walk & breathe",
                 hint: "A lap, then three slow breaths",
                 cue: "Take a lap. Finish with three slow breaths, breathing out longer than you breathe in.",
                 symbol: "figure.walk",
                 motion: .walk,
                 posture: .standing,
                 seconds: 90),
    ]

    // MARK: Seated only

    private static let loosenUp: [Movement] = [
        standAndStretch[0],
        standAndStretch[1],
        roundAndArch(id: 2),
        heelToeLifts(id: 3),
        legExtensions(id: 4),
    ]

    private static let marchAndReach: [Movement] = [
        reachAndRise[0],
        reachAndRise[1],
        seatedMarch(id: 2),
        legExtensions(id: 3),
        roundAndArch(id: 4),
    ]

    private static let twistAndTap: [Movement] = [
        twistAndHinge[0],
        twistAndHinge[1],
        standAndStretch[0].with(id: 2),
        heelToeLifts(id: 3),
        seatedMarch(id: 4),
    ]

    private static func roundAndArch(id: Int) -> Movement {
        Movement(id: id,
                 title: "Round & arch your back",
                 hint: "Slowly, with your breath",
                 cue: "Hands on your thighs. Round your back as you breathe out, then lift your chest as you breathe in.",
                 symbol: "figure.yoga",
                 motion: .catCow,
                 posture: .seated,
                 seconds: 25)
    }

    private static func heelToeLifts(id: Int) -> Movement {
        Movement(id: id,
                 title: "Heel & toe lifts",
                 hint: "Toes up, then heels up",
                 cue: "Feet flat. Lift your toes, then press down through them to lift your heels. Keep it going.",
                 symbol: "shoeprints.fill",
                 motion: .heelToeLifts,
                 posture: .seated,
                 seconds: 25)
    }

    private static func legExtensions(id: Int) -> Movement {
        Movement(id: id,
                 title: "Straighten your legs",
                 hint: "One at a time, toes toward you",
                 cue: "Straighten one leg out under the desk, toes toward you, and hold. Lower it and switch.",
                 symbol: "figure.seated.side",
                 motion: .legExtensions,
                 posture: .seated,
                 seconds: 30)
    }

    private static func seatedMarch(id: Int) -> Movement {
        Movement(id: id,
                 title: "March in your chair",
                 hint: "Lift one knee, then the other",
                 cue: "Sit tall and lift one knee, then the other, like marching in place. Keep a steady rhythm.",
                 symbol: "figure.walk.motion",
                 motion: .seatedMarch,
                 posture: .seated,
                 seconds: 30)
    }

    func with(id: Int) -> Movement {
        Movement(id: id, title: title, hint: hint, cue: cue, symbol: symbol, motion: motion, posture: posture, seconds: seconds)
    }
}
