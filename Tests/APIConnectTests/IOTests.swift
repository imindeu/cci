//
//  IOTests.swift
//  APIConnectTests
//
//  Created by Peter Geszten-Kovacs on 2018. 12. 01..
//

import APIConnect
import XCTest
import NIO

class IOTests: XCTestCase {
    
    private let context = MultiThreadedEventLoopGroup(numberOfThreads: 1)

    func testPure() throws {
        XCTAssertEqual(try pure(1, context).wait(), 1)
    }
    
    func testMapEither() throws {
        XCTAssertEqual(
            try pure(Either<Int, String>.left(1), context)
                .mapEither(String.init, id).wait(),
            "1")
        XCTAssertEqual(
            try pure(Either<Int, String>.right("x"), context)
                .mapEither(String.init, id).wait(),
            "x")
    }
}
