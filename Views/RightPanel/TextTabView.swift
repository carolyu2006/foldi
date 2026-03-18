import SwiftUI

struct TextTabView: View {
    @Bindable var model: FolderIconModel
    @State private var sliderValue: CGFloat = 205
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    private let weights: [(String, Font.Weight)] = [
        ("Light", .light), ("Regular", .regular), ("Medium", .medium),
        ("medium", .medium), ("medium", .medium), ("Heavy", .heavy),
    ]

    private var availableFonts: [String] {
        NSFontManager.shared.availableFontFamilies.sorted()
    }

    var body: some View {
        Form {
            Section("Content") {
                TextField("Label text", text: $model.textOverlay.content)
            }

            Section("Font") {
                Picker("Family", selection: $model.textOverlay.fontName) {
                    ForEach(availableFonts, id: \.self) { name in
                        Text(name)
                            .font(.custom(name, size: 14))
                            .tag(name)
                    }
                }

                Picker("Weight", selection: $model.textOverlay.fontWeight) {
                    ForEach(weights, id: \.0) { name, weight in
                        Text(name).tag(weight)
                    }
                }
            }

            Section("Appearance") {
                ColorPicker("Color", selection: $model.textOverlay.color, supportsOpacity: true)
            }

            Section("Shadow") {
                Picker("Shadow", selection: $model.textOverlay.shadowType) {
                    ForEach(OverlayShadowType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                if model.textOverlay.shadowType != .none {
                    HStack {
                        Text("Intensity")
                            .font(.caption)
                        Slider(value: $model.textOverlay.shadowIntensity, in: 0...1)
                    }
                }
            }

            Section("Size") {
                SizePresetGrid(selection: Binding(
                    get: { model.textOverlay.sizePreset },
                    set: { newPreset in
                        model.textOverlay.sizePreset = newPreset
                        if let p = newPreset {
                            sliderValue = p.displayValue
                            model.textOverlay.customFontSize = sliderValue
                        }
                    }
                ))

                HStack(spacing: 8) {
                    Slider(value: $sliderValue, in: 8...200)
                        .onChange(of: sliderValue) {
                            model.textOverlay.sizePreset = nil
                            model.textOverlay.customFontSize = sliderValue
                        }
                    TextField("", text: Binding(
                        get: { "\(Int(sliderValue))" },
                        set: { if let v = Double($0) { sliderValue = CGFloat(v) } }
                    ))
                        .frame(width: 44)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospacedDigit())
                        .onChange(of: sliderValue) {
                            model.textOverlay.sizePreset = nil
                            model.textOverlay.customFontSize = sliderValue
                        }
                }
            }

            Section("Position") {
                PositionGrid(selection: Binding(
                    get: { model.textOverlay.position },
                    set: { newPos in
                        model.textOverlay.position = newPos
                        model.textOverlay.customOffset = .zero
                        offsetX = 0
                        offsetY = 0
                    }
                ))

                HStack(spacing: 12) {
                    DraggableNumberField(value: $offsetX, label: "X")
                        .onChange(of: offsetX) {
                            model.textOverlay.customOffset.x = offsetX / 512
                        }
                    DraggableNumberField(value: $offsetY, label: "Y")
                        .onChange(of: offsetY) {
                            model.textOverlay.customOffset.y = offsetY / 512
                        }
                    Spacer()
                    Button("Reset") {
                        model.textOverlay.customOffset = .zero
                        offsetX = 0
                        offsetY = 0
                    }
                    .font(.caption)
                    .buttonStyle(.borderless)
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            sliderValue = model.textOverlay.customFontSize
            offsetX = model.textOverlay.customOffset.x * 512
            offsetY = model.textOverlay.customOffset.y * 512
        }
        .onChange(of: model.textOverlay.customOffset.x) {
            let newX = model.textOverlay.customOffset.x * 512
            if abs(newX - offsetX) > 0.5 { offsetX = newX }
        }
        .onChange(of: model.textOverlay.customOffset.y) {
            let newY = model.textOverlay.customOffset.y * 512
            if abs(newY - offsetY) > 0.5 { offsetY = newY }
        }
    }
}
