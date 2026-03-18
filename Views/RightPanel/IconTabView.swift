import SwiftUI

/// A draggable number field — drag left/right to adjust, or click to type
struct DraggableNumberField: View {
    @Binding var value: CGFloat
    var range: ClosedRange<CGFloat> = -291...291
    var label: String = ""

    @State private var dragStartValue: CGFloat = 0
    @State private var isEditing = false
    @State private var editText = ""

    var body: some View {
        HStack(spacing: 4) {
            if !label.isEmpty {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(width: 12)
            }

            if isEditing {
                TextField("", text: $editText)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption.monospacedDigit())
                    .frame(width: 52)
                    .onSubmit {
                        if let v = Double(editText) {
                            value = CGFloat(v).clamped(to: range)
                        }
                        isEditing = false
                    }
            } else {
                Text("\(Int(value))")
                    .font(.caption.monospacedDigit())
                    .frame(width: 44, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
                    .gesture(
                        DragGesture(minimumDistance: 1)
                            .onChanged { drag in
                                if dragStartValue == 0 && drag.translation.width == 0 { return }
                                if abs(drag.translation.width) < 1 {
                                    dragStartValue = value
                                }
                                let delta = drag.translation.width * 0.5
                                value = (dragStartValue + CGFloat(delta)).clamped(to: range)
                            }
                            .onEnded { _ in
                                dragStartValue = value
                            }
                    )
                    .onTapGesture(count: 2) {
                        editText = "\(Int(value))"
                        isEditing = true
                    }
                    .help("Drag to adjust, double-click to type")
            }
        }
    }
}

extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        return Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}

struct IconTabView: View {
    @Bindable var model: FolderIconModel
    @State private var sliderValue: CGFloat = 256
    @State private var offsetX: CGFloat = 0
    @State private var offsetY: CGFloat = 0

    var body: some View {
        Form {
            Section("Type") {
                Picker("Icon Type", selection: $model.iconOverlay.type) {
                    ForEach(IconOverlayType.allCases, id: \.self) { type in
                        Text(type.rawValue.capitalized).tag(type)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: model.iconOverlay.type) {
                    // Reset shadow to default for the new type
                    model.iconOverlay.shadowType = model.iconOverlay.defaultShadowType
                }
            }

            Section("Source") {
                IconPickerView(model: model) {
                    model.forceRender()
                }
            }

            Section("Color") {
                ColorPicker("Icon Color", selection: $model.iconOverlay.color, supportsOpacity: true)
            }

            Section("Shadow") {
                Picker("Shadow", selection: $model.iconOverlay.shadowType) {
                    ForEach(OverlayShadowType.allCases, id: \.self) { t in
                        Text(t.rawValue).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                if model.iconOverlay.shadowType != .none {
                    HStack {
                        Text("Intensity")
                            .font(.caption)
                        Slider(value: $model.iconOverlay.shadowIntensity, in: 0...1)
                    }
                }
            }

            Section("Size") {
                SizePresetGrid(selection: Binding(
                    get: { model.iconOverlay.sizePreset },
                    set: { newPreset in
                        model.iconOverlay.sizePreset = newPreset
                        if let p = newPreset {
                            sliderValue = p.displayValue
                            model.iconOverlay.customSizeValue = sliderValue
                        }
                    }
                ))

                HStack(spacing: 8) {
                    Slider(value: $sliderValue, in: 32...400)
                        .onChange(of: sliderValue) {
                            model.iconOverlay.sizePreset = nil
                            model.iconOverlay.customSizeValue = sliderValue
                        }
                    TextField("", text: Binding(
                        get: { "\(Int(sliderValue))" },
                        set: { if let v = Double($0) { sliderValue = CGFloat(v) } }
                    ))
                        .frame(width: 44)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption.monospacedDigit())
                        .onChange(of: sliderValue) {
                            model.iconOverlay.sizePreset = nil
                            model.iconOverlay.customSizeValue = sliderValue
                        }
                }
            }

            Section("Position") {
                PositionGrid(selection: Binding(
                    get: { model.iconOverlay.position },
                    set: { newPos in
                        model.iconOverlay.position = newPos
                        model.iconOverlay.customOffset = .zero
                        offsetX = 0
                        offsetY = 0
                    }
                ))

                HStack(spacing: 12) {
                    DraggableNumberField(value: $offsetX, label: "X")
                        .onChange(of: offsetX) {
                            model.iconOverlay.customOffset.x = offsetX / 512
                        }
                    DraggableNumberField(value: $offsetY, label: "Y")
                        .onChange(of: offsetY) {
                            model.iconOverlay.customOffset.y = offsetY / 512
                        }
                    Spacer()
                    Button("Reset") {
                        model.iconOverlay.customOffset = .zero
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
            sliderValue = model.iconOverlay.customSizeValue
            offsetX = model.iconOverlay.customOffset.x * 512
            offsetY = model.iconOverlay.customOffset.y * 512
        }
        .onChange(of: model.iconOverlay.customOffset.x) {
            let newX = model.iconOverlay.customOffset.x * 512
            if abs(newX - offsetX) > 0.5 { offsetX = newX }
        }
        .onChange(of: model.iconOverlay.customOffset.y) {
            let newY = model.iconOverlay.customOffset.y * 512
            if abs(newY - offsetY) > 0.5 { offsetY = newY }
        }
    }
}
