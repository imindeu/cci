//
//  PreludeTests.swift
//  APIModels
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import XCTest

class PreludeTests: XCTestCase {
    
    func testEither() {
        XCTAssertEqual(Either<Int, String>.left(1).either(String.init, id), "1")
        XCTAssertEqual(Either<Int, String>.right("x").either(String.init, id), "x")
    }
    
    func testLeft() {
        XCTAssertEqual(Either<Int, String>.left(1).left, 1)
        XCTAssertNil(Either<Int, String>.right("x").left)
    }
    
    func testRight() {
        XCTAssertNil(Either<Int, String>.left(1).right)
        XCTAssertEqual(Either<Int, String>.right("x").right ,"x")
    }

    func testIsLeft() {
        XCTAssertTrue(Either<Int, String>.left(1).isLeft)
        XCTAssertFalse(Either<Int, String>.right("x").isLeft)
    }

    func testIsRight() {
        XCTAssertFalse(Either<Int, String>.left(1).isRight)
        XCTAssertTrue(Either<Int, String>.right("x").isRight)
    }
    
    func testMap() {
        XCTAssertEqual(Either<Int, String>.left(1).map { $0 + "x" }.left, 1)
        XCTAssertEqual(Either<Int, String>.right("x").map { $0 + "x" }.right, "xx")
    }
    
    func testFlatMap() {
        XCTAssertEqual(Either<Int, String>.left(1).flatMap(const(Either<Int, Int>.right(2))).left, 1)
        XCTAssertEqual(Either<Int, String>.right("x").flatMap { Either<Int, Int>.right($0.count) }.right, 1)
    }

}
