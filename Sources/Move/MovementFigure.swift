import SwiftUI

/// A pictogram-style figure acting out a movement, looping for as long as the step lasts.
struct MovementFigure: View {
    private let choreography: Choreography
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var start = Date()

    init(motion: Motion) {
        choreography = motion.choreography
    }

    var body: some View {
        TimelineView(.animation(paused: isSnapshot)) { timeline in
            let time = isSnapshot ? 3.2 : timeline.date.timeIntervalSince(start)
            Canvas { context, size in
                FigureRenderer(choreography: choreography, time: time, size: size).draw(in: &context)
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton

/// Joint positions for one pose, in figure units (about 195 tall standing), y up, standing on y = 0.
private struct Skeleton {
    static let waist = 24.0, chest = 32.0, upperArm = 32.0, forearm = 30.0, hand = 8.0
    static let thigh = 44.0, shin = 44.0, foot = 14.0, frontFoot = 7.0
    static let headRadius = 13.5, neckGap = 3.0, limbWidth = 9.5
    static let shoulderHalf = 9.0, hipHalf = 6.0

    var spine: [CGPoint]    // hips, waist, base of the neck
    var shoulder: CGPoint   // midpoint of the shoulders
    var torsoWidth: Double
    var head: CGPoint
    var headUp: CGPoint
    var headSide: CGPoint
    var arms: [[CGPoint]]   // [R, L]: shoulder, elbow, wrist, fingertips
    var legs: [[CGPoint]]   // [R, L]: hip, knee, ankle, toes

    init(_ pose: Pose, choreography: Choreography) {
        let front = choreography.facing == .front
        let chest = pose.lean + pose.bend
        let up = direction(180 - chest)
        let side = direction(90 - chest)

        let waist = direction(180 - pose.lean) * Self.waist
        let neck = waist + up * Self.chest
        spine = [.zero, waist, neck]
        torsoWidth = front ? 14 + 10 * pose.shoulders : 17

        // In profile, looking up or down tips the whole head; facing us, it only moves the face.
        let tilt = chest + pose.neck - (front ? 0 : pose.nod * 16)
        headUp = direction(180 - tilt)
        headSide = direction(90 - tilt)
        head = neck + headUp * (torsoWidth / 2 + Self.neckGap + Self.headRadius)

        // Left limbs mirror the right ones when the figure faces us; in profile both swing the same way.
        let shoulderCenter = neck + side * pose.shrugX + up * pose.shrugY
        shoulder = shoulderCenter
        let spread = front ? Self.shoulderHalf * pose.shoulders : 0
        arms = [(pose.armR, 1.0), (pose.armL, -1.0)].map { limb, sign in
            let m = front ? sign : 1
            let shoulder = shoulderCenter + side * (spread * sign)
            let elbow = shoulder + direction(m * limb.a - chest) * Self.upperArm
            let wrist = elbow + direction(m * (limb.a + limb.b) - chest) * Self.forearm
            let tip = wrist + direction(m * (limb.a + limb.b + limb.c) - chest) * Self.hand
            return [shoulder, elbow, wrist, tip]
        }
        legs = [(pose.legR, 1.0), (pose.legL, -1.0)].map { limb, sign in
            let m = front ? sign : 1
            let top = CGPoint(x: front ? Self.hipHalf * sign : 0, y: 0)
            // Sitting and facing us, the thighs point at the viewer, so only a little of their length shows.
            let knee = top + direction(m * limb.a) * (front && choreography.seated ? 15 : Self.thigh)
            let ankle = knee + direction(m * (limb.a + limb.b)) * Self.shin
            let toes = ankle + direction(m * (90 - limb.c)) * (front ? Self.frontFoot : Self.foot)
            return [top, knee, ankle, toes]
        }

        // Plant the lowest foot on the floor, and keep the toes (or hips) from sliding sideways.
        let floor = legs.flatMap { $0[2...] }.map(\.y).min()! - Self.limbWidth / 2
        let anchorX = choreography.hipsX.map { -$0 } ?? (legs[0][3].x + legs[1][3].x) / 2 - (front ? 0 : Self.foot)
        let offset = CGPoint(x: -anchorX, y: -floor)
        spine = spine.map { $0 + offset }
        head = head + offset
        shoulder = shoulder + offset
        arms = arms.map { $0.map { $0 + offset } }
        legs = legs.map { $0.map { $0 + offset } }
    }

    func position(of joint: Choreography.Joint) -> CGPoint {
        switch joint {
        case .handR: arms[0][3]
        case .handL: arms[1][3]
        // Shoulders only travel a little, so their trail is drawn larger than life around where they rest.
        case .shoulder: lerp(spine[2], shoulder, 3)
        }
    }
}

/// A unit vector for an angle in degrees: 0 points down, 90 toward +x, 180 up.
private func direction(_ degrees: Double) -> CGPoint {
    let r = degrees * .pi / 180
    return CGPoint(x: sin(r), y: -cos(r))
}

private func + (a: CGPoint, b: CGPoint) -> CGPoint { CGPoint(x: a.x + b.x, y: a.y + b.y) }
private func * (a: CGPoint, k: Double) -> CGPoint { CGPoint(x: a.x * k, y: a.y * k) }
private func lerp(_ a: CGPoint, _ b: CGPoint, _ t: Double) -> CGPoint { a + (b + a * -1) * t }

// MARK: - Drawing

private struct FigureRenderer {
    let choreography: Choreography
    let time: Double
    let size: CGSize

    private var scale: Double { size.height / 285 * choreography.zoom }

    private let body = GraphicsContext.Shading.color(.sage)
    private let far = GraphicsContext.Shading.color(.sage.opacity(0.38))

    func draw(in context: inout GraphicsContext) {
        let pose = pose(at: time)
        let skeleton = Skeleton(pose, choreography: choreography)

        drawFloor(in: &context, skeleton)
        drawProp(in: &context)
        for joint in choreography.trails { drawTrail(of: joint, in: &context) }

        context.drawLayer { layer in
            let s = skeleton
            switch choreography.facing {
            case .front:
                stroke(s.legs[0], in: &layer)
                stroke(s.legs[1], in: &layer)
                drawTorso(s, in: &layer)
                drawHead(s, pose: pose, in: &layer)
                stroke(s.arms[1], in: &layer, cutout: true)
                stroke(s.arms[0], in: &layer, cutout: true)
            case .side:
                stroke(s.arms[1], in: &layer, shading: far)
                stroke(s.legs[1], in: &layer, shading: far)
                drawTorso(s, in: &layer)
                drawHead(s, pose: pose, in: &layer)
                stroke(s.legs[0], in: &layer, cutout: true)
                stroke(s.arms[0], in: &layer, cutout: true)
            }
        }
    }

    private func pose(at time: Double) -> Pose {
        var pose = choreography.pose(at: max(0, time))
        if choreography.groundSpeed == 0 {
            pose.shrugY += 0.8 * sin(time * 2 * .pi / 3.5)  // breathing, so held stretches still feel alive
        }
        return pose
    }

    private func point(_ p: CGPoint) -> CGPoint {
        CGPoint(x: size.width / 2 + (p.x + choreography.offsetX) * scale,
                y: size.height / 2 + (choreography.focus - p.y) * scale)
    }

    private func path(_ points: [CGPoint]) -> Path {
        Path { path in
            path.addLines(points.map(point))
        }
    }

    private func style(_ width: Double) -> StrokeStyle {
        StrokeStyle(lineWidth: width * scale, lineCap: .round, lineJoin: .round)
    }

    /// Draws a limb. With `cutout`, it first clears a thin gap around itself so it reads in front of the body.
    private func stroke(_ limb: [CGPoint], in layer: inout GraphicsContext,
                        shading: GraphicsContext.Shading? = nil, cutout: Bool = false) {
        if cutout {
            // Start the gap partway down the upper segment, so it doesn't ring the joint where the limb meets the body.
            let gap = [lerp(limb[0], limb[1], 0.4)] + limb[1...]
            layer.blendMode = .destinationOut
            layer.stroke(path(gap), with: .color(.black), style: style(Skeleton.limbWidth + 5))
            layer.blendMode = .normal
        }
        layer.stroke(path(limb), with: shading ?? body, style: style(Skeleton.limbWidth))
    }

    private func drawTorso(_ s: Skeleton, in layer: inout GraphicsContext) {
        var spine = Path()
        spine.move(to: point(s.spine[0]))
        spine.addQuadCurve(to: point(s.spine[2]), control: point(s.spine[1]))
        layer.stroke(spine, with: body, style: style(s.torsoWidth))
    }

    /// The nose and eyes show which way the head is turned and whether it's looking up or down.
    private func drawHead(_ s: Skeleton, pose: Pose, in layer: inout GraphicsContext) {
        let r = Skeleton.headRadius
        func spot(_ x: Double, _ y: Double) -> CGPoint { s.head + s.headSide * x + s.headUp * y }

        var eyes: [(x: Double, size: Double)] = []
        let nose: CGPoint, eyeHeight: Double
        switch choreography.facing {
        case .front:
            // The face slides around the head as it turns; the nose only shows once it clears the edge.
            let yaw = pose.turn * 66 * .pi / 180
            let look = r * 0.42 * pose.nod
            nose = spot((r + 1) * sin(yaw), look - r * 0.15)
            eyeHeight = r * 0.12 + look
            for offset in [-0.4, 0.4] where abs(yaw + offset) < 1.4 {
                eyes.append((r * 0.93 * sin(yaw + offset), max(0.5, cos(yaw + offset))))
            }
        case .side:
            nose = spot(r + 0.6, -r * 0.12)
            eyeHeight = r * 0.14
            eyes = [(r * 0.5, 1)]
        }

        layer.fill(circle(at: s.head, radius: r), with: body)
        layer.fill(circle(at: nose, radius: 3.4), with: body)
        layer.blendMode = .destinationOut
        for eye in eyes {
            layer.fill(circle(at: spot(eye.x, eyeHeight), radius: 1.9 * eye.size), with: .color(.black))
        }
        layer.blendMode = .normal
    }

    private func circle(at center: CGPoint, radius: Double) -> Path {
        let c = point(center), r = radius * scale
        return Path(ellipseIn: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2))
    }

    /// A ribbon that tapers away behind a moving joint, tracing where it has just been.
    private func drawTrail(of joint: Choreography.Joint, in context: inout GraphicsContext) {
        let count = 18
        let points = (0..<count).map { i in
            point(Skeleton(pose(at: time - Double(i) * 0.03), choreography: choreography).position(of: joint))
        }
        var left: [CGPoint] = [], right: [CGPoint] = []
        var normal = CGPoint.zero
        for i in 0..<count {
            let a = points[max(i - 1, 0)], b = points[min(i + 1, count - 1)]
            let length = hypot(b.x - a.x, b.y - a.y)
            if length > 0.01 { normal = CGPoint(x: (a.y - b.y) / length, y: (b.x - a.x) / length) }
            let half = Skeleton.limbWidth * 0.42 * scale * (1 - Double(i) / Double(count - 1))
            left.append(points[i] + normal * half)
            right.append(points[i] + normal * -half)
        }
        guard normal != .zero else { return }
        let ribbon = Path { path in
            path.addLines(left + right.reversed())
            path.closeSubpath()
        }
        context.fill(ribbon, with: .color(.sage.opacity(0.22)))
    }

    private func drawFloor(in context: inout GraphicsContext, _ s: Skeleton) {
        let xs = s.legs.flatMap { $0[2...].map(\.x) }
        let left = point(CGPoint(x: xs.min()! - 18, y: 0)), right = point(CGPoint(x: xs.max()! + 18, y: 0))
        let height = 7 * scale
        context.fill(Path(ellipseIn: CGRect(x: left.x, y: left.y - height / 2, width: right.x - left.x, height: height)),
                     with: .color(.sage.opacity(0.16)))

        // On a walk the floor drifts by underfoot, fading out toward the edges.
        guard choreography.groundSpeed > 0 else { return }
        let period = 34.0, reach = 150.0
        let offset = (time * choreography.groundSpeed).truncatingRemainder(dividingBy: period)
        var x = -reach - offset
        while x < reach {
            let fade = max(0, 1 - abs(x) / reach)
            context.stroke(path([CGPoint(x: x - 7, y: -3), CGPoint(x: x + 7, y: -3)]),
                           with: .color(.sage.opacity(0.35 * fade)), style: style(3))
            x += period
        }
    }

    private func drawProp(in context: inout GraphicsContext) {
        let wood = GraphicsContext.Shading.color(.primary.opacity(0.14))
        switch choreography.prop {
        case .chair where choreography.facing == .front:
            let back = Path(roundedRect: CGRect(origin: point(CGPoint(x: -27, y: 108)),
                                                size: CGSize(width: 54 * scale, height: 58 * scale)),
                            cornerRadius: 9 * scale)
            context.stroke(back, with: wood, style: style(5))
            context.stroke(path([CGPoint(x: -35, y: 47), CGPoint(x: 35, y: 47)]), with: wood, style: style(6))
            context.stroke(path([CGPoint(x: -32, y: 47), CGPoint(x: -32, y: 0)]), with: wood, style: style(4))
            context.stroke(path([CGPoint(x: 32, y: 47), CGPoint(x: 32, y: 0)]), with: wood, style: style(4))
        case .chair:
            context.stroke(path([CGPoint(x: -70, y: 100), CGPoint(x: -70, y: 41), CGPoint(x: -26, y: 41)]),
                           with: wood, style: style(5))
            context.stroke(path([CGPoint(x: -67, y: 41), CGPoint(x: -67, y: 0)]), with: wood, style: style(4))
            context.stroke(path([CGPoint(x: -30, y: 41), CGPoint(x: -30, y: 0)]), with: wood, style: style(4))
        case .desk:
            context.stroke(path([CGPoint(x: 38, y: 103), CGPoint(x: 130, y: 103)]), with: wood, style: style(5))
            context.stroke(path([CGPoint(x: 112, y: 103), CGPoint(x: 112, y: 0)]), with: wood, style: style(4))
        case nil:
            break
        }
    }
}
