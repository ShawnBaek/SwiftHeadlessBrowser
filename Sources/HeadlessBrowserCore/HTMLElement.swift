import Foundation

/// Base class for all HTML elements.
public class HTMLElement: HTMLParserElement, @unchecked Sendable {
    public class var cssTagName: String { "*" }
}
