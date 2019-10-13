#if os(Linux)
  import Glibc
#else
  import Darwin.C
#endif

/**
 Protocol for types that could produce `Regex`
 */
public protocol RegexConvertible {
  var regex: Regex? { get }
}

/**
 POSIX Regular Expression.
 */
public final class Regex {
  /// Specifies the structure to receive the compiled output of the regcomp.
  var compiledPattern = regex_t()

  /**
   Creates a new regular expression

   - Parameter pattern: Regular expression to be compiled by the regcomp.
   - Parameter flags: Bitwise inclusive OR of 0 or more flags for the regcomp.

   - Throws: Regular expression compilation error.
   */
  public init(_ pattern: String, flags: CFlags = .extended) throws {
    let result = regcomp(&compiledPattern, pattern, flags.rawValue)

    guard result == 0 else {
      throw RexyError(result: result, compiledPattern: compiledPattern)
    }
  }

  /// Destroys compiled pattern.
  deinit {
    regfree(&compiledPattern)
  }

  // MARK: - Match

  /**
   Checks if a given string matches regular expression.

   - Parameter source: The string to search for a match.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: True if a match is found.
   */
  public func isMatch(_ source: String, flags: EFlags = []) -> Bool {
    return !matches(source, count: 1, startAt: 0, max: 1, flags: flags).isEmpty
  }

  /**
   Searches an input string for a substring that matches a regular expression
   and returns the first occurrence.

   - Parameter source: The string to search for a match.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: The found matches.
   */
  public func match(_ source: String, flags: EFlags = []) -> Substring? {
    let results = matches(source, count: 1, startAt: 0, max: 1, flags: flags)

    guard !results.isEmpty else {
      return nil
    }

    return results[0]
  }

  /**
   Searches an input string for all occurrences of a regular expression and returns the matches.

   - Parameter source: The string to search for a match.
   - Parameter maxMatches: The maximum matches count.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: The found matches.
   */
  public func matches(_ source: String, maxMatches: Int = Int.max, flags: EFlags = []) -> [Substring] {
    return matches(source, count: 1, startAt: 0, max: maxMatches, flags: flags)
  }

  // MARK: - Group

  /**
   Matches and captures groups.

   - Parameter source: The string to search for a match.
   - Parameter maxGroups: The maximum groups count.
   - Parameter maxMatches: The maximum matches count.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: Found groups.
   */
  public func groups(_ source: String,
                     maxGroups: Int = 10,
                     maxMatches: Int = Int.max,
                     flags: EFlags = []) -> [Substring] {
    return matches(source, count: maxGroups, startAt: 1, max: maxMatches, flags: flags)
  }

  // MARK: - Replace

  /**
   Replaces all strings that match a regular expression pattern
   with a specified replacement string.

   - Parameter source: The string to search for a match.
   - Parameter replacement: The replacement string.
   - Parameter maxMatches: The maximum matches count.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: A new string where replacement string takes the place of each matched string.
   */
  public func replace(_ source: String,
                      with replacement: String,
                      maxMatches: Int = Int.max,
                      flags: EFlags = []) -> String {
    var string = source
    var output: String = ""

    for _ in 0 ..< maxMatches {
      var elements = [regmatch_t](repeating: regmatch_t(), count: 1)
      let result = regexec(&compiledPattern, string, elements.count, &elements, flags.rawValue)

      guard result == 0 else {
        break
      }

      let start = Int(elements[0].rm_so)
      let end = Int(elements[0].rm_eo)
      let startIndex = string.utf8.index(string.utf8.startIndex, offsetBy: end)
      let endIndex = string.utf8.endIndex
      var stringBytes = [UInt8](string.utf8)
      let replacementBytes = [UInt8](replacement.utf8)
      let replacedOffset = replacement.utf8.count + start

      stringBytes.replaceSubrange(start ..< end, with: replacementBytes)

      var replaced = stringBytes.reduce("") {
        $0 + String(UnicodeScalar($1))
      }

      let replacedEndIndex = replaced.utf8.index(replaced.utf8.startIndex, offsetBy: replacedOffset)

      replaced = String(replaced.utf8[replaced.utf8.startIndex ..< replacedEndIndex])!
      output += replaced
      string = String(string.utf8[startIndex ..< endIndex])!
    }

    return output + string
  }

  /**
   Searches an input string for all occurrences of a regular expression and returns the matches.

   - Parameter source: The string to search for a match.
   - Parameter count: The maximum elements count.
   - Parameter startAt: The start index.
   - Parameter max: The maximum matches count.
   - Parameter flags: Flags controlling the behavior of the regexec.

   - Returns: The found matches.
   */
  private func matches(_ source: String,
                       count: Int = 1,
                       startAt index: Int = 0,
                       max: Int = Int.max,
                       flags: EFlags = []) -> [Substring] {
    var string = Substring(source)
    var results = [Substring]()

    for _ in 0 ..< max {
      var elements = [regmatch_t](repeating: regmatch_t(), count: count)
      let result = regexec(&compiledPattern, String(string), elements.count, &elements, flags.rawValue)

      guard result == 0 else {
        break
      }

      let utf8 = string.utf8
      for element in elements[index ..< elements.count] where element.rm_so != -1 {
        let startIndex = utf8.index(utf8.startIndex, offsetBy: Int(element.rm_so)).samePosition(in: source)!
        let endIndex = utf8.index(utf8.startIndex, offsetBy: Int(element.rm_eo)).samePosition(in: source)!
        let result = string[startIndex ..< endIndex]

        results.append(result)
      }

      let startIndex = utf8.index(utf8.startIndex, offsetBy: Int(elements[0].rm_eo)).samePosition(in: source)!
      let range: Range<String.Index> = startIndex ..< source.endIndex
      string = source[range]
    }

    return results
  }
}

// MARK: - RegexConvertible

extension Regex: RegexConvertible {
  public var regex: Regex? {
    return self
  }
}
