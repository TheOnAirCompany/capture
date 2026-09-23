import SwiftUI

/// Export options for the selected screenshot: format, resolution, frame and background.
struct ExportInspector: View {
    let image: CGImage?
    let item: CaptureItem?

    @Environment(ExportSettings.self) private var settings
    @State private var copied = false
    @State private var errorMessage: String?

    var body: some View {
        @Bindable var settings = settings

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                section("Format") {
                    Picker("Format", selection: $settings.format) {
                        ForEach(ExportFormat.allCases) { Text($0.title).tag($0) }
                    }
                    .labelsHidden()
                }

                section("Resolution") {
                    HStack(spacing: 4) {
                        ForEach([0.5, 1, 2], id: \.self) { scale in
                            ResolutionOption(
                                scale: scale,
                                size: outputSize(scale: scale),
                                isSelected: settings.scale == scale
                            ) { settings.scale = scale }
                        }
                    }
                    .padding(3)
                    .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 10))
                }

                BezelSection(image: image)

                BackgroundSection()

                section("Margin") {
                    HStack {
                        Slider(value: $settings.margin, in: 0...0.3)
                            .disabled(!settings.hasBackground)
                        Text(settings.margin, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                            .frame(width: 44, alignment: .trailing)
                    }
                    Toggle("Shadow", isOn: $settings.showsShadow)
                        .disabled(!settings.hasBackground)
                }
            }
            .padding(20)
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 12) {
                Button(action: copy) {
                    Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button(action: export) {
                    Label("Export…", systemImage: "square.and.arrow.up")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut("e", modifiers: .command)
            }
            .controlSize(.large)
            .disabled(image == nil)
            .padding(20)
            .background(.bar)
        }
        .alert("Couldn't Export the Screenshot", isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } })) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(verbatim: errorMessage ?? "")
        }
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func outputSize(scale: Double) -> CGSize? {
        guard let image else { return nil }
        let layout = CompositionLayout(screen: CGSize(width: image.width, height: image.height), style: settings.style())
        return CGSize(width: (layout.canvas.width * scale).rounded(), height: (layout.canvas.height * scale).rounded())
    }

    private func copy() {
        guard let image, let rendered = ScreenshotExporter.render(image, style: settings.style(for: .png), scale: settings.scale),
              ScreenshotExporter.copy(rendered) else { return }
        copied = true
        Task {
            try? await Task.sleep(for: .seconds(1.5))
            copied = false
        }
    }

    private func export() {
        guard let image, let item else { return }
        let format = settings.format
        guard let rendered = ScreenshotExporter.render(image, style: settings.style(for: format), scale: settings.scale) else {
            errorMessage = CaptureError.writeFailed.localizedDescription
            return
        }
        do {
            let name = "\(item.name) (\(String(localized: "edited")))"
            if let url = try ScreenshotExporter.save(rendered, as: format, suggestedName: name) {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private struct ResolutionOption: View {
    let scale: Double
    let size: CGSize?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Text(verbatim: scale == 0.5 ? "½x" : "\(Int(scale))x")
                    .font(.headline)
                if let size {
                    Text(verbatim: "\(Int(size.width)) × \(Int(size.height))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isSelected ? AnyShapeStyle(.background) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 8))
            .shadow(color: .black.opacity(isSelected ? 0.08 : 0), radius: 2, y: 1)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct BezelSection: View {
    let image: CGImage?
    @Environment(ExportSettings.self) private var settings

    private var isSupported: Bool {
        guard let image else { return true }
        return DisplayCorners.hasRoundedDisplay(CGSize(width: image.width, height: image.height))
    }

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $settings.showsBezel) {
                Text("Device Frame").font(.headline)
            }
            .toggleStyle(.switch)
            .disabled(!isSupported)

            if !isSupported {
                Text("Frames aren't available for iPhones with a Home button.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                HStack(spacing: 8) {
                    ForEach(BezelFinish.allCases) { finish in
                        FinishOption(finish: finish, isSelected: settings.finish == finish) {
                            settings.finish = finish
                        }
                    }
                }
                .disabled(!settings.showsBezel)
                .opacity(settings.showsBezel ? 1 : 0.4)
            }
        }
    }
}

private struct FinishOption: View {
    let finish: BezelFinish
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: finish.colors, startPoint: .leading, endPoint: .trailing))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.black)
                        .padding(2)
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.6), .pink.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .padding(3.5)
                }
                .frame(width: 30, height: 60)
                .padding(8)
                .frame(maxWidth: .infinity)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                )
                Text(finish.title)
                    .font(.caption)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct BackgroundSection: View {
    @Environment(ExportSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Text("Background").font(.headline)

            Picker("Background", selection: $settings.backgroundKind) {
                ForEach(BackgroundKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 8), count: 5), spacing: 8) {
                Swatch(isSelected: !settings.hasBackground, label: "None") {
                    CheckerSwatch()
                } action: {
                    settings.hasBackground = false
                }

                switch settings.backgroundKind {
                case .color:
                    ForEach(ColorPresets.all.indices, id: \.self) { index in
                        let color = ColorPresets.all[index]
                        Swatch(isSelected: settings.hasBackground && settings.color == color) {
                            color
                        } action: {
                            settings.color = color
                            settings.hasBackground = true
                        }
                    }
                    ColorPicker("Custom Color", selection: Binding(
                        get: { settings.color },
                        set: { settings.color = $0; settings.hasBackground = true }
                    ))
                    .labelsHidden()
                case .gradient:
                    ForEach(GradientPresets.all.indices, id: \.self) { index in
                        Swatch(isSelected: settings.hasBackground && settings.gradientIndex == index) {
                            LinearGradient(colors: GradientPresets.all[index], startPoint: .topLeading, endPoint: .bottomTrailing)
                        } action: {
                            settings.gradientIndex = index
                            settings.hasBackground = true
                        }
                    }
                case .image:
                    if let url = settings.backgroundImage, let image = NSImage(contentsOf: url) {
                        Swatch(isSelected: settings.hasBackground) {
                            Image(nsImage: image).resizable().scaledToFill()
                        } action: {
                            settings.hasBackground = true
                        }
                    }
                    Swatch(isSelected: false) {
                        Image(systemName: "plus")
                            .font(.title3)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(.quaternary)
                    } action: {
                        chooseImage()
                    }
                }
            }
        }
    }

    private func chooseImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.image]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        settings.backgroundImage = url
        settings.hasBackground = true
    }
}

private struct Swatch<Content: View>: View {
    let isSelected: Bool
    var label: LocalizedStringKey?
    @ViewBuilder let content: Content
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                content
                    .frame(height: 44)
                    .frame(maxWidth: .infinity)
                    .clipShape(.rect(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                    .padding(2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                    )
                if let label {
                    Text(label).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct CheckerSwatch: View {
    var body: some View {
        Canvas { context, size in
            let square: CGFloat = 6
            context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
            for row in 0...Int(size.height / square) {
                for column in 0...Int(size.width / square) where (row + column).isMultiple(of: 2) {
                    context.fill(Path(CGRect(x: CGFloat(column) * square, y: CGFloat(row) * square, width: square, height: square)),
                                 with: .color(Color(white: 0.88)))
                }
            }
        }
    }
}
