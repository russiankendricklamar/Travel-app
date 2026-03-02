import UIKit
import CoreImage
import CoreImage.CIFilterBuiltins

enum BarcodeService {

    static func generateBarcode(
        from content: String,
        type: BarcodeType,
        size: CGSize = CGSize(width: 300, height: 300)
    ) -> UIImage? {
        let context = CIContext()

        let ciImage: CIImage?

        switch type {
        case .qr:
            let filter = CIFilter.qrCodeGenerator()
            filter.message = Data(content.utf8)
            filter.correctionLevel = "M"
            ciImage = filter.outputImage
        case .code128:
            let filter = CIFilter.code128BarcodeGenerator()
            filter.message = Data(content.utf8)
            ciImage = filter.outputImage
        }

        guard let output = ciImage else { return nil }

        let scaleX = size.width / output.extent.size.width
        let scaleY = size.height / output.extent.size.height
        let scale = min(scaleX, scaleY)

        let scaled = output.transformed(by: CGAffineTransform(scaleX: scale, y: scale))

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }
}
