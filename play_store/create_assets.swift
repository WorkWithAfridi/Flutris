import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let repository = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let assets = repository.appending(path: "play_store/assets")

func loadImage(_ relativePath: String) throws -> CGImage {
    let url = repository.appending(path: relativePath)
    guard
        let source = CGImageSourceCreateWithURL(url as CFURL, nil),
        let image = CGImageSourceCreateImageAtIndex(source, 0, nil)
    else {
        throw NSError(domain: "FlutrisStoreAssets", code: 1, userInfo: [
            NSLocalizedDescriptionKey: "Could not load \(relativePath)",
        ])
    }
    return image
}

func writePNG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.png.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "FlutrisStoreAssets", code: 2, userInfo: [
            NSLocalizedDescriptionKey: "Could not create PNG at \(url.path)",
        ])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "FlutrisStoreAssets", code: 3, userInfo: [
            NSLocalizedDescriptionKey: "Could not write PNG at \(url.path)",
        ])
    }
}

func writeJPEG(_ image: CGImage, to url: URL) throws {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL,
        UTType.jpeg.identifier as CFString,
        1,
        nil
    ) else {
        throw NSError(domain: "FlutrisStoreAssets", code: 4, userInfo: [
            NSLocalizedDescriptionKey: "Could not create JPEG at \(url.path)",
        ])
    }
    CGImageDestinationAddImage(
        destination,
        image,
        [kCGImageDestinationLossyCompressionQuality: 0.92] as CFDictionary
    )
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "FlutrisStoreAssets", code: 5, userInfo: [
            NSLocalizedDescriptionKey: "Could not write JPEG at \(url.path)",
        ])
    }
}

func canvas(width: Int, height: Int) throws -> CGContext {
    guard let context = CGContext(
        data: nil,
        width: width,
        height: height,
        bitsPerComponent: 8,
        bytesPerRow: width * 4,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else {
        throw NSError(domain: "FlutrisStoreAssets", code: 6, userInfo: [
            NSLocalizedDescriptionKey: "Could not create bitmap context",
        ])
    }
    context.interpolationQuality = .high
    return context
}

let iconSource = try loadImage("assets/branding/flutris-app-icon.png")
let iconContext = try canvas(width: 512, height: 512)
iconContext.draw(iconSource, in: CGRect(x: 0, y: 0, width: 512, height: 512))
guard let icon = iconContext.makeImage() else {
    throw NSError(domain: "FlutrisStoreAssets", code: 7, userInfo: [
        NSLocalizedDescriptionKey: "Could not render icon",
    ])
}
try writePNG(icon, to: assets.appending(path: "app-icon-512.png"))

let featureSource = try loadImage("assets/branding/flutris-readme-cover.png")
let featureContext = try canvas(width: 1024, height: 500)
let scale = max(1024.0 / CGFloat(featureSource.width), 500.0 / CGFloat(featureSource.height))
let scaledWidth = CGFloat(featureSource.width) * scale
let scaledHeight = CGFloat(featureSource.height) * scale
let featureRect = CGRect(
    x: (1024.0 - scaledWidth) / 2,
    y: (500.0 - scaledHeight) / 2,
    width: scaledWidth,
    height: scaledHeight
)
featureContext.setFillColor(CGColor(srgbRed: 0.29, green: 0.19, blue: 0.38, alpha: 1))
featureContext.fill(CGRect(x: 0, y: 0, width: 1024, height: 500))
featureContext.draw(featureSource, in: featureRect)
guard let feature = featureContext.makeImage() else {
    throw NSError(domain: "FlutrisStoreAssets", code: 8, userInfo: [
        NSLocalizedDescriptionKey: "Could not render feature graphic",
    ])
}
try writeJPEG(feature, to: assets.appending(path: "feature-graphic-1024x500.jpg"))

print("Wrote 512 × 512 RGBA app icon and 1024 × 500 JPEG feature graphic.")
