//
// HTMLTable.swift
//
// Copyright (c) 2015 Mathias Koehnke (http://www.mathiaskoehnke.de)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

import Foundation

/// HTML Table class representing the <table> element in the DOM.
public class HTMLTable: HTMLElement, @unchecked Sendable {

    /// The CSS tag name for this element type.
    public override class var cssTagName: String {
        return "table"
    }

    /// Returns all row elements within this table.
    public var rows: [HTMLTableRow]? {
        let rows: [HTMLTableRow]? = children()
        return (rows?.first?.tagName == "tbody") ? rows?.first?.children() : rows
    }
}

/// HTML Table Row class representing the <tr> element in the DOM.
public class HTMLTableRow: HTMLElement, @unchecked Sendable {

    /// The CSS tag name for this element type.
    public override class var cssTagName: String {
        return "tr"
    }

    /// Returns all columns within this row.
    public var columns: [HTMLTableColumn]? {
        return children()
    }
}

/// HTML Table Column class representing the <td> element in the DOM.
public class HTMLTableColumn: HTMLElement, @unchecked Sendable {

    /// The CSS tag name for this element type.
    public override class var cssTagName: String {
        return "td"
    }
}
