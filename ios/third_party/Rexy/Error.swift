#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

/**
 Representation of Regular Expression error.
 */
public struct RexyError: Error, CustomStringConvertible {
  /// Error description.
  public let description: String

  /**
   Creates a new regex error.

   - Parameter result: Compiled result.
   - Parameter compiledPattern: Compiled regex pattern.
   */
  public init(result: Int32, compiledPattern: regex_t) {
    var compiled = compiledPattern
    var buffer = [Int8](repeating: 0, count: 1024)

    regerror(result, &compiled, &buffer, buffer.count)
    description = String(cString: buffer) 
  }
}
