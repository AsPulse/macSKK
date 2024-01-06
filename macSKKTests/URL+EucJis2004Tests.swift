// SPDX-FileCopyrightText: 2024 mtgto <hogerappa@gmail.com>
// SPDX-License-Identifier: GPL-3.0-or-later

import XCTest

@testable import macSKK

final class URLEucJis2004Tests: XCTestCase {
    func testLoad() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "euc-jis-2004", withExtension: "txt")!
        XCTAssertEqual(try fileURL.eucJis2004String(), "川﨑")
    }

    func testLoadFail() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "SKK-JISYO.test", withExtension: "utf8")!
        XCTAssertThrowsError(try fileURL.eucJis2004String()) {
            XCTAssertEqual($0 as! EucJis2004Error, EucJis2004Error.convert)
        }
    }

    func testLoadEmpty() throws {
        let fileURL = Bundle(for: Self.self).url(forResource: "empty", withExtension: "txt")!
        XCTAssertEqual(try fileURL.eucJis2004String(), "")
    }
}
