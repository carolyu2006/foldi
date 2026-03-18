import SwiftUI

struct StylePreset: Identifiable {
    let id = UUID()
    let name: String
    let description: String
    let tintColor: Color
    let backColor: Color
}
