import SwiftUI

/// Routes an attempted sheet swipe through the same discard confirmation as Cancel.
struct DismissGuard: UIViewControllerRepresentable {
    let isDirty: Bool
    let onAttempt: () -> Void
    func makeUIViewController(context: Context) -> Controller { Controller() }
    func updateUIViewController(_ controller: Controller, context: Context) {
        controller.isDirty = isDirty; controller.onAttempt = onAttempt
        DispatchQueue.main.async { controller.attach() }
    }
    final class Controller: UIViewController, UIAdaptivePresentationControllerDelegate {
        var isDirty = false
        var onAttempt: (() -> Void)?
        override func viewDidAppear(_ animated: Bool) { super.viewDidAppear(animated); attach() }
        func attach() {
            var host: UIViewController = self
            while let parent = host.parent { host = parent }
            host.presentationController?.delegate = self
        }
        func presentationControllerShouldDismiss(_ presentationController: UIPresentationController) -> Bool { !isDirty }
        func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) { onAttempt?() }
    }
}
