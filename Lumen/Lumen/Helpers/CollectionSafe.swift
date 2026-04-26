import Foundation

extension Collection {
    /// out-of-bounds index에 nil을 돌려주는 안전 subscript.
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
