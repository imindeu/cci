import XCTest
@testable import AppTests

extension CircleciTests {
  static var allTests: [(String, (CircleciTests) -> () throws -> Void)] = [
    ("testTestJobRequest", testTestJobRequest),
    ("testDeployJobRequest", testDeployJobRequest)
  ]
}

extension CommandTests {
  static var allTests: [(String, (CommandTests) -> () throws -> Void)] = [
    ("testTestCommand", testTestCommand),
    ("testDeployCommand", testDeployCommand),
    ("testHelpCommand", testHelpCommand),
    ("testTestHelpCommand", testTestHelpCommand),
    ("testDeployHelpCommand", testDeployHelpCommand),
    ("testNoChannel", testNoChannel),
    ("testUnknownCommand", testUnknownCommand)
  ]
}

extension RouterTests {
  static var allTests: [(String, (RouterTests) -> () throws -> Void)] = [
    ("testTestCommandAction", testTestCommandAction),
    ("testDeployCommandAction", testDeployCommandAction),
    ("testHelpCommandAction", testHelpCommandAction),
    ("testTestHelpCommandAction", testTestHelpCommandAction),
    ("testDeployHelpCommandAction", testDeployHelpCommandAction),
    ("testErrorCommandAction", testErrorCommandAction)
  ]
}
