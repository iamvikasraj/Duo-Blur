import UIKit
import CoreImage
import Vision

/// Lifts the foreground subject out of a wallpaper image using Vision's
/// on-device subject segmentation (the same capability behind the iOS lock
/// screen's depth effect).
///
/// The returned image is the subject on a transparent background, at the
/// same pixel dimensions as the input, so drawing it with the wallpaper's
/// exact layout keeps the cutout perfectly registered over the original.
enum SubjectLift {
    static func cutout(fromImageNamed name: String) async -> UIImage? {
        guard let source = UIImage(named: name)?.cgImage else { return nil }
        let request = GenerateForegroundInstanceMaskRequest()
        do {
            guard let observation = try await request.perform(on: source) else { return nil }
            let handler = ImageRequestHandler(source)
            let buffer = try observation.generateMaskedImage(
                for: observation.allInstances,
                imageFrom: handler,
                croppedToInstancesExtent: false
            )
            let ciImage = CIImage(cvPixelBuffer: buffer)
            guard let cgImage = CIContext().createCGImage(ciImage, from: ciImage.extent) else {
                return nil
            }
            return UIImage(cgImage: cgImage)
        } catch {
            // No subject found (or segmentation failed): the view simply
            // renders without the depth layer.
            return nil
        }
    }
}
