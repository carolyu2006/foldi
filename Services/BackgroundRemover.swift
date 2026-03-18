import AppKit
import CoreImage
import Vision

struct BackgroundRemover {

    static func removeBackground(from image: NSImage) -> NSImage {
        if #available(macOS 14.0, *) {
            if let result = removeWithVision(image) {
                return result
            }
        }
        // Fallback: chromakey green screen removal
        return chromakeyRemove(from: image)
    }

    // MARK: - Vision (macOS 14+)

    @available(macOS 14.0, *)
    private static func removeWithVision(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }

        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
        } catch {
            print("[BackgroundRemover] Vision request failed: \(error)")
            return nil
        }

        guard let result = request.results?.first else { return nil }

        do {
            let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
            let maskCIImage = CIImage(cvPixelBuffer: maskPixelBuffer)
            let originalCIImage = CIImage(cgImage: cgImage)

            // Use the mask to composite foreground onto clear background
            let filter = CIFilter(name: "CIBlendWithMask")!
            filter.setValue(originalCIImage, forKey: kCIInputImageKey)
            filter.setValue(CIImage.empty(), forKey: kCIInputBackgroundImageKey)
            filter.setValue(maskCIImage, forKey: kCIInputMaskImageKey)

            guard let outputCIImage = filter.outputImage else { return nil }

            let context = CIContext()
            let outputRect = outputCIImage.extent
            guard let outputCGImage = context.createCGImage(outputCIImage, from: outputRect) else { return nil }

            return NSImage(cgImage: outputCGImage, size: image.size)
        } catch {
            print("[BackgroundRemover] Mask generation failed: \(error)")
            return nil
        }
    }

    // MARK: - Chromakey (green screen fallback)

    private static func chromakeyRemove(from image: NSImage) -> NSImage {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return image }

        let width = cgImage.width
        let height = cgImage.height
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue

        guard let context = CGContext(
            data: nil, width: width, height: height,
            bitsPerComponent: 8, bytesPerRow: width * 4,
            space: colorSpace, bitmapInfo: bitmapInfo
        ) else { return image }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return image }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Target: #00FF00, tolerance for compressed images
        let tolerance: Int = 80

        for i in 0..<(width * height) {
            let offset = i * 4
            let r = Int(pixels[offset])
            let g = Int(pixels[offset + 1])
            let b = Int(pixels[offset + 2])

            // Check if pixel is close to bright green
            if r < tolerance && g > (255 - tolerance) && b < tolerance {
                pixels[offset + 3] = 0 // set alpha to 0
            }
        }

        guard let resultCG = context.makeImage() else { return image }
        return NSImage(cgImage: resultCG, size: image.size)
    }
}
