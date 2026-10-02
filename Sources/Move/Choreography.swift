import Foundation

/// The animation the guide plays for a movement: a small figure looping through key poses.
enum Motion {
    case standTall, shoulderRolls, neckTurns, calfRaises, walk
    case sideBend, chestOpener, neckTilts, sitToStand
    case twist, wristStretch, hipOpener, hipHinge
    case standUp
}

/// One arm or leg. Angles are in degrees, measured from hanging straight down.
struct Limb {
    var a: Double = 0   // upper arm or thigh; + is outward (facing us) or forward (in profile)
    var b: Double = 0   // elbow or knee bend, relative to the upper segment
    var c: Double = 0   // hand angle at the wrist; for feet, + points the toes down

    init(_ a: Double = 0, _ b: Double = 0, _ c: Double = 0) {
        self.a = a
        self.b = b
        self.c = c
    }
}

/// A whole-body pose. "R" limbs are the screen-right ones when the figure faces us, or the near ones in profile.
struct Pose {
    var lean: Double = 0        // tilt from upright at the hips, degrees; + toward screen right (forward, in profile)
    var bend: Double = 0        // extra curve through the spine, so the chest tilts further than the hips
    var neck: Double = 0        // head tilt relative to the chest
    var turn: Double = 0        // head turn, -1 (screen left) ... 1 (screen right)
    var nod: Double = 0         // look down (-1) ... up (1)
    var shoulders: Double = 1   // shoulder width; narrows as the upper body twists
    var shrugX: Double = 0      // shoulders sideways, or forward and back in profile
    var shrugY: Double = 0      // shoulders up and down
    var armR = Limb(), armL = Limb()
    var legR = Limb(), legL = Limb()

    var arms: Limb {
        get { armR }
        set { armR = newValue; armL = newValue }
    }

    var legs: Limb {
        get { legR }
        set { legR = newValue; legL = newValue }
    }

    func with(_ change: (inout Pose) -> Void) -> Pose {
        var pose = self
        change(&pose)
        return pose
    }

    /// The same pose with the left and right limbs traded.
    var mirrored: Pose {
        with {
            swap(&$0.armR, &$0.armL)
            swap(&$0.legR, &$0.legL)
        }
    }

    static let front = Pose(armR: Limb(7, 5), armL: Limb(7, 5), legR: Limb(3), legL: Limb(3))
    static let side = Pose(armR: Limb(-2, 10), armL: Limb(3, 12))

    /// Sitting in a chair, facing us: knees apart, hands on knees. Needs a `seated` choreography to foreshorten the thighs.
    static let seatedFront = Pose(armR: Limb(28, -40), armL: Limb(28, -40), legR: Limb(55, -55), legL: Limb(55, -55))
    /// Sitting in a chair, in profile: hands resting on the thighs.
    static let seated = Pose(lean: 3, armR: Limb(8, 62, 10), armL: Limb(10, 60, 10), legR: Limb(90, -90), legL: Limb(88, -88))

    private static let channels: [WritableKeyPath<Pose, Double>] = [
        \.lean, \.bend, \.neck, \.turn, \.nod, \.shoulders, \.shrugX, \.shrugY,
        \.armR.a, \.armR.b, \.armR.c, \.armL.a, \.armL.b, \.armL.c,
        \.legR.a, \.legR.b, \.legR.c, \.legL.a, \.legL.b, \.legL.c,
    ]

    /// A weighted mix of poses, channel by channel.
    static func blend(_ poses: [Pose], _ weights: [Double]) -> Pose {
        var out = Pose()
        for channel in channels {
            out[keyPath: channel] = zip(poses, weights).reduce(0) { $0 + $1.0[keyPath: channel] * $1.1 }
        }
        return out
    }
}

struct Choreography {
    enum Facing { case front, side }
    enum Joint { case handR, handL, shoulder }
    enum Prop { case chair, desk }

    struct Key {
        var pose: Pose
        var move: Double            // seconds to arrive from the previous key
        var hold: Double = 0        // seconds to stay here
        var flow = false            // glide through without stopping (walking, rolls) instead of easing in and out

        init(_ pose: Pose, move: Double, hold: Double = 0, flow: Bool = false) {
            self.pose = pose
            self.move = move
            self.hold = hold
            self.flow = flow
        }
    }

    var facing: Facing
    var zoom: Double = 1            // closer framing for small movements (neck, shoulders, wrists)
    var focus: Double = 94          // the height, in figure units, that sits at the middle of the frame
    var offsetX: Double = 0         // nudges figures that reach to one side back toward the middle
    var anchorHips = false          // keep the hips still instead of the feet (walking on a moving floor)
    var groundSpeed: Double = 0     // figure units per second the floor scrolls by
    var seated = false              // sitting and facing us, so the thighs point at the viewer
    var prop: Prop?
    var loops = true                // otherwise plays once and rests on the last key
    var trails: [Joint] = []        // joints that leave a soft trail, showing the path of the movement
    var keys: [Key]

    var duration: Double { keys.reduce(0) { $0 + $1.move + $1.hold } }

    /// The pose at a time since the step began, starting settled on the first key.
    func pose(at time: Double) -> Pose {
        let n = keys.count
        var t = time + keys[0].move
        t = loops ? t.truncatingRemainder(dividingBy: duration) : min(t, duration - 0.001)
        for (i, key) in keys.enumerated() {
            let previous = keys[(i + n - 1) % n].pose
            if t < key.move {
                let u = t / key.move
                if key.flow {
                    // Catmull-Rom through the neighbouring keys keeps the motion moving through each one.
                    let before = keys[(i + n - 2) % n].pose, after = keys[(i + 1) % n].pose
                    let u2 = u * u, u3 = u2 * u
                    return Pose.blend([before, previous, key.pose, after],
                                      [(-u + 2 * u2 - u3) / 2, (2 - 5 * u2 + 3 * u3) / 2,
                                       (u + 4 * u2 - 3 * u3) / 2, (u3 - u2) / 2])
                }
                let eased = (1 - cos(.pi * u)) / 2
                return Pose.blend([previous, key.pose], [1 - eased, eased])
            }
            t -= key.move
            if t < key.hold { return key.pose }
            t -= key.hold
        }
        return keys[0].pose
    }
}

private typealias Key = Choreography.Key

extension Motion {
    var choreography: Choreography {
        switch self {
        case .standTall:
            let reach = Pose.side.with { $0.armR = Limb(174); $0.armL = Limb(179); $0.bend = -4; $0.nod = 0.5 }
            let hips = Pose.side.with { $0.arms = Limb(-40, 73, 20) }
            let leanBack = hips.with { $0.lean = -7; $0.bend = -17; $0.neck = -4; $0.nod = 0.4; $0.legs = Limb(-5) }
            return Choreography(facing: .side, trails: [.handR], keys: [
                Key(.side, move: 1, hold: 0.5),
                Key(reach, move: 1.3, hold: 1.2),
                Key(.side, move: 1.1, hold: 0.2),
                Key(hips, move: 0.8, hold: 0.3),
                Key(leanBack, move: 1.6, hold: 1.3),
                Key(hips, move: 1.4, hold: 0.3),
                Key(leanBack, move: 1.6, hold: 1.3),
                Key(hips, move: 1.4, hold: 0.3),
            ])

        case .shoulderRolls:
            // Up, back, down, around: the arm trails a little behind the shoulder.
            let rest = Pose.seated.with { $0.armR = Limb(-2, 10); $0.armL = Limb(3, 12) }
            func roll(_ x: Double, _ y: Double, arm: Double) -> Key {
                Key(rest.with { $0.shrugX = x; $0.shrugY = y; $0.arms = Limb(arm, 12) }, move: 0.55, flow: true)
            }
            let circle = [roll(2, 11, arm: 4), roll(-9, 7, arm: -8), roll(-8, -3, arm: -10), roll(3, -1, arm: 0)]
            let squeeze = rest.with { $0.shrugX = -8; $0.bend = -5; $0.nod = 0.2; $0.arms = Limb(-26, 86, 10) }
            return Choreography(facing: .side, zoom: 1.5, focus: 80, offsetX: 30, prop: .chair, trails: [.shoulder],
                                keys: [Key(rest, move: 0.8, hold: 0.4)]
                                    + circle + circle + circle
                                    + [Key(squeeze, move: 0.9, hold: 1.6), Key(rest, move: 1, hold: 0.2)])

        case .neckTurns:
            return Choreography(facing: .front, zoom: 1.55, focus: 86, seated: true, prop: .chair, keys: [
                Key(.seatedFront, move: 1, hold: 0.5),
                Key(.seatedFront.with { $0.nod = -0.45 }, move: 0.8, hold: 1),
                Key(.seatedFront, move: 0.7, hold: 0.3),
                Key(.seatedFront.with { $0.turn = -1 }, move: 1.2, hold: 1.2),
                Key(.seatedFront, move: 1.1, hold: 0.3),
                Key(.seatedFront.with { $0.turn = 1 }, move: 1.2, hold: 1.2),
            ])

        case .calfRaises:
            // One hand rests on the desk, which also gives the eye something still to measure the rise against.
            let down = Pose.side.with { $0.armR = Limb(27, 43, 20) }
            let up = Pose.side.with { $0.armR = Limb(36, 6, 48); $0.armL = Limb(6, 12); $0.legs = Limb(0, 0, 44) }
            return Choreography(facing: .side, zoom: 1.15, focus: 100, offsetX: -20, prop: .desk, keys: [
                Key(down, move: 1.2, hold: 0.3),
                Key(up, move: 0.9, hold: 0.7),
            ])

        case .walk:
            let contact = Pose.side.with {
                $0.lean = 4
                $0.legR = Limb(24, -4, -12); $0.legL = Limb(-18, -18, 22)
                $0.armR = Limb(-24, 16); $0.armL = Limb(24, 26)
            }
            let passing = Pose.side.with {
                $0.lean = 4
                $0.legR = Limb(2, -2); $0.legL = Limb(12, -55, 12)
                $0.armR = Limb(0, 14); $0.armL = Limb(0, 14)
            }
            return Choreography(facing: .side, anchorHips: true, groundSpeed: 120, keys: [
                Key(contact, move: 0.3, flow: true),
                Key(passing, move: 0.3, flow: true),
                Key(contact.mirrored, move: 0.3, flow: true),
                Key(passing.mirrored, move: 0.3, flow: true),
            ])

        case .sideBend:
            let up = Pose.seatedFront.with { $0.arms = Limb(160, 14) }
            func bent(_ sign: Double) -> Pose {
                up.with { $0.lean = 7 * sign; $0.bend = 19 * sign; $0.neck = 5 * sign }
            }
            return Choreography(facing: .front, zoom: 1.25, focus: 98, seated: true, prop: .chair,
                                trails: [.handR, .handL], keys: [
                Key(.seatedFront, move: 1.2, hold: 0.4),
                Key(up, move: 1.2, hold: 0.5),
                Key(bent(1), move: 1.4, hold: 1.3),
                Key(up, move: 1.2, hold: 0.2),
                Key(bent(-1), move: 1.4, hold: 1.3),
                Key(up, move: 1.2, hold: 0.3),
            ])

        case .chestOpener:
            let open = Pose.side.with {
                $0.armR = Limb(-40, -4, -10); $0.armL = Limb(-36, -4, -10)
                $0.shrugX = -5; $0.bend = -11; $0.nod = 0.35
            }
            return Choreography(facing: .side, zoom: 1.45, focus: 128, keys: [
                Key(.side, move: 1.4, hold: 0.5),
                Key(open, move: 1.6, hold: 2.4),
            ])

        case .neckTilts:
            return Choreography(facing: .front, zoom: 1.55, focus: 86, seated: true, prop: .chair, keys: [
                Key(.seatedFront, move: 1, hold: 0.4),
                Key(.seatedFront.with { $0.neck = 27 }, move: 1.2, hold: 1.2),
                Key(.seatedFront, move: 1, hold: 0.2),
                Key(.seatedFront.with { $0.neck = -27 }, move: 1.2, hold: 1.2),
                Key(.seatedFront, move: 1, hold: 0.2),
                Key(.seatedFront.with { $0.nod = 1 }, move: 1, hold: 1),
                Key(.seatedFront.with { $0.nod = -1 }, move: 1.4, hold: 1),
            ])

        case .sitToStand:
            let (seated, hinge, stand) = Self.rise
            return Choreography(facing: .side, offsetX: 22, prop: .chair, keys: [
                Key(seated, move: 0.6, hold: 0.5),
                Key(hinge, move: 0.8, hold: 0.1),
                Key(stand, move: 1, hold: 0.5),
                Key(hinge, move: 1.2, hold: 0.1),
            ])

        case .standUp:
            // Plays once: up out of the chair, and stays up.
            let (seated, hinge, stand) = Self.rise
            return Choreography(facing: .side, offsetX: 22, prop: .chair, loops: false, keys: [
                Key(.seated, move: 0.4, hold: 0.7),
                Key(seated, move: 0.5),
                Key(hinge, move: 0.8, hold: 0.1),
                Key(stand, move: 1, hold: 0.2),
                Key(.side, move: 0.8, hold: 1),
            ])

        case .twist:
            let crossed = Pose.seatedFront.with { $0.arms = Limb(12, -147) }
            func turned(_ sign: Double) -> Pose {
                crossed.with { $0.shoulders = 0.4; $0.turn = sign; $0.shrugX = 5 * sign }
            }
            return Choreography(facing: .front, zoom: 1.45, focus: 90, seated: true, prop: .chair, keys: [
                Key(.seatedFront, move: 1, hold: 0.4),
                Key(crossed, move: 1, hold: 0.3),
                Key(turned(1), move: 1.3, hold: 1),
                Key(crossed, move: 1.1, hold: 0.1),
                Key(turned(-1), move: 1.3, hold: 1),
                Key(crossed, move: 1.1, hold: 0.1),
            ])

        case .wristStretch:
            // One arm reaches out while the other hand eases its fingers back: up, then down, then swap arms.
            let fingersUp = Pose.seated.with { $0.armR = Limb(72, 6, 80); $0.armL = Limb(58, 41, 60) }
            let fingersDown = Pose.seated.with { $0.armR = Limb(72, 6, -80); $0.armL = Limb(62, 22, -50) }
            return Choreography(facing: .side, zoom: 1.5, focus: 80, offsetX: 26, prop: .chair, keys: [
                Key(.seated, move: 1, hold: 0.3),
                Key(fingersUp, move: 1.1, hold: 1.5),
                Key(fingersDown, move: 1.1, hold: 1.5),
                Key(.seated, move: 1, hold: 0.3),
                Key(fingersUp.mirrored, move: 1.1, hold: 1.5),
                Key(fingersDown.mirrored, move: 1.1, hold: 1.5),
            ])

        case .hipOpener:
            let lunge = Pose.side.with {
                $0.lean = -3; $0.arms = Limb(-40, 73, 20)
                $0.legR = Limb(30, -32); $0.legL = Limb(-26, -6, 28)
            }
            let deeper = lunge.with { $0.bend = -5; $0.legR = Limb(36, -44); $0.legL = Limb(-33, -2, 30) }
            return Choreography(facing: .side, keys: [
                Key(.side, move: 1.1, hold: 0.3),
                Key(lunge, move: 1.2, hold: 0.4),
                Key(deeper, move: 1.3, hold: 1.6),
                Key(lunge, move: 1, hold: 0.2),
                Key(.side, move: 1.1, hold: 0.3),
                Key(lunge.mirrored, move: 1.2, hold: 0.4),
                Key(deeper.mirrored, move: 1.3, hold: 1.6),
                Key(lunge.mirrored, move: 1, hold: 0.2),
            ])

        case .hipHinge:
            let stand = Pose.side.with { $0.arms = Limb(6, 8) }
            let hinge = Pose.side.with { $0.lean = 50; $0.neck = -12; $0.legs = Limb(18, -30); $0.arms = Limb(17) }
            return Choreography(facing: .side, offsetX: -20, keys: [
                Key(stand, move: 1.4, hold: 0.4),
                Key(hinge, move: 1.5, hold: 0.7),
            ])
        }
    }

    /// Getting out of a chair: sitting, nose over toes, standing.
    private static var rise: (seated: Pose, hinge: Pose, stand: Pose) {
        let seated = Pose.seated.with { $0.lean = 12; $0.arms = Limb(30, 45) }
        let hinge = seated.with { $0.lean = 40; $0.legs = Limb(88, -98); $0.arms = Limb(72, 8) }
        let stand = Pose.side.with { $0.lean = 2; $0.arms = Limb(40, 10) }
        return (seated, hinge, stand)
    }
}
