import SwiftUI
import UIKit

@MainActor final class BoardCoordinates {
    weak var scroll: UIScrollView?
    weak var content: UIView?
    var manualPinch = false
    var isPinching: Bool { manualPinch || scroll?.isZooming == true }
    func cell(at point: CGPoint) -> Int? {
        guard let content, let scroll else { return nil }
        let viewport = scroll.convert(point, from: nil)
        guard scroll.bounds.contains(viewport), content.bounds.width > 0 else { return nil }
        let local = content.convert(point, from: nil)
        guard content.bounds.contains(local) else { return nil }
        let side = content.bounds.width / 15
        return min(14, Int(local.y / side)) * 15 + min(14, Int(local.x / side))
    }
}

struct ZoomBoard<Content: View>: UIViewRepresentable {
    let side: CGFloat
    let scale: CGFloat
    let focus: Int
    let revision: Int
    let enabled: Bool
    let coordinates: BoardCoordinates
    let onZoomEnd: (CGFloat) -> Void
    @ViewBuilder let content: () -> Content

    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIView(context: Context) -> UIScrollView {
        let scroll = UIScrollView()
        scroll.minimumZoomScale = 1
        scroll.maximumZoomScale = 3.5
        scroll.bouncesZoom = true
        scroll.showsHorizontalScrollIndicator = false
        scroll.showsVerticalScrollIndicator = false
        scroll.contentInsetAdjustmentBehavior = .never
        scroll.delegate = context.coordinator
        // A dedicated recognizer cooperates with the hosted SwiftUI tile gestures.
        scroll.pinchGestureRecognizer?.isEnabled = false
        let pinch = UIPinchGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.pinch(_:)))
        pinch.delegate = context.coordinator
        pinch.cancelsTouchesInView = true
        scroll.addGestureRecognizer(pinch)
        context.coordinator.pinchRecognizer = pinch
        let host = context.coordinator.host
        host.view.backgroundColor = .clear
        host.view.frame = CGRect(x: 0, y: 0, width: side, height: side)
        scroll.addSubview(host.view)
        scroll.contentSize = CGSize(width: side, height: side)
        coordinates.scroll = scroll
        coordinates.content = host.view
        return scroll
    }
    func updateUIView(_ scroll: UIScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        coordinator.host.rootView = content()
        coordinator.pinchRecognizer?.isEnabled = enabled
        if coordinator.side != side {
            scroll.setZoomScale(1, animated: false)
            coordinator.host.view.frame = CGRect(x: 0, y: 0, width: side, height: side)
            scroll.contentSize = CGSize(width: side, height: side)
            coordinator.side = side
            // Reapply the requested zoom after a window resize changes the board size.
            coordinator.revision = -1
        }
        guard coordinator.revision != revision else { return }
        coordinator.revision = revision
        // Native zoom(to:) animates both scale and offset as one operation.
        scroll.layoutIfNeeded()
        let width = scroll.bounds.width / scale
        let height = scroll.bounds.height / scale
        let center = CGPoint(x: (CGFloat(focus % 15) + 0.5) * side / 15,
                             y: (CGFloat(focus / 15) + 0.5) * side / 15)
        let rect = CGRect(x: max(0, min(side - width, center.x - width / 2)),
                          y: max(0, min(side - height, center.y - height / 2)), width: width, height: height)
        if scale <= 1 { scroll.setZoomScale(1, animated: true) }
        else if width > 0 && height > 0 { scroll.zoom(to: rect, animated: true) }
    }
    final class Coordinator: NSObject, UIScrollViewDelegate, UIGestureRecognizerDelegate {
        weak var pinchRecognizer: UIPinchGestureRecognizer?
        var startScale: CGFloat = 1
        var anchor = CGPoint.zero
        var parent: ZoomBoard
        let host: UIHostingController<Content>
        var revision = -1
        var side: CGFloat
        init(_ parent: ZoomBoard) {
            self.parent = parent
            side = parent.side
            host = UIHostingController(rootView: parent.content())
        }
        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer,
                               shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
            gestureRecognizer === pinchRecognizer || otherGestureRecognizer === pinchRecognizer
        }
        @objc func pinch(_ recognizer: UIPinchGestureRecognizer) {
            guard let scroll = parent.coordinates.scroll else { return }
            switch recognizer.state {
            case .began:
                parent.coordinates.manualPinch = true
                startScale = scroll.zoomScale
                anchor = recognizer.location(in: host.view)
                scroll.panGestureRecognizer.isEnabled = false
            case .changed:
                let location = recognizer.location(in: scroll)
                let viewportPoint = CGPoint(x: location.x - scroll.bounds.minX, y: location.y - scroll.bounds.minY)
                let scale = min(scroll.maximumZoomScale, max(scroll.minimumZoomScale, startScale * recognizer.scale))
                scroll.setZoomScale(scale, animated: false)
                let x = anchor.x * scale - viewportPoint.x
                let y = anchor.y * scale - viewportPoint.y
                scroll.contentOffset = CGPoint(x: max(0, min(x, scroll.contentSize.width - scroll.bounds.width)),
                                               y: max(0, min(y, scroll.contentSize.height - scroll.bounds.height)))
            case .ended, .cancelled, .failed:
                parent.coordinates.manualPinch = false
                scroll.panGestureRecognizer.isEnabled = true
                parent.onZoomEnd(scroll.zoomScale)
            default: break
            }
        }
        func viewForZooming(in scrollView: UIScrollView) -> UIView? { host.view }
        func scrollViewDidEndZooming(_ scrollView: UIScrollView, with view: UIView?, atScale scale: CGFloat) {
            if !parent.coordinates.manualPinch { parent.onZoomEnd(scale) }
        }
    }
}
