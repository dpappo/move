import SwiftUI

extension Color {
    static let sage = Color(red: 0.36, green: 0.69, blue: 0.59)
}

extension EnvironmentValues {
    /// True when rendering README screenshots offscreen, where materials and appear animations don't run.
    @Entry var isSnapshot = false
}

struct ReminderView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        ZStack {
            switch session.phase {
            case .prompt:
                PromptView(session: session)
                    .transition(.opacity.combined(with: .offset(x: -12)))
            case .guiding:
                GuideView(session: session)
                    .transition(.opacity.combined(with: .offset(x: 12)))
            case .finished:
                FinishedView(session: session)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .animation(.smooth(duration: 0.4), value: session.phase)
        .padding(.horizontal, 22)
        .padding(.top, 22)
        .padding(.bottom, 18)
        .frame(width: ReminderPanelController.cardSize.width,
               height: ReminderPanelController.cardSize.height)
        .modifier(CardBackground())
    }
}

// MARK: - Prompt

private struct PromptView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 13) {
                BreathingBadge()
                VStack(alignment: .leading, spacing: 2) {
                    Text("Time to move")
                        .font(.system(size: 17, weight: .semibold, design: .rounded))
                    Text("Step away for a couple of minutes.")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                if session.breaksToday > 0 {
                    TodayBadge(count: session.breaksToday)
                }
            }

            Spacer(minLength: 18)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(session.routine) { MovementRow(movement: $0) }
            }

            Spacer(minLength: 18)

            HStack(spacing: 6) {
                Button("Later") { session.snooze() }
                    .buttonStyle(QuietButtonStyle())
                    .help("Remind me again in 10 minutes")
                Spacer()
                Button("Done") { session.markDone() }
                    .buttonStyle(SoftButtonStyle())
                    .help("I moved — see you in \(session.intervalMinutes) minutes")
                Button { session.startGuide() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: "play.fill").font(.system(size: 9))
                        Text("Guide me")
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                .help("A gentle \(session.totalMinutesLabel) routine")
            }
        }
    }
}

private struct MovementRow: View {
    let movement: Movement

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: movement.symbol)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Color.sage)
                .frame(width: 32, height: 32)
                .background(Color.sage.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 1) {
                Text(movement.title)
                    .font(.system(size: 13, weight: .medium))
                Text(movement.hint)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct BreathingBadge: View {
    @State private var inhale = false

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.sage.opacity(0.2))
                .scaleEffect(inhale ? 1 : 0.7)
            Circle()
                .fill(Color.sage)
                .frame(width: 30, height: 30)
            Image(systemName: "figure.walk")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 42, height: 42)
        .onAppear {
            withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
                inhale = true
            }
        }
    }
}

private struct TodayBadge: View {
    let count: Int

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "checkmark").font(.system(size: 8, weight: .bold))
            Text("\(count) today").font(.system(size: 10.5, weight: .medium)).monospacedDigit()
        }
        .foregroundStyle(Color.sage)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.sage.opacity(0.13), in: Capsule())
        .help("Breaks taken today")
    }
}

// MARK: - Guided routine

private struct GuideView: View {
    @ObservedObject var session: BreakSession

    var body: some View {
        let step = session.step
        VStack(spacing: 0) {
            HStack {
                Text("\(session.stepIndex + 1) of \(session.routine.count)")
                    .font(.system(size: 11, weight: .medium))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Spacer()
                StepDots(count: session.routine.count, current: session.stepIndex)
            }

            Spacer(minLength: 10)

            ZStack {
                Circle()
                    .stroke(Color.sage.opacity(0.15), lineWidth: 6)
                Circle()
                    .trim(from: 0, to: session.progress)
                    .stroke(Color.sage, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 5) {
                    Image(systemName: step.symbol)
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(Color.sage)
                        .contentTransition(.symbolEffect(.replace))
                        .animation(.smooth, value: step.id)
                    Text(timeLabel(session.remainingSeconds))
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText(countsDown: true))
                }
            }
            .frame(width: 120, height: 120)

            Spacer(minLength: 16)

            VStack(spacing: 6) {
                Text(step.title)
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                Text(step.cue)
                    .font(.system(size: 12.5))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(1.5)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(height: 36, alignment: .top)
            }
            .id(step.id)
            .transition(.opacity)
            .animation(.smooth(duration: 0.35), value: step.id)

            Spacer(minLength: 14)

            HStack {
                Button("Skip") { session.skip() }
                    .buttonStyle(QuietButtonStyle())
                Spacer()
                Button("Done") { session.markDone() }
                    .buttonStyle(SoftButtonStyle())
            }
        }
    }

    private func timeLabel(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct StepDots: View {
    let count: Int
    let current: Int

    var body: some View {
        HStack(spacing: 5) {
            ForEach(0..<count, id: \.self) { i in
                Capsule()
                    .fill(i <= current ? Color.sage : Color.primary.opacity(0.15))
                    .frame(width: i == current ? 16 : 6, height: 6)
            }
        }
        .animation(.smooth, value: current)
    }
}

// MARK: - Finished

private struct FinishedView: View {
    @ObservedObject var session: BreakSession
    @Environment(\.isSnapshot) private var isSnapshot
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: "checkmark")
                .font(.system(size: 26, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 64, height: 64)
                .background(Color.sage, in: Circle())
                .scaleEffect(appeared || isSnapshot ? 1 : 0.6)
                .opacity(appeared || isSnapshot ? 1 : 0)
            Text("Nicely done")
                .font(.system(size: 17, weight: .semibold, design: .rounded))
                .padding(.top, 6)
            Text("That's \(session.breaksToday) today. See you in \(session.intervalMinutes) minutes.")
                .font(.system(size: 12.5))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.6)) { appeared = true }
        }
    }
}

// MARK: - Styling

private struct CardBackground: ViewModifier {
    @Environment(\.isSnapshot) private var isSnapshot
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 24, style: .continuous)
        if isSnapshot {
            content
                .background(colorScheme == .dark ? Color(white: 0.17, opacity: 0.94) : Color(white: 0.98, opacity: 0.9), in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(colorScheme == .dark ? 0.16 : 0.06), lineWidth: 0.5))
        } else if #available(macOS 26.0, *) {
            content
                .background(.regularMaterial, in: shape)
                .glassEffect(.regular, in: shape)
        } else {
            content
                .background(.regularMaterial, in: shape)
                .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        }
    }
}

private struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .semibold))
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.sage.opacity(configuration.isPressed ? 0.8 : 1), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule())
    }
}

private struct SoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.system(size: 12.5, weight: .medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 7)
            .background(Color.primary.opacity(configuration.isPressed ? 0.14 : 0.08), in: Capsule())
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .contentShape(Capsule())
    }
}

private struct QuietButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        QuietLabel(configuration: configuration)
    }

    private struct QuietLabel: View {
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        var body: some View {
            configuration.label
                .font(.system(size: 12.5, weight: .medium))
                .foregroundStyle(hovering ? .primary : .secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .contentShape(Rectangle())
                .opacity(configuration.isPressed ? 0.6 : 1)
                .onHover { hovering = $0 }
        }
    }
}
