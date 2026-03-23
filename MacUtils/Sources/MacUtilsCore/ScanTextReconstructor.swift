import Foundation
#if canImport(CoreGraphics)
import CoreGraphics
#endif

// MARK: - Scan OCR Core Logic

/// Represents a recognized text observation with bounding box info
public struct TextObservation: Equatable {
    public let text: String
    public let boundingBox: CGRect  // Normalized coordinates (0-1)
    public let confidence: Float

    public init(text: String, boundingBox: CGRect, confidence: Float = 1.0) {
        self.text = text
        self.boundingBox = boundingBox
        self.confidence = confidence
    }
}

/// Reconstructs indented text from OCR text observations.
/// Uses the x-position of bounding boxes to determine relative indentation.
public struct ScanTextReconstructor {

    /// Average character width in pixels for indentation calculation (monospace assumption)
    public let averageCharWidth: CGFloat

    public init(averageCharWidth: CGFloat = 8.0) {
        self.averageCharWidth = averageCharWidth
    }

    /// Reconstruct text from observations, preserving indentation based on x-positions.
    /// Observations should be in reading order (top to bottom, left to right).
    /// Bounding boxes are in image coordinates (origin at top-left).
    ///
    /// - Parameter observations: Array of text observations from VNRecognizeTextRequest
    /// - Returns: Reconstructed text with indentation preserved
    public func reconstruct(observations: [TextObservation]) -> String {
        guard !observations.isEmpty else { return "" }

        // 1. Sort by Y descending (top to bottom)
        let sortedDescY = observations.sorted { $0.boundingBox.origin.y > $1.boundingBox.origin.y }

        // 2. Group into lines based on Y-overlap or proximity
        var lineGroups: [[TextObservation]] = []
        var currentLine: [TextObservation] = []

        for obs in sortedDescY {
            if let last = currentLine.last {
                let yDiff = abs(obs.boundingBox.origin.y - last.boundingBox.origin.y)
                let heightTolerance = max(obs.boundingBox.height, last.boundingBox.height) * 0.4
                
                if yDiff <= heightTolerance {
                    currentLine.append(obs)
                } else {
                    lineGroups.append(currentLine)
                    currentLine = [obs]
                }
            } else {
                currentLine.append(obs)
            }
        }
        if !currentLine.isEmpty {
            lineGroups.append(currentLine)
        }

        // 3. Reconstruct text with horizontal and vertical spacing
        let minX = observations.map { $0.boundingBox.origin.x }.min() ?? 0
        var resultText = ""
        
        var previousLineY: CGFloat? = nil
        var previousLineHeight: CGFloat = 0

        for line in lineGroups {
            // Sort line logically left-to-right
            let sortedLine = line.sorted { $0.boundingBox.origin.x < $1.boundingBox.origin.x }
            
            let currentLineY = sortedLine[0].boundingBox.origin.y
            let currentLineHeight = sortedLine[0].boundingBox.height
            
            // Vertical Spacing (Blank Lines)
            if let prevY = previousLineY {
                let gap = prevY - currentLineY
                let avgHeight = (previousLineHeight + currentLineHeight) / 2.0
                
                if avgHeight > 0 {
                    let blankLines = Int((gap / avgHeight) - 1.2)
                    if blankLines > 0 {
                        resultText += String(repeating: "\n", count: min(blankLines, 4))
                    }
                }
            }
            
            // Horizontal Spacing
            var lineString = ""
            var currentCursorX = minX
            
            for obs in sortedLine {
                let xOffset = obs.boundingBox.origin.x - currentCursorX
                let spaceCount = max(0, Int(xOffset / averageCharWidth))
                
                if spaceCount > 0 {
                    lineString += String(repeating: " ", count: spaceCount)
                } else if !lineString.isEmpty {
                    lineString += " " // Ensure at least 1 separating space between distinct boxes on same line
                }
                
                lineString += obs.text
                currentCursorX = obs.boundingBox.origin.x + obs.boundingBox.width
            }
            
            if !resultText.isEmpty {
                resultText += "\n"
            }
            resultText += lineString
            
            previousLineY = currentLineY
            previousLineHeight = currentLineHeight
        }

        return resultText
    }

    /// Reconstruct from observations using normalized coordinates (0-1 range)
    /// multiplied by the image width to get pixel positions.
    public func reconstructFromNormalized(observations: [TextObservation], imageWidth: CGFloat) -> String {
        let pixelObservations = observations.map { obs in
            TextObservation(
                text: obs.text,
                boundingBox: CGRect(
                    x: obs.boundingBox.origin.x * imageWidth,
                    y: obs.boundingBox.origin.y,
                    width: obs.boundingBox.width * imageWidth,
                    height: obs.boundingBox.height
                ),
                confidence: obs.confidence
            )
        }
        return reconstruct(observations: pixelObservations)
    }
}
