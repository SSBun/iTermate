import AppKit
import CoreGraphics

struct PanelLayout {
    static let gap: CGFloat = 8
    static let width: CGFloat = 260

    static func frame(for windowFrame: CGRect, in visibleFrame: CGRect) -> CGRect {
        let height = min(windowFrame.height, visibleFrame.height)
        let y = min(
            max(windowFrame.minY, visibleFrame.minY),
            visibleFrame.maxY - height
        )

        let rightX = windowFrame.maxX + gap
        let leftX = windowFrame.minX - width - gap
        let x: CGFloat

        if rightX + width <= visibleFrame.maxX {
            x = rightX
        } else if leftX >= visibleFrame.minX {
            x = leftX
        } else {
            x = min(
                max(windowFrame.maxX - width - gap, visibleFrame.minX),
                visibleFrame.maxX - width
            )
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func appKitFrame(fromQuartzFrame frame: CGRect) -> CGRect {
        let mainDisplayFrame = CGDisplayBounds(CGMainDisplayID())
        return CGRect(
            x: frame.minX,
            y: mainDisplayFrame.maxY - frame.maxY,
            width: frame.width,
            height: frame.height
        )
    }

    static func screen(containing frame: CGRect) -> NSScreen? {
        NSScreen.screens.max { first, second in
            intersectionArea(first.frame, frame) < intersectionArea(second.frame, frame)
        }
    }

    private static func intersectionArea(_ first: CGRect, _ second: CGRect) -> CGFloat {
        let intersection = first.intersection(second)
        return intersection.isNull ? 0 : intersection.width * intersection.height
    }
}
