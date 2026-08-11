import CoreImage
import CoreImage.CIFilterBuiltins
import SwiftUI
import UIKit

struct ReceiptCropEditor: View {
    @Environment(\.dismiss) private var dismiss

    let image: UIImage
    let pageNumber: Int
    let completion: (UIImage) -> Void

    @State private var workingImage: UIImage
    @State private var quad = ReceiptCropQuad.inset
    @State private var errorMessage: String?

    init(image: UIImage, pageNumber: Int = 1, completion: @escaping (UIImage) -> Void) {
        self.image = image
        self.pageNumber = pageNumber
        self.completion = completion
        _workingImage = State(initialValue: image.normalizedForReceiptEditing)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                GeometryReader { proxy in
                    let imageRect = aspectFitRect(imageSize: workingImage.size, in: proxy.size)

                    ZStack {
                        Color.black

                        Image(uiImage: workingImage)
                            .resizable()
                            .scaledToFit()
                            .frame(width: imageRect.width, height: imageRect.height)
                            .position(x: imageRect.midX, y: imageRect.midY)

                        cropOverlay(in: imageRect)
                    }
                    .coordinateSpace(name: "receiptCropCanvas")
                }

                VStack(spacing: 12) {
                    Text("Drag each corner to the edge of the receipt. The result will be straightened before text is read.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)

                    HStack {
                        Button("Reset", systemImage: "arrow.counterclockwise") { quad = .inset }
                        Spacer()
                        Button("Rotate", systemImage: "rotate.right") {
                            workingImage = workingImage.rotatedClockwiseForReceiptEditing
                            quad = .inset
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(.bar)
            }
            .navigationTitle("Crop page \(pageNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Crop") { applyCrop() }
                        .fontWeight(.semibold)
                }
            }
            .alert("Couldn’t crop receipt", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "Move the corners farther apart and try again.")
            }
        }
    }

    @ViewBuilder
    private func cropOverlay(in rect: CGRect) -> some View {
        let points = quad.points.map { point in
            CGPoint(x: rect.minX + point.x * rect.width, y: rect.minY + point.y * rect.height)
        }

        ZStack {
            Path { path in
                guard let first = points.first else { return }
                path.move(to: first)
                points.dropFirst().forEach { path.addLine(to: $0) }
                path.closeSubpath()
            }
            .stroke(.teal, style: StrokeStyle(lineWidth: 3, lineJoin: .round))

            ForEach(ReceiptCropCorner.allCases) { corner in
                let point = points[corner.rawValue]
                Circle()
                    .fill(.white)
                    .stroke(.teal, lineWidth: 4)
                    .frame(width: 30, height: 30)
                    .contentShape(Rectangle().inset(by: -14))
                    .position(point)
                    .gesture(
                        DragGesture(minimumDistance: 0, coordinateSpace: .named("receiptCropCanvas"))
                            .onChanged { value in
                                guard rect.width > 0, rect.height > 0 else { return }
                                let normalized = CGPoint(
                                    x: (value.location.x - rect.minX) / rect.width,
                                    y: (value.location.y - rect.minY) / rect.height
                                )
                                var updated = quad
                                updated.move(corner, to: normalized)
                                quad = updated
                            }
                    )
                    .accessibilityLabel(corner.accessibilityLabel)
                    .accessibilityHint("Drag this handle to the matching receipt corner")
                    .accessibilityIdentifier("receiptCrop.\(corner.identifier)")
            }
        }
    }

    private func applyCrop() {
        do {
            let cropped = try ReceiptImageCropper.crop(workingImage, to: quad)
            completion(cropped)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func aspectFitRect(imageSize: CGSize, in container: CGSize) -> CGRect {
        guard imageSize.width > 0, imageSize.height > 0, container.width > 0, container.height > 0 else {
            return .zero
        }
        let scale = min(container.width / imageSize.width, container.height / imageSize.height)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (container.width - size.width) / 2,
            y: (container.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }
}

private enum ReceiptCropCorner: Int, CaseIterable, Identifiable {
    case topLeft
    case topRight
    case bottomRight
    case bottomLeft

    var id: Int { rawValue }

    var identifier: String {
        switch self {
        case .topLeft: "topLeft"
        case .topRight: "topRight"
        case .bottomRight: "bottomRight"
        case .bottomLeft: "bottomLeft"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .topLeft: "Top-left crop corner"
        case .topRight: "Top-right crop corner"
        case .bottomRight: "Bottom-right crop corner"
        case .bottomLeft: "Bottom-left crop corner"
        }
    }
}

private struct ReceiptCropQuad {
    var topLeft: CGPoint
    var topRight: CGPoint
    var bottomRight: CGPoint
    var bottomLeft: CGPoint

    static let inset = ReceiptCropQuad(
        topLeft: CGPoint(x: 0.04, y: 0.04),
        topRight: CGPoint(x: 0.96, y: 0.04),
        bottomRight: CGPoint(x: 0.96, y: 0.96),
        bottomLeft: CGPoint(x: 0.04, y: 0.96)
    )

    var points: [CGPoint] { [topLeft, topRight, bottomRight, bottomLeft] }

    mutating func move(_ corner: ReceiptCropCorner, to proposed: CGPoint) {
        let edgeInset = 0.01
        let minimumGap = 0.04
        switch corner {
        case .topLeft:
            topLeft = CGPoint(
                x: proposed.x.clamped(to: edgeInset...(topRight.x - minimumGap)),
                y: proposed.y.clamped(to: edgeInset...(bottomLeft.y - minimumGap))
            )
        case .topRight:
            topRight = CGPoint(
                x: proposed.x.clamped(to: (topLeft.x + minimumGap)...(1 - edgeInset)),
                y: proposed.y.clamped(to: edgeInset...(bottomRight.y - minimumGap))
            )
        case .bottomRight:
            bottomRight = CGPoint(
                x: proposed.x.clamped(to: (bottomLeft.x + minimumGap)...(1 - edgeInset)),
                y: proposed.y.clamped(to: (topRight.y + minimumGap)...(1 - edgeInset))
            )
        case .bottomLeft:
            bottomLeft = CGPoint(
                x: proposed.x.clamped(to: edgeInset...(bottomRight.x - minimumGap)),
                y: proposed.y.clamped(to: (topLeft.y + minimumGap)...(1 - edgeInset))
            )
        }
    }
}

private enum ReceiptImageCropper {
    enum CropError: LocalizedError {
        case invalidImage
        case invalidCrop

        var errorDescription: String? {
            switch self {
            case .invalidImage: "The receipt image could not be prepared for cropping."
            case .invalidCrop: "The selected crop area is too small or could not be rendered."
            }
        }
    }

    static func crop(_ image: UIImage, to quad: ReceiptCropQuad) throws -> UIImage {
        let normalized = image.normalizedForReceiptEditing
        guard let input = CIImage(image: normalized) else { throw CropError.invalidImage }

        let extent = input.extent
        func coreImagePoint(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: extent.minX + point.x * extent.width,
                y: extent.minY + (1 - point.y) * extent.height
            )
        }

        let filter = CIFilter.perspectiveCorrection()
        filter.inputImage = input
        filter.topLeft = coreImagePoint(quad.topLeft)
        filter.topRight = coreImagePoint(quad.topRight)
        filter.bottomRight = coreImagePoint(quad.bottomRight)
        filter.bottomLeft = coreImagePoint(quad.bottomLeft)
        filter.crop = true

        guard let output = filter.outputImage,
              output.extent.width >= 40,
              output.extent.height >= 40,
              let cgImage = CIContext(options: [.useSoftwareRenderer: false]).createCGImage(output, from: output.extent) else {
            throw CropError.invalidCrop
        }
        return UIImage(cgImage: cgImage, scale: normalized.scale, orientation: .up)
    }
}

private extension CGFloat {
    func clamped(to range: ClosedRange<CGFloat>) -> CGFloat {
        min(max(self, range.lowerBound), range.upperBound)
    }
}

private extension UIImage {
    var normalizedForReceiptEditing: UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    var rotatedClockwiseForReceiptEditing: UIImage {
        let source = normalizedForReceiptEditing
        let outputSize = CGSize(width: source.size.height, height: source.size.width)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = source.scale
        return UIGraphicsImageRenderer(size: outputSize, format: format).image { context in
            context.cgContext.translateBy(x: outputSize.width / 2, y: outputSize.height / 2)
            context.cgContext.rotate(by: .pi / 2)
            source.draw(in: CGRect(
                x: -source.size.width / 2,
                y: -source.size.height / 2,
                width: source.size.width,
                height: source.size.height
            ))
        }
    }
}
