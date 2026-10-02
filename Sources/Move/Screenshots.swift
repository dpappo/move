import AppKit
import SwiftUI

/// Renders the README screenshots from the real card views: `Move --screenshots <dir>`.
/// Output is deterministic, so unchanged UI produces byte-identical PNGs.
@MainActor
enum Screenshots {
    static func render(to dir: URL) {
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            // The two routines alternate break to break, so the hero and the flow show one each.
            write(Desktop(scheme: scheme) { card(.prompt, breaksToday: 3) }, scheme, to: dir.appendingPathComponent("hero-\(name).png"))
            write(Backdrop(scheme: scheme) {
                HStack(spacing: 28) {
                    card(.prompt, breaksToday: 2)
                    card(.guiding, breaksToday: 2, elapsed: 12)
                    card(.finished, breaksToday: 3)
                }
            }, scheme, to: dir.appendingPathComponent("flow-\(name).png"))
        }
        print("Wrote screenshots to \(dir.path)")
    }

    private static func card(_ phase: BreakSession.Phase, breaksToday: Int, elapsed: Double = 0) -> some View {
        let session = BreakSession()
        session.stage(phase, elapsed: elapsed, breaksToday: breaksToday)
        return ReminderView(session: session)
            .shadow(color: .black.opacity(0.18), radius: 24, y: 10)
    }

    private static func write(_ view: some View, _ scheme: ColorScheme, to url: URL) {
        let renderer = ImageRenderer(content: view
            .environment(\.colorScheme, scheme)
            .environment(\.isSnapshot, true))
        renderer.scale = 2
        guard let image = renderer.cgImage,
              let png = NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]) else {
            FileHandle.standardError.write("Could not render \(url.lastPathComponent)\n".data(using: .utf8)!)
            exit(1)
        }
        try! png.write(to: url)
    }
}

// MARK: - Scenery

private struct Wallpaper: View {
    let scheme: ColorScheme

    var body: some View {
        let dark = scheme == .dark
        ZStack {
            LinearGradient(colors: dark
                           ? [Color(red: 0.07, green: 0.13, blue: 0.12), Color(red: 0.12, green: 0.10, blue: 0.19)]
                           : [Color(red: 0.86, green: 0.94, blue: 0.91), Color(red: 0.93, green: 0.91, blue: 0.97)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            Circle()
                .fill(Color.sage.opacity(dark ? 0.22 : 0.28))
                .frame(width: 520)
                .blur(radius: 90)
                .offset(x: 260, y: -160)
            Circle()
                .fill(Color(red: 0.55, green: 0.5, blue: 0.85).opacity(dark ? 0.18 : 0.16))
                .frame(width: 460)
                .blur(radius: 100)
                .offset(x: -300, y: 180)
        }
    }
}

/// Cards on a soft wallpaper.
private struct Backdrop<Content: View>: View {
    let scheme: ColorScheme
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(56)
            .background(Wallpaper(scheme: scheme))
    }
}

/// The card where it really lives: top-right corner of the desktop, beside the work it doesn't interrupt.
private struct Desktop<Content: View>: View {
    let scheme: ColorScheme
    @ViewBuilder let content: Content

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Wallpaper(scheme: scheme)
            VStack(spacing: 0) {
                MenuBar()
                HStack(alignment: .top, spacing: 0) {
                    EditorWindow()
                        .padding(.leading, 48)
                        .padding(.top, 44)
                    Spacer(minLength: 0)
                    content.padding(14)
                }
                Spacer(minLength: 0)
            }
        }
        .frame(width: 960, height: 560)
        .clipped()
    }
}

private struct MenuBar: View {
    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            Image(systemName: "figure.walk")
                .font(.system(size: 13, weight: .semibold))
                .frame(width: 26, height: 20)
                .background(Color.primary.opacity(0.1), in: RoundedRectangle(cornerRadius: 5))
            Image(systemName: "wifi")
            Image(systemName: "battery.75percent")
            Text("Tue 10:30")
        }
        .font(.system(size: 13, weight: .medium))
        .padding(.horizontal, 14)
        .frame(height: 28)
        .background(.primary.opacity(0.05))
    }
}

/// A stand-in for whatever you're focused on.
private struct EditorWindow: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                ForEach([Color(red: 1, green: 0.37, blue: 0.34),
                         Color(red: 1, green: 0.74, blue: 0.18),
                         Color(red: 0.16, green: 0.79, blue: 0.25)], id: \.self) {
                    Circle().fill($0).frame(width: 12, height: 12)
                }
            }
            .padding(14)
            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array([0.55, 0.9, 0.82, 0.7, 0.0, 0.88, 0.6, 0.76, 0.4].enumerated()), id: \.offset) { _, width in
                    Capsule()
                        .fill(Color.primary.opacity(0.1))
                        .frame(width: 400 * width, height: 9)
                }
            }
            .padding(.horizontal, 28)
            .padding(.top, 14)
            Spacer()
        }
        .frame(width: 470, height: 400, alignment: .topLeading)
        .background(Color.primary.opacity(0.04), in: shape)
        .background(.background.opacity(0.75), in: shape)
        .overlay(shape.strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.12), radius: 30, y: 14)
    }
}
