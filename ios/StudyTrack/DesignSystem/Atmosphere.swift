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
        let samples = stride(from: 0,to: bytes.count,by: 4).map { index in
            (0.2126*Double(bytes[index])+0.7152*Double(bytes[index+1])+0.0722*Double(bytes[index+2]))/255
        }.sorted()
        return samples[samples.count/2] < 0.57
    }
}

struct ProgressiveTopBlur: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    var body: some View {
        GeometryReader { proxy in
            Rectangle().fill(reduceTransparency ? AnyShapeStyle(Color(uiColor: .systemBackground)) : AnyShapeStyle(.ultraThinMaterial))
                .mask { LinearGradient(stops: [.init(color: .black,location: 0),.init(color: .black.opacity(0.9),location: 0.35),.init(color: .clear,location: 1)],startPoint: .top,endPoint: .bottom) }
                .frame(height: proxy.safeAreaInsets.top + 72).frame(maxHeight: .infinity,alignment: .top).ignoresSafeArea(edges: .top)
        }.allowsHitTesting(false).accessibilityHidden(true)
    }
}

struct SwipeDeleteRow<Content: View>: View {
    var action: () -> Void
    @ViewBuilder var content: Content
    @State private var offset: CGFloat = 0
    var body: some View {
        ZStack(alignment: .leading) {
            if offset > 0 { Button(role: .destructive,action: action) { Label("删除",systemImage: "trash").labelStyle(.iconOnly).frame(width: 64,height: 60) }.tint(.red) }
            content.offset(x: offset)
                .simultaneousGesture(DragGesture(minimumDistance: 24).onChanged { value in
                    guard abs(value.translation.width) > abs(value.translation.height)*1.5 else { return }
                    offset = min(84,max(0,value.translation.width))
                }.onEnded { _ in withAnimation(.snappy) { offset = offset > 44 ? 76 : 0 } })
        }.clipped().accessibilityAction(named: Text("删除成绩"),action)
    }
}
