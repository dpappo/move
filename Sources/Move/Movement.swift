import Foundation

struct Movement: Identifiable, Equatable {
    let id: Int
    let title: String
    let hint: String
    let cue: String
    let symbol: String
    let seconds: Double

    /// Three routines of about 3 minutes each, rotating break to break. Between them they move the spine
    /// every way (back, side, twist), and each one eases the upper body and neck, wakes up the legs,
    /// then gives most of the time to walking.
    static let routines: [[Movement]] = [standAndStretch, reachAndRise, twistAndHinge]

    static func routine(forBreak index: Int) -> [Movement] {
        routines[index % routines.count]
    }

    private static let standAndStretch: [Movement] = [
        Movement(id: 0,
                 title: "Stand tall & lean back",
                 hint: "Hands on hips, gentle lean back",
                 cue: "Reach tall, then put your hands on your hips and lean back gently. Repeat a few times.",
                 symbol: "figure.stand",
                 seconds: 20),
        Movement(id: 1,
                 title: "Roll & squeeze shoulders",
                 hint: "Roll back, then squeeze your shoulder blades",
                 cue: "A few slow rolls back and down, then squeeze your shoulder blades together and let go.",
                 symbol: "figure.cooldown",
                 seconds: 25),
        Movement(id: 2,
                 title: "Tuck & turn your neck",
                 hint: "Chin back, then slow turns",
                 cue: "Slide your chin straight back, then turn slowly to look left and right. Keep it easy.",
                 symbol: "figure.mind.and.body",
                 seconds: 20),
        Movement(id: 3,
                 title: "Calf raises",
                 hint: "Up on your toes, down slowly",
                 cue: "Rise onto your toes, then lower slowly. Rest a hand on the desk for balance if you like.",
                 symbol: "figure.step.training",
                 seconds: 20),
        Movement(id: 4,
                 title: "Walk around",
                 hint: "A lap, some water, a window",
                 cue: "Take a lap, refill your water, and rest your eyes on something far away.",
                 symbol: "figure.walk",
                 seconds: 90),
    ]

    private static let reachAndRise: [Movement] = [
        Movement(id: 0,
                 title: "Reach & side bend",
                 hint: "Arms up, lean side to side",
                 cue: "Reach both arms overhead, then lean gently to one side and the other. Keep breathing.",
                 symbol: "figure.flexibility",
                 seconds: 20),
        Movement(id: 1,
                 title: "Open your chest",
                 hint: "Hands clasped behind, shoulders back",
                 cue: "Clasp your hands behind you and draw your shoulders back and down. Breathe slowly.",
                 symbol: "figure.arms.open",
                 seconds: 25),
        Movement(id: 2,
                 title: "Ease your neck",
                 hint: "Gentle tilts, look up and down",
                 cue: "Ear toward each shoulder, then look slowly up and down. Only as far as feels easy.",
                 symbol: "figure.mind.and.body",
                 seconds: 20),
        Movement(id: 3,
                 title: "Sit to stand",
                 hint: "8–10 slow reps from your chair",
                 cue: "Sit down and stand back up, 8 to 10 times. Slow and steady, hands off if you can.",
                 symbol: "figure.strengthtraining.functional",
                 seconds: 20),
        Movement(id: 4,
                 title: "Take a longer walk",
                 hint: "Stairs, a hallway, a window",
                 cue: "Go a little farther: stairs or a hallway. Let your eyes rest on something far away.",
                 symbol: "figure.stairs",
                 seconds: 90),
    ]

    private static let twistAndHinge: [Movement] = [
        Movement(id: 0,
                 title: "Twist your upper back",
                 hint: "Arms crossed, slow turns",
                 cue: "Cross your arms over your chest and turn slowly left and right. Let your head follow.",
                 symbol: "figure.core.training",
                 seconds: 20),
        Movement(id: 1,
                 title: "Stretch your wrists",
                 hint: "Palm up, then palm down",
                 cue: "Arm out, gently pull your fingers back with your palm up, then down. Switch arms.",
                 symbol: "hand.raised",
                 seconds: 20),
        Movement(id: 2,
                 title: "Open your hips",
                 hint: "Step back, tuck under, ease forward",
                 cue: "Step one foot back, tuck your hips under, and ease forward. 10 seconds each side.",
                 symbol: "figure.yoga",
                 seconds: 20),
        Movement(id: 3,
                 title: "Hip hinges",
                 hint: "Hips back, long spine, stand tall",
                 cue: "Hands on thighs, send your hips back with a long spine, then stand tall. 8 to 10 times.",
                 symbol: "figure.strengthtraining.traditional",
                 seconds: 20),
        Movement(id: 4,
                 title: "Walk & breathe",
                 hint: "A lap, then three slow breaths",
                 cue: "Take a lap. Finish with three slow breaths, breathing out longer than you breathe in.",
                 symbol: "figure.walk",
                 seconds: 90),
    ]
}
