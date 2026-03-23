import AppKit
import FinderSync

class FinderSyncExtension: FIFinderSync {

    override init() {
        super.init()
        // Monitor all file system URLs
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/")]
    }

    // MARK: - Context Menu

    override func menu(for menuKind: FIMenuKind) -> NSMenu {
        let menu = NSMenu(title: "Mac Utils")

        return menu
    }
}
