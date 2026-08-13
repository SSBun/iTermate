import AppKit
import CoreGraphics

enum PanelDockingSide: String, CaseIterable {
    /// Tries the left side before falling back to the right side.
    case left
    /// Tries the right side before falling back to the left side.
    case right
}

struct PanelLayout {
    static let gap: CGFloat = 8
    static let defaultWidth: CGFloat = 260
    static let minimumWidth: CGFloat = 180
    static let maximumWidth: CGFloat = 600

    static func frame(
        for windowFrame: CGRect,
        in visibleFrame: CGRect,
        width proposedWidth: CGFloat = defaultWidth,
        preferredSide: PanelDockingSide = .right
    ) -> CGRect {
        let width = clampedWidth(proposedWidth)
        let height = min(windowFrame.height, visibleFrame.height)
        let y = min(
            max(windowFrame.minY, visibleFrame.minY),
            visibleFrame.maxY - height
        )

        let rightX = windowFrame.maxX + gap
        let leftX = windowFrame.minX - width - gap
        let preferredX: CGFloat
        let fallbackX: CGFloat
        switch preferredSide {
        case .left:
            preferredX = leftX
            fallbackX = rightX
        case .right:
            preferredX = rightX
            fallbackX = leftX
        }

        let x: CGFloat
        if preferredX >= visibleFrame.minX,
           preferredX + width <= visibleFrame.maxX {
            x = preferredX
        } else if fallbackX >= visibleFrame.minX,
                  fallbackX + width <= visibleFrame.maxX {
            x = fallbackX
        } else {
            x = min(
                max(windowFrame.maxX - width - gap, visibleFrame.minX),
                visibleFrame.maxX - width
            )
        }

        return CGRect(x: x, y: y, width: width, height: height)
    }

    static func clampedWidth(_ width: CGFloat) -> CGFloat {
        min(max(width, minimumWidth), maximumWidth)
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
