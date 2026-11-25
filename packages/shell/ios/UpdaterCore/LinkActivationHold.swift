import CoreGraphics

enum LinkActivationHold {
  struct Listed: Equatable {
    let number: Int
    let owner: Int32
    let layer: Int
    var windowServer = false
  }

  static let overlayLayer = Int(CGWindowLevelForKey(.draggingWindow))

  static func underPointer(frontToBack list: [Listed], clickedBelow: (Int) -> Int) -> Listed? {
    var below = 0
    for _ in 0...list.count {
      let number = clickedBelow(below)
      guard number > 0, number != below, let hit = list.first(where: { $0.number == number }) else { return nil }
      if !hit.windowServer && (0..<overlayLayer).contains(hit.layer) { return hit }
      below = number
    }
    return nil
  }

  static func leftToWindowManager(own: Int32, windowManagers: Set<Int32>, frontToBack list: [Listed], clickedBelow: (Int) -> Int) -> Bool {
    guard !list.isEmpty else { return true }
    guard let hit = underPointer(frontToBack: list, clickedBelow: clickedBelow) else { return false }
    if windowManagers.contains(hit.owner) { return true }
    return hit.owner == own && list.first { $0.layer == 0 } == hit
  }
}
