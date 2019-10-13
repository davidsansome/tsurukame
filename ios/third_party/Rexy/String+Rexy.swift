// MARK: - RegexConvertible

extension String: RegexConvertible {
  public var regex: Regex? {
    return try? Regex(self)
  }
}

// MARK: - Operators

infix operator =~ : ComparisonPrecedence
infix operator !~ : ComparisonPrecedence

public func =~ (source: String, pattern: RegexConvertible?) -> Bool {
  guard let matches = pattern?.regex?.isMatch(source) else {
    return false
  }

  return matches
}

public func !~ (source: String, pattern: RegexConvertible?) -> Bool {
  return !(source =~ pattern)
}
