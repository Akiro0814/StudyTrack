import SwiftUI
import UIKit
import StudyTrackCore

struct StudyPrimaryButtonStyle: ButtonStyle {
    @Environment(AppModel.self) private var model
    @Environment(\.isEnabled) private var enabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.padding(.horizontal,16).padding(.vertical,10)
            .foregroundStyle(darkText ? Color.black : Color.white)
            .background(model.accent,in: Capsule()).opacity(enabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
    var darkText: Bool {
        var r: CGFloat = 0,g: CGFloat = 0,b: CGFloat = 0,a: CGFloat = 0
        UIColor(model.accent).getRed(&r,green: &g,blue: &b,alpha: &a)
        return RGBColor(red: Int(r*255),green: Int(g*255),blue: Int(b*255)).usesDarkText
    }
}

extension UIImage {
    /// Sample the visible central content area; a protective scrim handles mixed photos.
    var prefersLightText: Bool {
        let width = 12, height = 20
        var bytes = [UInt8](repeating: 0,count: width*height*4)
        guard let cgImage, let context = CGContext(data: &bytes,width: width,height: height,bitsPerComponent: 8,bytesPerRow: width*4,space: CGColorSpaceCreateDeviceRGB(),bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { return true }
        context.draw(cgImage,in: CGRect(x: 0,y: 0,width: width,height: height))
        var samples: [Double] = []
        for index in stride(from: 0,to: bytes.count,by: 4) {
            let red = Double(bytes[index]) * 0.2126
            let green = Double(bytes[index+1]) * 0.7152
            let blue = Double(bytes[index+2]) * 0.0722
            samples.append((red+green+blue)/255.0)
        }
        samples.sort()
        return samples[samples.count/2] < 0.57
    }
}

struct SwipeDeleteRow<Content: View>: View {
    var action: () -> Void
    var onTap: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    @State private var dragStart: CGFloat?
    var body: some View {
        ZStack(alignment: .trailing) {
            if offset < 0 {
                Button(role: .destructive,action: action) {
                    Image(systemName: "trash").frame(width: 72,height: 60).foregroundStyle(.white)
                        .background(.red,in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain).accessibilityLabel("删除成绩")
            }
            content.frame(maxWidth: .infinity,alignment: .leading)
                .overlay {
                    ScoreRowGestures(tap: {
                        if offset < 0 { withAnimation(.snappy(duration: 0.2)) { offset = 0 } }
                        else { onTap() }
                    },drag: { translation in
                        if dragStart == nil { dragStart = offset }
                        offset = min(0,max(-88,(dragStart ?? 0)+translation))
                    },end: { cancelled in
                        dragStart = nil
                        withAnimation(.snappy(duration: 0.2)) { offset = !cancelled && offset < -36 ? -80 : 0 }
                    }).accessibilityHidden(true)
                }.offset(x: offset)
        }.clipped()
            .accessibilityAction(named: Text("编辑成绩"),onTap)
            .accessibilityAction(named: Text("删除成绩"),action)
    }
}

/// Direction is decided before the recognizer begins, so vertical scrolling is
/// left to the parent scroll view. A tap explicitly waits for the pan to fail.
private struct ScoreRowGestures: UIViewRepresentable {
    @Environment(\.isEnabled) private var enabled
    var tap: () -> Void
    var drag: (CGFloat) -> Void
    var end: (Bool) -> Void
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIView {
        let view = UIView(); view.backgroundColor = .clear; view.isUserInteractionEnabled = enabled
        let pan = UIPanGestureRecognizer(target: context.coordinator,action: #selector(Coordinator.pan(_:)))
        pan.maximumNumberOfTouches = 1; pan.delegate = context.coordinator
        let tap = UITapGestureRecognizer(target: context.coordinator,action: #selector(Coordinator.tap(_:)))
        tap.require(toFail: pan)
        view.addGestureRecognizer(pan); view.addGestureRecognizer(tap)
        return view
    }
    func updateUIView(_ view: UIView,context: Context) { context.coordinator.parent = self; view.isUserInteractionEnabled = enabled }
    final class Coordinator: NSObject,UIGestureRecognizerDelegate {
        var parent: ScoreRowGestures
        init(_ parent: ScoreRowGestures) { self.parent = parent }
        func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
            guard let pan = gestureRecognizer as? UIPanGestureRecognizer else { return true }
            let velocity = pan.velocity(in: pan.view?.window)
            return abs(velocity.x) > abs(velocity.y)*1.4
        }
        @objc func tap(_ recognizer: UITapGestureRecognizer) { if recognizer.state == .ended { parent.tap() } }
        @objc func pan(_ recognizer: UIPanGestureRecognizer) {
            switch recognizer.state {
            case .began,.changed: parent.drag(recognizer.translation(in: recognizer.view?.window).x)
            case .ended: parent.end(false)
            case .cancelled,.failed: parent.end(true)
            default: break
            }
        }
    }
}
