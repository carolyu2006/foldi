import SwiftUI
import UniformTypeIdentifiers

struct ImageUploadView: View {
    @Binding var image: NSImage?
    @Binding var previewImage: NSImage?

    var body: some View {
        VStack(spacing: 12) {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(height: 80)

                Button("Remove") {
                    self.image = nil
                    self.previewImage = nil
                }
            }

            Button("Choose Image...") {
                let panel = NSOpenPanel()
                panel.allowedContentTypes = [.image]
                panel.allowsMultipleSelection = false
                if panel.runModal() == .OK, let url = panel.url {
                    let original = NSImage(contentsOf: url)
                    self.image = original
                    self.previewImage = original.flatMap { Self.downscale($0, maxDim: 512) }
                }
            }
        }
    }

    /// Downscale an image to fit within maxDim × maxDim for preview rendering
    static func downscale(_ image: NSImage, maxDim: CGFloat) -> NSImage {
        let w = image.size.width
        let h = image.size.height
        guard w > maxDim || h > maxDim else { return image }
        let scale = maxDim / max(w, h)
        let newSize = NSSize(width: w * scale, height: h * scale)
        let result = NSImage(size: newSize)
        result.lockFocus()
        NSGraphicsContext.current?.imageInterpolation = .high
        image.draw(in: NSRect(origin: .zero, size: newSize))
        result.unlockFocus()
        return result
    }
}
