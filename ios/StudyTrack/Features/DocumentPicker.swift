import SwiftUI
import UniformTypeIdentifiers

/// Use a single generic file type. Some file providers assign XLSX a dynamic
/// UTI that does not match the spreadsheet/ZIP declarations in a filtered picker.
struct StudyDocumentPicker: UIViewControllerRepresentable {
    enum Mode {
        case file,folder
        var contentTypes: [UTType] { self == .folder ? [.folder] : [.item] }
        var asCopy: Bool { self == .file }
    }
    var mode: Mode = .file
    var onSelection: (URL) -> Void
    var onCancel: () -> Void
    static func makeController(for mode: Mode) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: mode.contentTypes,asCopy: mode.asCopy)
        picker.allowsMultipleSelection = false
        picker.shouldShowFileExtensions = true
        #if DEBUG
        if mode == .file,ProcessInfo.processInfo.arguments.contains("-uitesting-showcase") {
            picker.directoryURL = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask).first
        }
        #endif
        return picker
    }
    func makeCoordinator() -> Coordinator { Coordinator(self) }
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = Self.makeController(for: mode); picker.delegate = context.coordinator; return picker
    }
    func updateUIViewController(_ picker: UIDocumentPickerViewController,context: Context) { context.coordinator.parent = self }
    final class Coordinator: NSObject,UIDocumentPickerDelegate {
        var parent: StudyDocumentPicker
        init(_ parent: StudyDocumentPicker) { self.parent = parent }
        func documentPicker(_ controller: UIDocumentPickerViewController,didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { parent.onSelection(url) } else { parent.onCancel() }
        }
        func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) { parent.onCancel() }
    }
}
