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

    func testPure() throws {
        XCTAssertEqual(try pure(1, MultiThreadedEventLoopGroup(numberOfThreads: 1)).wait(), 1)
    }
    
    func testMapEither() throws {
        XCTAssertEqual(
            try pure(Either<Int, String>.left(1),
                     MultiThreadedEventLoopGroup(numberOfThreads: 1))
                .mapEither(String.init, id).wait(),
            "1")
        XCTAssertEqual(
            try pure(Either<Int, String>.right("x"),
                     MultiThreadedEventLoopGroup(numberOfThreads: 1))
                .mapEither(String.init, id).wait(),
            "x")
    }
}
