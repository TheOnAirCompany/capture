import SwiftUI

/// Export options for the selected screenshot: format, resolution, frame and background.
struct ExportInspector: View {
    let image: CGImage?
    let item: CaptureItem?
    let suggestions: SuggestedBackgrounds

    @Environment(ExportSettings.self) private var settings
    @State private var copied = false
    @State private var exported = false
    @Environment(CaptureLibrary.self) private var library
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

                LayoutSection()

                BezelSection(size: image.map { CGSize(width: $0.width, height: $0.height) })

                BackgroundSection(suggestions: suggestions)

                MarginSection()
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
                    Label(exportTitle, systemImage: exported ? "checkmark" : "square.and.arrow.up")
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

    private func size(of image: CGImage) -> CGSize {
        CGSize(width: image.width, height: image.height)
    }

    private var exportTitle: LocalizedStringKey {
        if exported { return "Exported" }
        return Preferences.exportsToCaptureFolder ? "Export" : "Export…"
    }

    private func section<Content: View>(_ title: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
            content()
        }
    }

    private func outputSize(scale: Double) -> CGSize? {
        guard let image else { return nil }
        let size = CGSize(width: image.width, height: image.height)
        let layout = CompositionLayout(image: size, style: settings.style(for: size))
        return CGSize(width: (layout.canvas.width * scale).rounded(), height: (layout.canvas.height * scale).rounded())
    }

    private func copy() {
        guard let image,
              let rendered = ScreenshotExporter.render(image, style: settings.style(for: size(of: image), format: .png), scale: settings.scale),
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
        guard let rendered = ScreenshotExporter.render(image, style: settings.style(for: size(of: image), format: format), scale: settings.scale) else {
            errorMessage = CaptureError.writeFailed.localizedDescription
            return
        }
        do {
            if Preferences.exportsToCaptureFolder {
                _ = try ScreenshotExporter.saveToExportsFolder(rendered, as: format, name: item.name)
                library.reload()
                exported = true
                Task {
                    try? await Task.sleep(for: .seconds(1.5))
                    exported = false
                }
            } else {
                let name = "\(item.name) (\(String(localized: "edited")))"
                if let url = try ScreenshotExporter.save(rendered, as: format, suggestedName: name) {
                    NSWorkspace.shared.activateFileViewerSelecting([url])
                }
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

/// Orientation of the device and shape of the output, shared by the screenshot and video editors.
struct LayoutSection: View {
    @Environment(ExportSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Text("Layout").font(.headline)
            HStack {
                Text("Orientation")
                Spacer()
                Picker("Orientation", selection: $settings.orientation) {
                    ForEach(DeviceOrientation.allCases) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .fixedSize()
            }
            HStack {
                Text("Ratio")
                Spacer()
                Picker("Ratio", selection: $settings.ratio) {
                    ForEach(CanvasRatio.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .fixedSize()
            }
            Text("The device is resized to fit inside the chosen ratio.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

/// Margin and shadow around the device, shared by the screenshot and video editors.
struct MarginSection: View {
    @Environment(ExportSettings.self) private var settings

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Text("Margin").font(.headline)
            HStack {
                Slider(value: $settings.margin, in: 0...0.3)
                    .disabled(!settings.hasBackground && settings.ratio == .automatic)
                Text(settings.margin, format: .percent.precision(.fractionLength(0)))
                    .monospacedDigit()
                    .frame(width: 44, alignment: .trailing)
            }
            Toggle("Shadow", isOn: $settings.showsShadow)
                .disabled(!settings.hasBackground)
        }
    }
}

/// Device frame options, shared by the screenshot and video editors.
struct BezelSection: View {
    /// Size of the capture, used to suggest matching models.
    let size: CGSize?
    @Environment(ExportSettings.self) private var settings

    private var matching: [DeviceModel] { size.map(DeviceModel.matching) ?? [] }
    private var model: DeviceModel? { size.flatMap(settings.model(for:)) }

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Toggle(isOn: $settings.showsBezel) {
                Text("Device Frame").font(.headline)
            }
            .toggleStyle(.switch)
            .disabled(model == nil)

            if let model {
                Picker("Model", selection: $settings.modelID) {
                    Text("Automatic (\(matching.first?.name ?? model.name))").tag(String?.none)
                    if !matching.isEmpty {
                        Section("Same Screen as This Capture") {
                            ForEach(matching) { Text(verbatim: $0.name).tag(Optional($0.id)) }
                        }
                    }
                    Section("Other Models") {
                        ForEach(DeviceModel.all.reversed().filter { !matching.contains($0) }) {
                            Text(verbatim: $0.name).tag(Optional($0.id))
                        }
                    }
                }
                .disabled(!settings.showsBezel)

                if model.cutout.isDynamicIsland {
                    Toggle("Dynamic Island", isOn: $settings.showsDynamicIsland)
                        .disabled(!settings.showsBezel)
                }

                if !matching.isEmpty, !matching.contains(model) {
                    Text("This model has a different screen size: the capture is scaled to fill it.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ScrollView(.horizontal) {
                    HStack(spacing: 8) {
                        ForEach(model.finishes) { finish in
                            FinishOption(finish: finish, isSelected: settings.finish(for: model) == finish) {
                                settings.finishHex = finish.hex
                            }
                        }
                    }
                    .padding(2)
                }
                .scrollIndicators(.never)
                .disabled(!settings.showsBezel)
                .opacity(settings.showsBezel ? 1 : 0.4)
            } else {
                Text("Frames aren't available for this capture.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct FinishOption: View {
    let finish: DeviceFinish
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(LinearGradient(colors: finish.bandColors, startPoint: .leading, endPoint: .trailing))
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(.black)
                        .padding(2)
                    RoundedRectangle(cornerRadius: 5.5, style: .continuous)
                        .fill(LinearGradient(colors: [.blue.opacity(0.6), .pink.opacity(0.5)], startPoint: .top, endPoint: .bottom))
                        .padding(3.5)
                }
                .frame(width: 28, height: 56)
                .padding(8)
                .background(isSelected ? AnyShapeStyle(.tint.opacity(0.12)) : AnyShapeStyle(.clear), in: .rect(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                )
                Text(finish.name)
                    .font(.caption)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 64)
                    .foregroundStyle(isSelected ? .primary : .secondary)
            }
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

/// Background options, shared by the screenshot and video editors.
struct BackgroundSection: View {
    let suggestions: SuggestedBackgrounds
    @Environment(ExportSettings.self) private var settings
    @State private var addsColor = false
    @State private var addsGradient = false

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 6)

    var body: some View {
        @Bindable var settings = settings

        VStack(alignment: .leading, spacing: 10) {
            Text("Background").font(.headline)

            Picker("Background", selection: $settings.backgroundKind) {
                ForEach(BackgroundKind.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            LazyVGrid(columns: columns, spacing: 8) {
                Swatch(isSelected: !settings.hasBackground) {
                    CheckerSwatch()
                } action: {
                    settings.hasBackground = false
                }
                .help(Text("No Background"))

                switch settings.backgroundKind {
                case .color: colorSwatches
                case .gradient: gradientSwatches
                case .image: imageSwatches
                }
            }
        }
    }

    @ViewBuilder
    private var colorSwatches: some View {
        ForEach(suggestions.colors.map(\.hex), id: \.self) { hex in
            Swatch(isSelected: isSelected(color: hex), isSuggestion: true) {
                Color(hex: hex)
            } action: {
                settings.selectColor(hex)
            }
            .help(Text("Suggested from the capture"))
        }
        ForEach(settings.customColors, id: \.self) { hex in
            Swatch(isSelected: isSelected(color: hex)) {
                Color(hex: hex)
            } action: {
                settings.selectColor(hex)
            }
            .help(Text(verbatim: hex))
            .contextMenu {
                Button("Remove", role: .destructive) { settings.customColors.removeAll { $0 == hex } }
            }
        }
        AddSwatch { addsColor = true }
            .popover(isPresented: $addsColor, arrowEdge: .bottom) { AddColorsView() }
    }

    @ViewBuilder
    private var gradientSwatches: some View {
        ForEach(suggestions.gradients.map { $0.map(\.hex) }, id: \.self) { hexes in
            gradientSwatch(hexes, isSuggestion: true)
                .help(Text("Suggested from the capture"))
        }
        ForEach(settings.customGradients, id: \.self) { hexes in
            gradientSwatch(hexes)
                .contextMenu {
                    Button("Remove", role: .destructive) { settings.customGradients.removeAll { $0 == hexes } }
                }
        }
        ForEach(GradientPresets.all, id: \.self) { hexes in
            gradientSwatch(hexes)
        }
        AddSwatch { addsGradient = true }
            .popover(isPresented: $addsGradient, arrowEdge: .bottom) { AddGradientView() }
    }

    @ViewBuilder
    private var imageSwatches: some View {
        if let url = settings.backgroundImage, let image = NSImage(contentsOf: url) {
            Swatch(isSelected: settings.hasBackground) {
                Image(nsImage: image).resizable().scaledToFill()
            } action: {
                settings.hasBackground = true
            }
        }
        AddSwatch(action: chooseImage)
    }

    private func gradientSwatch(_ hexes: [String], isSuggestion: Bool = false) -> some View {
        Swatch(isSelected: settings.hasBackground && settings.gradientHexes == hexes, isSuggestion: isSuggestion) {
            LinearGradient(colors: hexes.compactMap { Color(hex: $0) }, startPoint: .topLeading, endPoint: .bottomTrailing)
        } action: {
            settings.selectGradient(hexes)
        }
    }

    private func isSelected(color hex: String) -> Bool {
        settings.hasBackground && settings.colorHex == hex
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

/// Paste one or more hex codes, or pick a color, to add it to the palette.
private struct AddColorsView: View {
    @Environment(ExportSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var picked = Color.white
    @State private var isInvalid = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add Colors").font(.headline)
            TextField("#FF9500, #34C759…", text: $text)
                .textFieldStyle(.roundedBorder)
                .font(.body.monospaced())
                .onSubmit(add)
            Text("Paste one or more hex codes.")
                .font(.caption)
                .foregroundStyle(isInvalid ? .red : .secondary)
            HStack {
                ColorPicker("Or pick a color", selection: $picked, supportsOpacity: false)
                Spacer()
                Button("Add Color") {
                    _ = settings.addColors(from: picked.hex)
                    dismiss()
                }
            }
            Divider()
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add", action: add)
                    .buttonStyle(.borderedProminent)
                    .disabled(text.isEmpty)
            }
        }
        .padding(16)
        .frame(width: 300)
        .onAppear {
            // Prefill with hex codes already on the clipboard.
            if let pasted = NSPasteboard.general.string(forType: .string), !Color.hexCodes(in: pasted).isEmpty {
                text = pasted
            }
        }
    }

    private func add() {
        if settings.addColors(from: text) {
            dismiss()
        } else {
            isInvalid = true
        }
    }
}

private struct AddGradientView: View {
    @Environment(ExportSettings.self) private var settings
    @Environment(\.dismiss) private var dismiss
    @State private var start = ""
    @State private var end = ""

    private var colors: [String]? {
        guard let first = Color(hex: start)?.hex, let last = Color(hex: end)?.hex else { return nil }
        return [first, last]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Add a Gradient").font(.headline)
            HStack {
                TextField("Start", text: $start, prompt: Text(verbatim: "#A1C4FD"))
                TextField("End", text: $end, prompt: Text(verbatim: "#FBC2EB"))
            }
            .textFieldStyle(.roundedBorder)
            .font(.body.monospaced())
            RoundedRectangle(cornerRadius: 8)
                .fill(LinearGradient(colors: (colors ?? []).compactMap { Color(hex: $0) }, startPoint: .leading, endPoint: .trailing))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .frame(height: 32)
            HStack {
                Spacer()
                Button("Cancel", role: .cancel) { dismiss() }
                Button("Add") {
                    guard let colors else { return }
                    settings.customGradients.insert(colors, at: 0)
                    settings.selectGradient(colors)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(colors == nil)
            }
        }
        .padding(16)
        .frame(width: 300)
    }
}

private struct Swatch<Content: View>: View {
    let isSelected: Bool
    var isSuggestion = false
    @ViewBuilder let content: Content
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            content
                .aspectRatio(1, contentMode: .fill)
                .frame(minWidth: 0, maxWidth: .infinity)
                .clipShape(.rect(cornerRadius: 8))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(.separator))
                .overlay(alignment: .bottomTrailing) {
                    if isSuggestion {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.white)
                            .shadow(color: .black.opacity(0.5), radius: 1)
                            .padding(4)
                    }
                }
                .padding(2)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .strokeBorder(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.clear), lineWidth: 2)
                )
                .contentShape(.rect)
        }
        .buttonStyle(.plain)
    }
}

private struct AddSwatch: View {
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "plus")
                .font(.title3)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .background(.quaternary.opacity(0.6), in: .rect(cornerRadius: 8))
                .padding(2)
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
