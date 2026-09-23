import AVFoundation
import CoreImage
import SwiftUI

/// Still images drawn around each video frame: the background and device below the
/// screen, the notch or Dynamic Island above it, and the rounded screen mask.
nonisolated struct FrameLayers: @unchecked Sendable {
    let below: CIImage
    let above: CIImage
    let mask: CIImage
    /// Screen rectangle in Core Image coordinates (origin at the bottom left).
    let screenRect: CGRect
    let canvas: CGSize

    /// Renders the layers for a video of `videoSize`, or nil when there is no frame or background.
    @MainActor
    static func make(style: CompositionStyle, videoSize: CGSize) -> FrameLayers? {
        guard style.showsBezel || style.background != .none else { return nil }
        let layout = CompositionLayout(image: videoSize, style: style)

        func render<V: View>(_ view: V) -> CIImage? {
            let renderer = ImageRenderer(content: view.frame(width: layout.canvas.width, height: layout.canvas.height))
            renderer.scale = 1
            return renderer.cgImage.map { CIImage(cgImage: $0) }
        }

        let screen = CGRect(origin: layout.screenOrigin, size: layout.screen)
        let maskView = ZStack(alignment: .topLeading) {
            Color.black
            RoundedRectangle(cornerRadius: layout.screenRadius, style: .continuous)
                .fill(.white)
                .frame(width: screen.width, height: screen.height)
                .offset(x: screen.minX, y: screen.minY)
        }
        guard let below = render(ScreenshotComposition(imageSize: videoSize, style: style, part: .belowScreen)),
              let above = render(ScreenshotComposition(imageSize: videoSize, style: style, part: .aboveScreen)),
              let mask = render(maskView) else { return nil }

        let canvas = below.extent.size
        return FrameLayers(
            below: below,
            above: above,
            mask: mask,
            screenRect: CGRect(x: screen.minX, y: canvas.height - screen.maxY, width: screen.width, height: screen.height),
            canvas: canvas
        )
    }
}

/// Builds an AVFoundation composition from the source video and its edits,
/// for the preview player and for exports.
nonisolated enum VideoRenderer {
    struct Output: @unchecked Sendable {
        let composition: AVMutableComposition
        let videoComposition: AVMutableVideoComposition?
        let audioMix: AVMutableAudioMix?
        let renderSize: CGSize
    }

    /// Size of the video once rotated and cropped.
    static func editedSize(source: CGSize, edits: VideoEdits) -> CGSize {
        var size = source
        if edits.rotation % 2 != 0 { size = CGSize(width: size.height, height: size.width) }
        return edits.crop.rect(in: CGRect(origin: .zero, size: size)).size
    }

    static func build(
        asset: AVURLAsset,
        edits: VideoEdits,
        layers: FrameLayers?,
        renderScale: Double,
        frameRate: Double?,
        includesAudio: Bool = true
    ) async throws -> Output {
        let composition = AVMutableComposition()
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first,
              let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw CaptureError.writeFailed
        }
        let sourceAudio = includesAudio ? try await asset.loadTracks(withMediaType: .audio).first : nil
        let audioTrack = sourceAudio.flatMap { _ in
            composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
        }

        var cursor = CMTime.zero
        for segment in edits.segments {
            let range = CMTimeRange(start: time(segment.start), end: time(segment.end))
            try videoTrack.insertTimeRange(range, of: sourceVideo, at: cursor)
            if let sourceAudio, let audioTrack {
                try? audioTrack.insertTimeRange(range, of: sourceAudio, at: cursor)
            }
            cursor = cursor + range.duration
        }
        if edits.speed != 1 {
            composition.scaleTimeRange(CMTimeRange(start: .zero, duration: cursor),
                                       toDuration: CMTimeMultiplyByFloat64(cursor, multiplier: 1 / edits.speed))
        }
        let duration = composition.duration

        var parameters: [AVMutableAudioMixInputParameters] = []
        if let audioTrack {
            let input = AVMutableAudioMixInputParameters(track: audioTrack)
            input.setVolume(edits.isMuted ? 0 : Float(edits.volume), at: .zero)
            parameters.append(input)
        }
        if includesAudio, let musicURL = edits.musicURL,
           let music = try? await AVURLAsset(url: musicURL).loadTracks(withMediaType: .audio).first,
           let musicTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) {
            let musicDuration = try await music.load(.timeRange).duration
            try musicTrack.insertTimeRange(CMTimeRange(start: .zero, duration: CMTimeMinimum(musicDuration, duration)), of: music, at: .zero)
            let input = AVMutableAudioMixInputParameters(track: musicTrack)
            input.setVolume(Float(edits.musicVolume), at: .zero)
            parameters.append(input)
        }
        let audioMix: AVMutableAudioMix?
        if parameters.isEmpty {
            audioMix = nil
        } else {
            audioMix = AVMutableAudioMix()
            audioMix?.inputParameters = parameters
        }

        let naturalSize = try await sourceVideo.load(.naturalSize)
        let transform = try await sourceVideo.load(.preferredTransform)
        let sourceSize = CGRect(origin: .zero, size: naturalSize).applying(transform).size
        let videoSize = editedSize(source: sourceSize, edits: edits)
        let baseSize = layers?.canvas ?? videoSize
        let renderSize = CGSize(width: even(baseSize.width * renderScale), height: even(baseSize.height * renderScale))

        let needsComposition = layers != nil || edits.hasVideoAdjustments || renderScale != 1 || frameRate != nil
        guard needsComposition else {
            return Output(composition: composition, videoComposition: nil, audioMix: audioMix, renderSize: videoSize)
        }

        // The macOS 26 filtering API can't set a custom render size yet, which frames need.
        let videoComposition = AVMutableVideoComposition(
            asset: composition,
            applyingCIFiltersWithHandler: frameHandler(edits: edits, layers: layers, renderScale: renderScale, renderSize: renderSize)
        )
        videoComposition.renderSize = renderSize
        if let frameRate {
            // Filtered compositions follow the source frame timing unless told otherwise.
            videoComposition.sourceTrackIDForFrameTiming = kCMPersistentTrackID_Invalid
            videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(frameRate.rounded()))
        } else {
            let sourceRate = try await sourceVideo.load(.nominalFrameRate)
            videoComposition.frameDuration = CMTime(value: 1, timescale: CMTimeScale(sourceRate > 0 ? sourceRate.rounded() : 30))
        }
        return Output(composition: composition, videoComposition: videoComposition, audioMix: audioMix, renderSize: renderSize)
    }

    private static func frameHandler(
        edits: VideoEdits, layers: FrameLayers?, renderScale: Double, renderSize: CGSize
    ) -> @Sendable (AVAsynchronousCIImageFilteringRequest) -> Void {
        { request in
            let frame = process(request.sourceImage, edits: edits)
            var output = layers.map { compose(frame, in: $0) } ?? frame
            if renderScale != 1 {
                output = output.transformed(by: CGAffineTransform(scaleX: renderScale, y: renderScale))
            }
            request.finish(with: output.cropped(to: CGRect(origin: .zero, size: renderSize)), context: nil)
        }
    }

    /// Rotation, crop, filter and adjustments.
    static func process(_ source: CIImage, edits: VideoEdits) -> CIImage {
        var image = source
        let orientations: [CGImagePropertyOrientation] = [.up, .right, .down, .left]
        if edits.rotation % 4 != 0 {
            image = image.oriented(orientations[((edits.rotation % 4) + 4) % 4])
            image = image.transformed(by: CGAffineTransform(translationX: -image.extent.minX, y: -image.extent.minY))
        }
        if edits.crop != .original {
            let rect = edits.crop.rect(in: image.extent)
            image = image.cropped(to: rect).transformed(by: CGAffineTransform(translationX: -rect.minX, y: -rect.minY))
        }
        if let name = edits.filter.ciFilterName, let filter = CIFilter(name: name) {
            filter.setValue(image, forKey: kCIInputImageKey)
            image = filter.outputImage ?? image
        }
        if edits.brightness != 0 || edits.contrast != 1 || edits.saturation != 1 {
            image = image.applyingFilter("CIColorControls", parameters: [
                kCIInputBrightnessKey: edits.brightness,
                kCIInputContrastKey: edits.contrast,
                kCIInputSaturationKey: edits.saturation,
            ])
        }
        return image
    }

    /// Places the frame in the screen, between the device layers.
    static func compose(_ frame: CIImage, in layers: FrameLayers) -> CIImage {
        let screen = layers.screenRect
        let scale = max(screen.width / frame.extent.width, screen.height / frame.extent.height)
        let scaled = frame.transformed(by: CGAffineTransform(scaleX: scale, y: scale))
        let placed = scaled
            .transformed(by: CGAffineTransform(
                translationX: screen.midX - scaled.extent.midX,
                y: screen.midY - scaled.extent.midY
            ))
            .cropped(to: screen)
        let blended = placed.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: layers.below,
            kCIInputMaskImageKey: layers.mask,
        ])
        return layers.above.composited(over: blended).cropped(to: CGRect(origin: .zero, size: layers.canvas))
    }

    private static func time(_ seconds: Double) -> CMTime {
        CMTime(seconds: seconds, preferredTimescale: 600)
    }

    private static func even(_ value: CGFloat) -> CGFloat {
        max(2, (value / 2).rounded() * 2)
    }
}
