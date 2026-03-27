//
//  HTMLButton.swift
//
//  Created by Mathias Köhnke on 06/04/16.
//  Copyright 2016 Mathias Köhnke. All rights reserved.
//

import Foundation

/// HTML Button class representing the <button> element in the DOM.
public class HTMLButton: HTMLRedirectable, @unchecked Sendable {

    /// The CSS tag name for this element type.
    public override class var cssTagName: String {
        return "button"
    }
}
