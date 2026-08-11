import ImageIO
import SwiftUI
import UIKit

struct StoredReceiptImage: View {
    let data: Data
    let cacheKey: String
    let maxPixelSize: Int

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else {
                ZStack {
                    Color(uiColor: .secondarySystemBackground)
                    ProgressView()
                }
                .accessibilityLabel("Loading receipt image")
            }
        }
        .task(id: cacheKey) {
            image = await ReceiptImageLoader.image(
                data: data,
                cacheKey: "\(cacheKey)-\(maxPixelSize)",
                maxPixelSize: maxPixelSize
            )
        }
    }
}

private enum ReceiptImageLoader {
    private static let cache = ReceiptImageCache()

    static func image(data: Data, cacheKey: String, maxPixelSize: Int) async -> UIImage? {
        if let cached = cache.image(for: cacheKey) { return cached }
        let decoded = await Task.detached(priority: .userInitiated) {
            autoreleasepool { downsample(data: data, maxPixelSize: maxPixelSize) }
        }.value
        if let decoded { cache.insert(decoded, for: cacheKey) }
        return decoded
    }

    private static func downsample(data: Data, maxPixelSize: Int) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ] as CFDictionary
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: image)
    }
}

private final class ReceiptImageCache: @unchecked Sendable {
    private let values = NSCache<NSString, UIImage>()

    init() {
        values.countLimit = 24
        values.totalCostLimit = 64 * 1_024 * 1_024
    }

    func image(for key: String) -> UIImage? {
        values.object(forKey: key as NSString)
    }

    func insert(_ image: UIImage, for key: String) {
        let cost = image.cgImage.map { $0.bytesPerRow * $0.height } ?? 0
        values.setObject(image, forKey: key as NSString, cost: cost)
    }
}
