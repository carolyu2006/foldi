import AppKit

extension NSImage {
    func composited(with overlay: NSImage, at point: NSPoint, size: NSSize? = nil) -> NSImage {
        let result = self.copy() as! NSImage
        result.lockFocus()
        let drawSize = size ?? overlay.size
        overlay.draw(in: NSRect(origin: point, size: drawSize),
                     from: .zero,
                     operation: .sourceOver,
                     fraction: 1.0)
        result.unlockFocus()
        return result
    }
}
