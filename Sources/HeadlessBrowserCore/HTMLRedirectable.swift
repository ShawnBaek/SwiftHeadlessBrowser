//
//  HTMLRedirectable.swift
//
//  Created by Mathias Köhnke on 06/04/16.
//  Copyright 2016 Mathias Köhnke. All rights reserved.
//

import Foundation

/// Base class for redirectable HTML elements (e.g. HTMLLink, HTMLButton).
public class HTMLRedirectable: HTMLElement, @unchecked Sendable {

    // MARK: - Initializer

    public required init?(element: Any, cssQuery: String? = nil) {
        super.init(element: element, cssQuery: cssQuery)
    }

    // MARK: - Redirect Script

    /// Returns a JavaScript action script for this element.
    public func actionScript() -> String? {
        if let onClick = objectForKey("onclick") {
            return onClick
        }
        return nil
    }
}
