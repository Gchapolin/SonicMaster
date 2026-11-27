import AVFoundation
import AVKit
import Flutter
import UIKit

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  private var pip: PipController?

  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    if let registrar = engineBridge.pluginRegistry.registrar(forPlugin: "SonicMasterPip") {
      pip = PipController(registrar: registrar)
    }
  }
}

/// A Picture-in-Picture window showing the current preset over other apps.
/// Its skip buttons step presets (sent to Dart as `next` / `previous` on the
/// `sonicmaster/pip` channel, see lib/state/pip_bridge.dart); its restore
/// button brings the app back. The content is a still frame rendered here on
/// every `update` from Dart.
final class PipController: NSObject, AVPictureInPictureControllerDelegate,
  AVPictureInPictureSampleBufferPlaybackDelegate
{
  private let channel: FlutterMethodChannel
  private weak var registrar: FlutterPluginRegistrar?
  private let layer = AVSampleBufferDisplayLayer()
  private var host: UIView?
  private var controller: AVPictureInPictureController?
  private var info: [String: Any] = [:]

  /// 2:1, drawn at 2x: a compact, readable window.
  private let size = CGSize(width: 320, height: 160)

  init(registrar: FlutterPluginRegistrar) {
    channel = FlutterMethodChannel(
      name: "sonicmaster/pip", binaryMessenger: registrar.messenger())
    self.registrar = registrar
    super.init()
    channel.setMethodCallHandler { [weak self] call, result in
      switch call.method {
      case "setEnabled":
        self?.setEnabled(call.arguments as? Bool ?? false)
      case "update":
        self?.info = call.arguments as? [String: Any] ?? [:]
        self?.render()
      default:
        result(FlutterMethodNotImplemented)
        return
      }
      result(nil)
    }
  }

  private func setEnabled(_ on: Bool) {
    guard on else {
      controller?.stopPictureInPicture()
      controller = nil
      host?.removeFromSuperview()
      host = nil
      return
    }
    guard controller == nil, AVPictureInPictureController.isPictureInPictureSupported(),
      let root = registrar?.viewController?.view
    else { return }

    // Plays alongside other apps' audio; an active playback session is what
    // allows PiP at all.
    try? AVAudioSession.sharedInstance().setCategory(.playback, options: .mixWithOthers)
    try? AVAudioSession.sharedInstance().setActive(true)

    // The layer must be in the view hierarchy; keep it tiny and out of the way.
    let view = UIView(frame: CGRect(x: 0, y: 0, width: 2, height: 1))
    view.isUserInteractionEnabled = false
    view.alpha = 0.01
    layer.frame = view.bounds
    layer.videoGravity = .resizeAspect
    view.layer.addSublayer(layer)
    root.addSubview(view)
    host = view

    let pip = AVPictureInPictureController(
      contentSource: .init(sampleBufferDisplayLayer: layer, playbackDelegate: self))
    pip.delegate = self
    pip.canStartPictureInPictureAutomaticallyFromInline = true
    controller = pip
    render()
  }

  // MARK: Rendering

  private func color(_ key: String, _ fallback: UInt32) -> UIColor {
    let v = (info[key] as? NSNumber)?.uint32Value ?? fallback
    return UIColor(
      red: CGFloat((v >> 16) & 0xFF) / 255, green: CGFloat((v >> 8) & 0xFF) / 255,
      blue: CGFloat(v & 0xFF) / 255, alpha: 1)
  }

  private func render() {
    guard controller != nil else { return }
    let label = info["label"] as? String ?? "--"
    let name = info["name"] as? String ?? ""
    let device = info["device"] as? String ?? ""
    let connected = info["connected"] as? Bool ?? false
    let modified = info["modified"] as? Bool ?? false
    let bg = color("bg", 0xFF3E2C28)
    let fg = color("fg", 0xFFF0ECE9)
    let accent = color("accent", 0xFFDF9D8E)
    let ok = color("ok", 0xFF9FBF8F)

    let format = UIGraphicsImageRendererFormat()
    format.scale = 2
    format.opaque = true
    let image = UIGraphicsImageRenderer(size: size, format: format).image { ctx in
      bg.setFill()
      ctx.fill(CGRect(origin: .zero, size: size))

      NSAttributedString(
        string: label + (modified ? "*" : ""),
        attributes: [
          .font: UIFont.systemFont(ofSize: 44, weight: .heavy), .foregroundColor: accent,
        ]
      ).draw(at: CGPoint(x: 18, y: 12))

      NSAttributedString(
        string: name,
        attributes: [
          .font: UIFont.systemFont(ofSize: 26, weight: .semibold), .foregroundColor: fg,
        ]
      ).draw(
        with: CGRect(x: 18, y: 72, width: size.width - 36, height: 34),
        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)

      (connected ? ok : fg.withAlphaComponent(0.4)).setFill()
      ctx.cgContext.fillEllipse(in: CGRect(x: 18, y: 126, width: 12, height: 12))
      NSAttributedString(
        string: device,
        attributes: [
          .font: UIFont.systemFont(ofSize: 16), .foregroundColor: fg.withAlphaComponent(0.7),
        ]
      ).draw(
        with: CGRect(x: 38, y: 122, width: size.width - 56, height: 22),
        options: [.usesLineFragmentOrigin, .truncatesLastVisibleLine], context: nil)
    }

    if let buffer = Self.sampleBuffer(from: image) {
      layer.flush()
      layer.enqueue(buffer)
    }
  }

  private static func sampleBuffer(from image: UIImage) -> CMSampleBuffer? {
    guard let cg = image.cgImage else { return nil }
    let w = cg.width
    let h = cg.height
    var pixels: CVPixelBuffer?
    let attrs = [kCVPixelBufferIOSurfacePropertiesKey: [:]] as CFDictionary
    guard
      CVPixelBufferCreate(kCFAllocatorDefault, w, h, kCVPixelFormatType_32BGRA, attrs, &pixels)
        == kCVReturnSuccess, let pb = pixels
    else { return nil }

    CVPixelBufferLockBaseAddress(pb, [])
    let ctx = CGContext(
      data: CVPixelBufferGetBaseAddress(pb), width: w, height: h, bitsPerComponent: 8,
      bytesPerRow: CVPixelBufferGetBytesPerRow(pb), space: CGColorSpaceCreateDeviceRGB(),
      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
        | CGBitmapInfo.byteOrder32Little.rawValue)
    ctx?.draw(cg, in: CGRect(x: 0, y: 0, width: w, height: h))
    CVPixelBufferUnlockBaseAddress(pb, [])

    var format: CMVideoFormatDescription?
    CMVideoFormatDescriptionCreateForImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescriptionOut: &format)
    guard let fmt = format else { return nil }

    var timing = CMSampleTimingInfo(
      duration: .invalid, presentationTimeStamp: CMClockGetTime(CMClockGetHostTimeClock()),
      decodeTimeStamp: .invalid)
    var sample: CMSampleBuffer?
    CMSampleBufferCreateReadyWithImageBuffer(
      allocator: kCFAllocatorDefault, imageBuffer: pb, formatDescription: fmt,
      sampleTiming: &timing, sampleBufferOut: &sample)

    if let s = sample,
      let attachments = CMSampleBufferGetSampleAttachmentsArray(s, createIfNecessary: true),
      CFArrayGetCount(attachments) > 0
    {
      let dict = unsafeBitCast(
        CFArrayGetValueAtIndex(attachments, 0), to: CFMutableDictionary.self)
      CFDictionarySetValue(
        dict, Unmanaged.passUnretained(kCMSampleAttachmentKey_DisplayImmediately).toOpaque(),
        Unmanaged.passUnretained(kCFBooleanTrue).toOpaque())
    }
    return sample
  }

  // MARK: AVPictureInPictureSampleBufferPlaybackDelegate

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController, setPlaying playing: Bool
  ) {}

  /// A finite range (a live, infinite one hides the skip buttons) around the
  /// playhead: the layer runs on the host clock, so a range from zero would
  /// leave the playhead past its end and the forward skip disabled.
  func pictureInPictureControllerTimeRangeForPlayback(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> CMTimeRange {
    let day = CMTime(value: 86_400, timescale: 1)
    let now = CMClockGetTime(CMClockGetHostTimeClock())
    return CMTimeRange(start: now - CMTimeMultiplyByRatio(day, multiplier: 1, divisor: 2), duration: day)
  }

  func pictureInPictureControllerIsPlaybackPaused(
    _ pictureInPictureController: AVPictureInPictureController
  ) -> Bool { false }

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    didTransitionToRenderSize newRenderSize: CMVideoDimensions
  ) {}

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    skipByInterval skipInterval: CMTime, completion completionHandler: @escaping () -> Void
  ) {
    channel.invokeMethod(skipInterval.seconds < 0 ? "previous" : "next", arguments: nil)
    completionHandler()
  }

  // MARK: AVPictureInPictureControllerDelegate

  func pictureInPictureController(
    _ pictureInPictureController: AVPictureInPictureController,
    restoreUserInterfaceForPictureInPictureStopWithCompletionHandler completionHandler:
      @escaping (Bool) -> Void
  ) {
    completionHandler(true)
  }
}
