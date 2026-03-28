import Foundation

/// HTML `<a>` element.
public class HTMLLink: HTMLElement, @unchecked Sendable {
    public override class var cssTagName: String { "a" }

    /// The href attribute value.
    public var href: String? { objectForKey("href") }
}
