#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

public extension Regex {
  /**
   Flags used to determine the type of compilation (cflag).
   */
  public struct CFlags: OptionSet {
    /// Raw value.
    public let rawValue: Int32

    /**
     Creates a new cflag.

     - Parameter rawValue: The value.
     */
    public init(rawValue: Int32) {
      self.rawValue = rawValue
    }

    /// Default options
    public static let regular = [extended]

    // No options
    public static let none = [CFlags]()

    /// Use POSIX Basic Regular Expression syntax.
    public static let basic = CFlags(rawValue: 0)

    /// Use POSIX Extended Regular Expression syntax.
    public static let extended = CFlags(rawValue: 1)

    /// Do not differentiate case.
    public static let caseInsensitive = CFlags(rawValue: 2)

    /// Do not report position of matches.
    public static let ignorePositions = CFlags(rawValue: 3)

    // Newline-sensitive matching.
    public static let newLineSensitive = CFlags(rawValue: 4)

    /// Ignore special characters.
    public static let ignoreSpecialCharacters = CFlags(rawValue: 5)

    /// Interpret the entire regex argument as a literal string.
    public static let literal = CFlags(rawValue: 6)

    /// Point to the end of the expression to compile.
    public static let endPointer = CFlags(rawValue: 7)

    /// Compile using minimal repetition.
    public static let minimal = CFlags(rawValue: 8)

    /// Make the operators non-greedy by default and greedy when a ? is specified.
    public static let nonGreedy = CFlags(rawValue: 9)
  }
}
