import CoreGraphics
import XCTest
@testable import ArdiaUpdaterCore

final class LinkActivationHoldTests: XCTestCase {
  private let own: Int32 = 100
  private let linkSource: Int32 = 200
  private let dock: Int32 = 300
  private let stageManager: Int32 = 400
  private let windowServer: Int32 = 500
  private let notificationCenter: Int32 = 600
  private var managers: Set<Int32> { [dock, stageManager] }
  private let pointer = CGPoint(x: 500, y: 400)
  private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
  private let dockBar = CGRect(x: 400, y: 900, width: 700, height: 80)

  private struct Placed {
    let listed: LinkActivationHold.Listed
    let clickable: CGRect?
  }

  private var nextNumber = 1

  private func window(_ owner: Int32, layer: Int = 0, clickable: CGRect?) -> Placed {
    nextNumber += 1
    return Placed(listed: LinkActivationHold.Listed(number: nextNumber, owner: owner, layer: layer, windowServer: owner == windowServer), clickable: clickable)
  }

  private func cursor() -> Placed {
    window(windowServer, layer: Int(CGWindowLevelForKey(.cursorWindow)), clickable: CGRect(x: pointer.x - 8, y: pointer.y - 8, width: 32, height: 32))
  }

  private func visibleDock() -> Placed {
    window(dock, layer: Int(CGWindowLevelForKey(.dockWindow)), clickable: dockBar)
  }

  private func clickedBelow(_ scene: [Placed], at point: CGPoint) -> (Int) -> Int {
    { below in
      let start = below == 0 ? 0 : (scene.firstIndex { $0.listed.number == below }.map { $0 + 1 } ?? scene.count)
      return scene[start...].first { $0.clickable?.contains(point) == true }?.listed.number ?? 0
    }
  }

  private func left(_ scene: [Placed], at point: CGPoint? = nil) -> Bool {
    LinkActivationHold.leftToWindowManager(
      own: own, windowManagers: managers, frontToBack: scene.map(\.listed), clickedBelow: clickedBelow(scene, at: point ?? pointer))
  }

  func testALinkClickedInAnotherAppHoldsWhileTheDockIsShown() {
    let scene = [
      visibleDock(),
      window(linkSource, clickable: CGRect(x: 0, y: 33, width: 1512, height: 859)),
      window(own, clickable: CGRect(x: 0, y: 33, width: 1512, height: 859)),
    ]
    XCTAssertFalse(left(scene))
  }

  func testAFullScreenNotificationCenterWindowThatTakesNoClicksIsLookedThrough() {
    let scene = [
      window(notificationCenter, layer: 23, clickable: nil),
      visibleDock(),
      window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700)),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
    ]
    XCTAssertFalse(left(scene))
  }

  func testALinkOpenedWithThePointerOnTheDockBarIsLeftToTheDock() {
    let scene = [visibleDock(), window(linkSource, clickable: screen), window(own, clickable: screen)]
    XCTAssertTrue(left(scene, at: CGPoint(x: 700, y: 940)))
  }

  func testAClickInMissionControlIsLeftToTheDock() {
    let scene = [
      window(dock, layer: 20, clickable: screen),
      window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700)),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
    ]
    XCTAssertTrue(left(scene))
  }

  func testARecordedCursorAboveMissionControlStillLeavesItToTheDock() {
    let scene = [cursor(), window(dock, layer: 20, clickable: screen), window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700))]
    XCTAssertTrue(left(scene))
  }

  func testARecordedCursorAboveTheLinkAppStillHolds() {
    let scene = [
      cursor(),
      visibleDock(),
      window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700)),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
    ]
    XCTAssertFalse(left(scene))
  }

  func testOverlaysAboveEverythingAreLookedThrough() {
    let scene = [
      window(notificationCenter, layer: Int(CGWindowLevelForKey(.assistiveTechHighWindow)), clickable: CGRect(x: 300, y: 200, width: 400, height: 400)),
      window(linkSource, layer: Int(CGWindowLevelForKey(.draggingWindow)), clickable: CGRect(x: 480, y: 380, width: 64, height: 64)),
      window(windowServer, layer: 25, clickable: CGRect(x: 0, y: 380, width: 1512, height: 40)),
      window(dock, layer: 20, clickable: screen),
    ]
    XCTAssertEqual(
      LinkActivationHold.underPointer(frontToBack: scene.map(\.listed), clickedBelow: clickedBelow(scene, at: pointer))?.owner, dock)
  }

  func testAWindowMissionControlAlreadyPutInFrontUnderThePointerIsLeftAlone() {
    let scene = [
      visibleDock(),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
      window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700)),
    ]
    XCTAssertTrue(left(scene))
  }

  func testAStageManagerStripClickIsLeftToStageManager() {
    let scene = [
      window(stageManager, clickable: CGRect(x: 0, y: 200, width: 180, height: 500)),
      window(linkSource, clickable: CGRect(x: 200, y: 100, width: 900, height: 700)),
    ]
    XCTAssertTrue(left(scene, at: CGPoint(x: 90, y: 400)))
  }

  func testAPointerRestingOnArdiaBehindTheAppInFrontKeepsTheHold() {
    let scene = [
      visibleDock(),
      window(linkSource, clickable: CGRect(x: 0, y: 0, width: 600, height: 900)),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
    ]
    XCTAssertFalse(left(scene, at: CGPoint(x: 900, y: 400)))
  }

  func testAnotherArdiaWindowBehindTheAppInFrontKeepsTheHoldEvenWhenOneArdiaWindowIsFrontmost() {
    let scene = [
      window(own, clickable: CGRect(x: 1200, y: 0, width: 300, height: 300)),
      window(linkSource, clickable: CGRect(x: 0, y: 0, width: 600, height: 900)),
      window(own, clickable: CGRect(x: 300, y: 80, width: 1100, height: 800)),
    ]
    XCTAssertFalse(left(scene, at: CGPoint(x: 900, y: 400)))
  }

  func testAPointerOverNoWindowKeepsTheHold() {
    let scene = [visibleDock(), window(linkSource, clickable: CGRect(x: 100, y: 100, width: 300, height: 300))]
    XCTAssertFalse(left(scene, at: CGPoint(x: 900, y: 700)))
  }

  func testAWindowTheListDoesNotKnowKeepsTheHold() {
    let scene = [window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700))]
    XCTAssertFalse(
      LinkActivationHold.leftToWindowManager(own: own, windowManagers: managers, frontToBack: scene.map(\.listed)) { _ in 9999 })
  }

  func testAHitTestThatRepeatsItselfEnds() {
    let scene = [window(windowServer, layer: 25, clickable: screen)]
    let number = scene[0].listed.number
    XCTAssertNil(LinkActivationHold.underPointer(frontToBack: scene.map(\.listed)) { _ in number })
  }

  func testAnEmptyWindowListHoldsNothing() {
    XCTAssertTrue(LinkActivationHold.leftToWindowManager(own: own, windowManagers: managers, frontToBack: []) { _ in 0 })
  }

  func testWindowsBelowTheNormalLayerAreSkipped() {
    let scene = [
      window(dock, layer: -2147483623, clickable: screen),
      window(linkSource, clickable: CGRect(x: 100, y: 100, width: 900, height: 700)),
    ]
    XCTAssertEqual(
      LinkActivationHold.underPointer(frontToBack: scene.map(\.listed), clickedBelow: clickedBelow(scene, at: pointer))?.owner, linkSource)
  }
}
