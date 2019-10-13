#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

public extension Regex {
  /**
   POSIX regex matching flags (eflag).
   */
  public struct EFlags: OptionSet {
    /// Raw value.
    public let rawValue: Int32

    /**
     Creates a new eflag.

     - Parameter rawValue: The value
     */
    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    /// First character not at beginning of line.
    public static let notBeginningOfLine = EFlags(rawValue: 1)

    /// Last character not at end of line.
    public static let notEndOfLine = EFlags(rawValue: 2)

    /// String start/end in pmatch[0].
    public static let startEnd = EFlags(rawValue: 4)
  }
}
