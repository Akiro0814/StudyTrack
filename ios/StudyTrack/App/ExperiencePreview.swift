#if DEBUG
import SwiftUI
import StudyTrackCore

extension AppModel {
    /// Deterministic UI fixtures exercise the same asset/database paths as a picked photo.
    /// Never included or executed in the Release application.
    func seedExperiencePreview() async throws {
        guard let store, let files else { return }
        let scope = try await store.createUser(name: "林同学",semester: "高一 · 上学期")
        let subject = try await store.saveSubject(id: nil,name: "数学",fullScore: 10000,scope: scope)
        _ = try await store.saveSubject(id: nil,name: "英语",fullScore: 15000,scope: scope)
        let sameDay = try LocalDate("2026-10-14")
        for (index,score) in [4500,5800,6100,7600,7900].enumerated() {
            _ = try await store.saveExams([ExamInput(subjectID: subject.id,name: "阶段练习 \(index+1)",date: sameDay,score: Int64(score),classRank: index == 2 ? nil : 24-index*4)],scope: scope)
        }
        let wallpaper = UIGraphicsImageRenderer(size: CGSize(width: 720,height: 1280)).image { renderer in
            let colors = [UIColor(red: 0.25,green: 0.40,blue: 0.65,alpha: 1).cgColor,UIColor(red: 0.84,green: 0.62,blue: 0.47,alpha: 1).cgColor,UIColor(red: 0.80,green: 0.84,blue: 0.75,alpha: 1).cgColor]
            let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(),colors: colors as CFArray,locations: [0,0.55,1])!
            renderer.cgContext.drawLinearGradient(gradient,start: CGPoint(x: 0,y: 0),end: CGPoint(x: 720,y: 1280),options: [])
        }.jpegData(compressionQuality: 0.9)!
        let avatar = UIGraphicsImageRenderer(size: CGSize(width: 256,height: 256)).image { renderer in
            UIColor(red: 0.85,green: 0.40,blue: 0.28,alpha: 1).setFill(); renderer.fill(CGRect(x: 0,y: 0,width: 256,height: 256))
            let symbol = UIImage(systemName: "person.crop.circle.fill",withConfiguration: UIImage.SymbolConfiguration(pointSize: 180))!
            symbol.withTintColor(.white,renderingMode: .alwaysOriginal).draw(in: CGRect(x: 38,y: 38,width: 180,height: 180))
        }.jpegData(compressionQuality: 0.9)!
        let wallpaperCandidate = try await files.saveWallpaper(wallpaper)
        let wallpaperAsset = try await store.addAsset(wallpaperCandidate)
        let avatarCandidate = try await files.saveAvatar(avatar)
        let avatarAsset = try await store.addAsset(avatarCandidate)
        var p = try await store.preferences()
        p.wallpaperAssetID = wallpaperAsset.id; p.setAvatarAssetID(avatarAsset.id,for: scope.userID)
        p.theme = "simple"
        try await store.updatePreferences(p)
        // Exercise the real system document picker with a selectable XLSX, not
        // just a decoder unit test. Real app data remains in Application Support.
        let documents = FileManager.default.urls(for: .documentDirectory,in: .userDomainMask)[0]
        try FileManager.default.createDirectory(at: documents,withIntermediateDirectories: true)
        let rows = try await store.exportRows(scope: scope)
        try XLSXCodec.encode(rows).write(to: documents.appendingPathComponent("StudyTrack Import Test.xlsx"),options: .atomic)
    }
}
#endif
