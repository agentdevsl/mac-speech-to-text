import AppKit
import SwiftUI
import XCTest

/// Helper class for capturing screenshots of SwiftUI views during testing
/// Used to verify UI layout and detect visual regressions
@MainActor
final class ScreenshotTestHelper {
    /// Directory where screenshots are saved
    private let screenshotDirectory: URL

    /// Initialize with a custom screenshot directory
    init(testName: String) {
        let tempDir = FileManager.default.temporaryDirectory
        screenshotDirectory = tempDir.appendingPathComponent("SpeechToTextScreenshots/\(testName)")

        // Create directory if it doesn't exist
        try? FileManager.default.createDirectory(
            at: screenshotDirectory,
            withIntermediateDirectories: true
        )
    }

    /// Capture a screenshot of a SwiftUI view
    /// - Parameters:
    ///   - view: The SwiftUI view to capture
    ///   - size: The size to render the view at
    ///   - name: A descriptive name for the screenshot
    /// - Returns: The URL of the saved screenshot, or nil if capture failed
    @discardableResult
    func captureScreenshot<V: View>(
        of view: V,
        size: CGSize,
        name: String
    ) -> URL? {
        // Create hosting view
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)

        // Force layout
        hostingView.layoutSubtreeIfNeeded()

        // Create bitmap representation
        guard let bitmapRep = hostingView.bitmapImageRepForCachingDisplay(in: hostingView.bounds) else {
            return nil
        }

        hostingView.cacheDisplay(in: hostingView.bounds, to: bitmapRep)

        // Convert to PNG
        guard let pngData = bitmapRep.representation(using: .png, properties: [:]) else {
            return nil
        }

        // Save to file
        let fileName = "\(name).png"
        let fileURL = screenshotDirectory.appendingPathComponent(fileName)

        do {
            try pngData.write(to: fileURL)
            print("Screenshot saved to: \(fileURL.path)")
            return fileURL
        } catch {
            print("Failed to save screenshot: \(error)")
            return nil
        }
    }

    /// Verify that a view renders without any content being clipped
    /// - Parameters:
    ///   - view: The SwiftUI view to check
    ///   - size: The size to render the view at
    /// - Returns: A tuple containing (isValid, issues) where issues describes any problems found
    func verifyViewFitsInBounds<V: View>(
        view: V,
        size: CGSize
    ) -> (isValid: Bool, issues: [String]) {
        var issues: [String] = []

        // Create hosting view
        let hostingView = NSHostingView(rootView: view)
        hostingView.frame = NSRect(origin: .zero, size: size)

        // Force layout
        hostingView.layoutSubtreeIfNeeded()

        // Check intrinsic content size
        let intrinsicSize = hostingView.intrinsicContentSize

        if intrinsicSize.width > size.width && intrinsicSize.width != NSView.noIntrinsicMetric {
            issues.append("Content width (\(Int(intrinsicSize.width))) exceeds container width (\(Int(size.width)))")
        }

        if intrinsicSize.height > size.height && intrinsicSize.height != NSView.noIntrinsicMetric {
            issues.append("Content height (\(Int(intrinsicSize.height))) exceeds container height (\(Int(size.height)))")
        }

        // Check fitting size
        let fittingSize = hostingView.fittingSize

        if fittingSize.width > size.width {
            issues.append("Fitting width (\(Int(fittingSize.width))) exceeds container width (\(Int(size.width)))")
        }

        if fittingSize.height > size.height {
            issues.append("Fitting height (\(Int(fittingSize.height))) exceeds container height (\(Int(size.height)))")
        }

        return (issues.isEmpty, issues)
    }

    /// Get the path to the screenshot directory
    var screenshotPath: String {
        screenshotDirectory.path
    }
}

/// Extension to add screenshot testing assertions
extension XCTestCase {
    /// Assert that a view renders correctly at the given size
    @MainActor
    func assertViewRendersCorrectly<V: View>(
        _ view: V,
        size: CGSize,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let helper = ScreenshotTestHelper(testName: name)
        let result = helper.verifyViewFitsInBounds(view: view, size: size)

        if !result.isValid {
            let message = "View layout issues:\n" + result.issues.joined(separator: "\n")
            XCTFail(message, file: file, line: line)
        }
    }

    /// Capture a screenshot of a view and return the file URL
    @MainActor
    @discardableResult
    func captureScreenshot<V: View>(
        of view: V,
        size: CGSize,
        name: String
    ) -> URL? {
        let helper = ScreenshotTestHelper(testName: self.name)
        return helper.captureScreenshot(of: view, size: size, name: name)
    }
}
