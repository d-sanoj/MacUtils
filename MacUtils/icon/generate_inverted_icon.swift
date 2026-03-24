import AppKit
import CoreGraphics
import CoreImage

func invertImageAndAddBackground(inputPath: String, outputPath: String) {
    let url = URL(fileURLWithPath: inputPath)
    guard let nsImage = NSImage(contentsOf: url),
          let cgImage = nsImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
        print("Failed to load image")
        exit(1)
    }

    let width = cgImage.width
    let height = cgImage.height
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

    guard let context = CGContext(data: nil,
                                  width: width,
                                  height: height,
                                  bitsPerComponent: 8,
                                  bytesPerRow: width * 4,
                                  space: colorSpace,
                                  bitmapInfo: bitmapInfo) else {
        print("Failed to create context")
        exit(1)
    }

    // 1. Draw black background
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))

    // 2. Draw the icon into the context
    context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

    guard let drawnImage = context.makeImage() else { exit(1) }

    // 3. Invert the whole thing (black becomes white, white becomes black)
    // Since our icon was black on transparent, drawing it on a black background made it all black!
    // Wait, the icon is black on transparent.
    // Let's do this: 
    // Fill context with black. Then draw the icon tinted WHITE.
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    context.setFillColor(NSColor.black.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    
    // To tint the icon white, we can mask the context with the icon's alpha
    context.saveGState()
    context.clip(to: CGRect(x: 0, y: 0, width: width, height: height), mask: cgImage)
    context.setFillColor(NSColor.white.cgColor)
    context.fill(CGRect(x: 0, y: 0, width: width, height: height))
    context.restoreGState()

    guard let finalCGImage = context.makeImage() else {
        print("Failed to make final image")
        exit(1)
    }

    let rep = NSBitmapImageRep(cgImage: finalCGImage)
    guard let pngData = rep.representation(using: .png, properties: [:]) else {
        print("Failed to generate png")
        exit(1)
    }

    do {
        try pngData.write(to: URL(fileURLWithPath: outputPath))
        print("Success: \(outputPath)")
    } catch {
        print("Failed to save: \(error)")
        exit(1)
    }
}

// Ensure args
let args = CommandLine.arguments
if args.count < 3 { exit(1) }
invertImageAndAddBackground(inputPath: args[1], outputPath: args[2])
