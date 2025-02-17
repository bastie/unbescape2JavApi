/*
 * =============================================================================
 * 
 *   Licensed under the Apache License, Version 2.0 (the "License");
 *   you may not use this file except in compliance with the License.
 *   You may obtain a copy of the License at
 * 
 *       http://www.apache.org/licenses/LICENSE-2.0
 * 
 *   Unless required by applicable law or agreed to in writing, software
 *   distributed under the License is distributed on an "AS IS" BASIS,
 *   WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 *   See the License for the specific language governing permissions and
 *   limitations under the License.
 * 
 * =============================================================================
 */

import JavApi

/**
 * <p>
 *   Internal class in charge of performing the real escape/unescape operations.
 * </p>
 *
 * @author Daniel Fern&aacute;ndez
 *
 * @since 1.0.0
 *
 */
final class JavaEscapeUtil {
  
  /*
   * JAVA ESCAPE/UNESCAPE OPERATIONS
   * -------------------------------
   *
   *   See: http://docs.oracle.com/javase/specs/jls/se7/html/jls-3.html
   *        http://arity23.blogspot.com.es/2013/04/secrets-of-scala-lexer-1-uuuuunicode.html
   *
   *   (Note that, in the following examples, and in order to avoid escape problems during the compilation
   *    of this class, the backslash symbol is replaced by '%')
   *
   *   - SINGLE ESCAPE CHARACTERS (SECs):
   *        U+0008 -> %b
   *        U+0009 -> %t
   *        U+000A -> %n
   *        U+000C -> %f
   *        U+000D -> %r
   *        U+0022 -> %"
   *        U+0027 -> %' [ NOT USED IN ESCAPE OF STRINGS IF LEVEL < 3 ]
   *        U+005C -> %%
   *   - UNICODE ESCAPE [UHEXA]
   *        Characters <= U+FFFF: %u????
   *        Characters > U+FFFF : %u????%u???? (surrogate character pair)
   *   - OCTAL ESCAPE: %377 [NOT USED IN ESCAPE - Use is not recommended by the JLS, exists for C compatibility]
   *
   *
   *   ------------------------
   *
   *   NOTE: The way Unicode Escapes work in Java is different to other languages like e.g. JavaScript. In Java,
   *         these UHEXA escapes are processed by the compiler itself, and therefore resolved before any other
   *         type of escapes. Besides, UHEXA escapes can appear anywhere in the code, not only String literals.
   *         This means that, while in JavaScript 'a\u005Cna' would be displayed as 'a\na', in Java "a\u005Cna"
   *         would in fact be displayed in two lines: 'a'+LF+'a'.
   *         Going even further, this is perfectly valid Java code:
   *
   *             final String hello = \u0022Hello, World!\u0022;
   *
   *         Also, Java allows to write any number of 'u' characters in this type of escapes, like \uu00E1 or even
   *         \uuuuuuuuu00E1. This is so in order to enable legacy compatibility with older code-processing tools
   *         that didn't support Unicode processing at all, which would fail when finding an Unicode escape
   *         like \u00E1, but not \uu00E1 (because they would consider backslash+'u' as the escape).
   *         So yes, this is valid Java code too:
   *
   *             final String hello = \uuuuuuuu0022Hello, World!\u0022;
   *
   *         In order to correctly unescape Java UHEXA escapes like "a\u005Cna", Unbescape will perform a two-pass
   *         process so that all unicode escapes are processed in the first pass, and then the single escape
   *         characters and octal escapes in the second pass.
   *
   *   ------------------------
   *
   *   NOTE: Unbescape does not define a 'type' for Java escaping (just a level) because, given what's explained
   *         above about Unicode Escapes, there is not the possibility to choose whether we want to escape, for
   *         example, '\t' (U+0009) as a SEC ('\t') or as a Unicode Escape ('\u0009'). Given Unicode Escapes are
   *         processed by the compiler, using it instead of the SEC would really insert a tab character inside our
   *         source code, which is not equivalent to the '\t' syntax (and might be actually invalid).
   *
   *   ------------------------
   *
   */
  
  /*
   * Prefixes defined for use in escape and unescape operations
   */
  private static let ESCAPE_PREFIX : Character = "\\"
  private static let ESCAPE_UHEXA_PREFIX2 : Character = "u"
  private static let ESCAPE_UHEXA_PREFIX = "\\u".toCharArray();
  
  /*
   * Small utility char arrays for hexadecimal conversion.
   */
  private static let HEXA_CHARS_UPPER = "0123456789ABCDEF".toCharArray();
  private static let HEXA_CHARS_LOWER = "0123456789abcdef".toCharArray();
  
  /*
   * Structures for holding the Single Escape Characters
   */
  private static let SEC_CHARS_LEN : Int = 0x5D //'\\' + 1; // 0x5C + 1 = 0x5D
  private static let SEC_CHARS_NO_SEC : Character = "*"
  private static let SEC_CHARS : [Character] = {
    /*
     * Initialize Single Escape Characters
     */
    //SEC_CHARS = new char[SEC_CHARS_LEN];
    //Arrays.fill(SEC_CHARS,SEC_CHARS_NO_SEC);
    var _SEC_CHARS = Array(repeating: SEC_CHARS_NO_SEC, count: SEC_CHARS_LEN)
    _SEC_CHARS[0x08] = "b"
    _SEC_CHARS[0x09] = "t"
    _SEC_CHARS[0x0A] = "n"
    _SEC_CHARS[0x0C] = "f"
    _SEC_CHARS[0x0D] = "r"
    _SEC_CHARS[0x22] = "\""
    // Escaping the apostrophe is only required in character literals, but we are escaping
    // string literals, so we don't really need this escape if level < 3
    _SEC_CHARS[0x27] = "'";
    _SEC_CHARS[0x5C] = "\\";
    return _SEC_CHARS
  }()
  
  /*
   * Structured for holding the 'escape level' assigned to chars (not codepoints) up to ESCAPE_LEVELS_LEN.
   * - The last position of the ESCAPE_LEVELS array will be used for determining the level of all
   *   codepoints >= (ESCAPE_LEVELS_LEN - 1)
   */
  private static let ESCAPE_LEVELS_LEN = Character (Int (0x9f + 2)) // Last relevant char to be indexed is 0x9f
  private static let ESCAPE_LEVELS : [UInt8] = {
    /*
     * Initialization of escape levels.
     * Defined levels :
     *
     *    - Level 1 : Basic escape set
     *    - Level 2 : Basic escape set plus all non-ASCII
     *    - Level 3 : All non-alphanumeric characters
     *    - Level 4 : All characters
     *
     */
    var _ESCAPE_LEVELS : [UInt8] = Array(repeating: UInt8(3), count: Int(ESCAPE_LEVELS_LEN))
    
    /*
     * Everything is level 3 unless contrary indication.
     */
    //java.util.Arrays.fill(ESCAPE_LEVELS, UInt8(3))
    
    /*
     * Everything non-ASCII is level 2 unless contrary indication.
     */
    for c in 0x80..<Int(ESCAPE_LEVELS_LEN) {
      _ESCAPE_LEVELS[c] = 2;
    }
    
    /*
     * Alphanumeric characters are level 4.
     */
    for c in Int(Character("A"))...Int(Character("Z")) {
      _ESCAPE_LEVELS[c] = 4;
    }
    for c in Int(Character("a"))...Int(Character("z")) {
      _ESCAPE_LEVELS[c] = 4;
    }
    for c  in Int(Character("0"))...Int(Character("9")) {
      _ESCAPE_LEVELS[c] = 4;
    }
    
    /*
     * Simple Escape Character will be level 1 (always escaped)
     */
    _ESCAPE_LEVELS[0x08] = 1;
    _ESCAPE_LEVELS[0x09] = 1;
    _ESCAPE_LEVELS[0x0A] = 1;
    _ESCAPE_LEVELS[0x0C] = 1;
    _ESCAPE_LEVELS[0x0D] = 1;
    _ESCAPE_LEVELS[0x22] = 1;
    // Escaping the apostrophe is only required in character literals, but we are escaping
    // string literals, so we don't really need this escape if level < 3
    _ESCAPE_LEVELS[0x27] = 3;
    _ESCAPE_LEVELS[0x5C] = 1;
    
    /*
     * Java defines one ranges of non-displayable, control characters: U+0000 to U+001F.
     * Additionally, the U+007F to U+009F range is also escaped (which is allowed).
     */
    for c in 0x00...0x1F {
      _ESCAPE_LEVELS[c] = 1;
    }
    for c in  0x7F...0x9F {
      _ESCAPE_LEVELS[c] = 1;
    }
    return _ESCAPE_LEVELS
  }()
  
  private init() {
  }
  
  static func toUHexa(_ codepoint : Int) -> [Character] {
    var result : [Character] = Array(repeating: "\u{0}", count: 4)
    result[3] = HEXA_CHARS_UPPER[codepoint % 0x10];
    result[2] = HEXA_CHARS_UPPER[(codepoint >>> 4) % 0x10];
    result[1] = HEXA_CHARS_UPPER[(codepoint >>> 8) % 0x10];
    result[0] = HEXA_CHARS_UPPER[(codepoint >>> 12) % 0x10];
    return result;
  }
  
  /*
   * Perform an escape operation, based on String, according to the specified level.
   */
  static func escape(_ text : String, _ escapeLevel : JavaEscapeLevel) throws -> String{
    
    let level = escapeLevel.getEscapeLevel();
    
    var strBuilder : StringBuilder? = nil
    
    let offset : Int = 0;
    let max = text.count
    
    var readOffset = offset;
    
    for var i in offset..<max {
      let codepoint = try Character.codePointAt(text, i);
      
      /*
       * Shortcut: most characters will be ASCII/Alphanumeric, and we won't need to do anything at
       * all for them
       */
      if (codepoint <= (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[codepoint]) {
        continue;
      }
      
      /*
       * Shortcut: we might not want to escape non-ASCII chars at all either.
       */
      if (codepoint > (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[Int(ESCAPE_LEVELS_LEN) - 1]) {
        if (Character.charCount(codepoint) > 1) {
          // This is to compensate that we are actually escaping two char[] positions with a single codepoint.
          i += 1
        }
        continue;
      }
      
      /*
       * At this point we know for sure we will need some kind of escape, so we
       * can increase the offset and initialize the string builder if needed, along with
       * copying to it all the contents pending up to this point.
       */
      if (strBuilder == nil) {
        strBuilder = StringBuilder()//max + 20);
      }
      if (i - readOffset > 0) {
        _ = strBuilder!.append(text, readOffset, i);
      }
      
      if (Character.charCount(codepoint) > 1) {
        // This is to compensate that we are actually reading two char[] positions with a single codepoint.
        i += 1
      }
      
      readOffset = i + 1;
      
      /*
       * -----------------------------------------------------------------------------------------
       *
       * Perform the real escape, attending the different combinations of SECs and UHEXA
       *
       * -----------------------------------------------------------------------------------------
       */
      if (codepoint < SEC_CHARS_LEN) {
        // We will try to use a SEC
        let sec : Character = SEC_CHARS[codepoint];
        
        if (sec != SEC_CHARS_NO_SEC) {
          // SEC found! just write it and go for the next char
          _ = strBuilder!.append(ESCAPE_PREFIX);
          _ = strBuilder!.append(sec);
          continue;
        }
      }
      
      /*
       * No SEC-escape was possible, so we need uhexa escape.
       */
      if (Character.charCount(codepoint) > 1) {
        let codepointChars = try Character.toChars(codepoint);
        _ = strBuilder!.append(ESCAPE_UHEXA_PREFIX);
        _ = strBuilder!.append(toUHexa(Int(codepointChars[0])))
        _ = strBuilder!.append(ESCAPE_UHEXA_PREFIX);
        _ = strBuilder!.append(toUHexa(Int(codepointChars[1])))
        continue;
      }
      
      _ = strBuilder!.append(ESCAPE_UHEXA_PREFIX);
      _ = strBuilder!.append(toUHexa(codepoint));
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: return the original String object if no escape was actually needed. Otherwise
     *                 append the remaining unescaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    
    if (strBuilder == nil) {
      return text;
    }
    
    if (max - readOffset > 0) {
      _ = strBuilder!.append(text, readOffset, max);
    }
    
    return strBuilder!.toString();
  }
  
  /*
   * Perform an escape operation, based on a Reader, according to the specified level and writing the result
   * to a Writer.
   *
   * Note this reader is going to be read char-by-char, so some kind of buffering might be appropriate if this
   * is an inconvenience for the specific Reader implementation.
   */
  static func escape(_ reader : java.io.Reader, _ writer : java.io.Writer, _ escapeLevel : JavaEscapeLevel) throws {
    
    let level = escapeLevel.getEscapeLevel();
    
    var c1 : Int // c0: last char, c1: current char, c2: next char
    var c2 : Int // c0: last char, c1: current char, c2: next char
    
    c2 = try reader.read();
    
    while (c2 >= 0) {
      
      c1 = c2;
      c2 = try reader.read();
      
      let codepoint : Int = codePointAt(Character(c1), Character(c2))
      
      /*
       * Shortcut: most characters will be ASCII/Alphanumeric, and we won't need to do anything at
       * all for them
       */
      if (codepoint <= (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[codepoint]) {
        try writer.write(c1);
        continue;
      }
      
      /*
       * Shortcut: we might not want to escape non-ASCII chars at all either.
       */
      if (codepoint > (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[Int(ESCAPE_LEVELS_LEN) - 1]) {
        try writer.write(c1);
        
        if (Character.charCount(codepoint) > 1) {
          // This is to compensate that we are actually escaping two char[] positions with a single codepoint.
          try writer.write(c2);
          
          c1 = c2;
          c2 = try reader.read();
        }
        continue;
      }
      
      /*
       * We know we need to escape, so from here on we will only work with the codepoint -- we can advance
       * the chars.
       */
      if (Character.charCount(codepoint) > 1) {
        // This is to compensate that we are actually reading two char positions with a single codepoint.
        c1 = c2;
        c2 = try reader.read();
      }

      /*
       * -----------------------------------------------------------------------------------------
       *
       * Perform the real escape, attending the different combinations of SECs and UHEXA
       *
       * -----------------------------------------------------------------------------------------
       */
      if (codepoint < SEC_CHARS_LEN) {
        // We will try to use a SEC
        let sec : Character = SEC_CHARS[codepoint];
        
        if (sec != SEC_CHARS_NO_SEC) {
          // SEC found! just write it and go for the next char
          try writer.write(ESCAPE_PREFIX);
          try writer.write(sec);
          continue;
        }
      }
      
      /*
       * No SEC-escape was possible, so we need uhexa escape.
       */
      if (Character.charCount(codepoint) > 1) {
        let codepointChars = try Character.toChars(codepoint);
        try writer.write(ESCAPE_UHEXA_PREFIX);
        try writer.write(toUHexa(Int(codepointChars[0])))
        try writer.write(ESCAPE_UHEXA_PREFIX);
        try writer.write(toUHexa(Int(codepointChars[1])))
        continue;
      }

      try writer.write(ESCAPE_UHEXA_PREFIX);
      try writer.write(toUHexa(codepoint));
    }
  }
  
  /*
   * Perform an escape operation, based on char[], according to the specified level.
   */
  static func escape(_ text : [Character], _ offset : Int, _ len : Int, _ writer : java.io.Writer, _ escapeLevel : JavaEscapeLevel) throws {
    
    if text.isEmpty {
      return;
    }
    
    let level = escapeLevel.getEscapeLevel();
    let max = (offset + len);
    var readOffset = offset;
    
    for var i in offset..<max {
      let codepoint = try Character.codePointAt(text, i);
            
      /*
       * Shortcut: most characters will be ASCII/Alphanumeric, and we won't need to do anything at
       * all for them
       */
      if (codepoint <= (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[codepoint]) {
        continue;
      }
      
      /*
       * Shortcut: we might not want to escape non-ASCII chars at all either.
       */
      if (codepoint > (Int(ESCAPE_LEVELS_LEN) - 2) && level < ESCAPE_LEVELS[Int(ESCAPE_LEVELS_LEN) - 1]) {
        if (Character.charCount(codepoint) > 1) {
          // This is to compensate that we are actually escaping two char[] positions with a single codepoint.
          i += 1
        }
        continue;
      }
      
      /*
       * At this point we know for sure we will need some kind of escape, so we
       * copy all the contents pending up to this point.
       */
      if (i - readOffset > 0) {
        try writer.write(text, readOffset, (i - readOffset))
      }
      if (Character.charCount(codepoint) > 1) {
        // This is to compensate that we are actually reading two char[] positions with a single codepoint.
        i += 1
      }
      
      readOffset = i + 1;
            
      /*
       * -----------------------------------------------------------------------------------------
       *
       * Perform the real escape, attending the different combinations of SECs and UHEXA
       *
       * -----------------------------------------------------------------------------------------
       */
      if (codepoint < SEC_CHARS_LEN) {
        // We will try to use a SEC
        let sec : Character = SEC_CHARS[codepoint];
        
        if (sec != SEC_CHARS_NO_SEC) {
          // SEC found! just write it and go for the next char
          try writer.write(ESCAPE_PREFIX);
          try writer.write(sec);
          continue;
        }
      }
      
      /*
       * No SEC-escape was possible, so we need uhexa escape.
       */
      if (Character.charCount(codepoint) > 1) {
        let codepointChars = try Character.toChars(codepoint);
        try writer.write(ESCAPE_UHEXA_PREFIX);
        try writer.write(toUHexa(Int(codepointChars[0])))
        try writer.write(ESCAPE_UHEXA_PREFIX);
        try writer.write(toUHexa(Int(codepointChars[1])))
        continue;
      }
      
      try writer.write(ESCAPE_UHEXA_PREFIX);
      try writer.write(toUHexa(codepoint));
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: append the remaining unescaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    if (max - readOffset > 0) {
      try writer.write(text, readOffset, (max - readOffset));
    }
  }
  
  /*
   * This methods (the two versions) are used instead of Integer.parseInt(str,radix) in order to avoid the need
   * to create substrings of the text being unescaped to feed such method.
   * -  No need to check all chars are within the radix limits - reference parsing code will already have done so.
   */
  
  static func parseIntFromReference(_ text : String, _ start : Int, _ end : Int, _ radix : Int) -> Int {
    return parseIntFromReference(text.toCharArray(), start, end, radix)
  }
  
  @inlinable
  static func parseIntFromReference(_ text : [Character], _ start : Int, _ end : Int, _ radix : Int) -> Int {
    var result = 0;
    for i in start..<end {
      let c = text[i];
      var n = -1;
      for  j in 0..<HEXA_CHARS_UPPER.count {
        if (c == HEXA_CHARS_UPPER[j] || c == HEXA_CHARS_LOWER[j]) {
          n = j;
          break;
        }
      }
      result = (radix * result) + n;
    }
    return result;
  }
  
  static func isOctalEscape(_ text : String, _ start : Int, _ end : Int) -> Bool {
    if (start >= end) {
      return false;
    }
    
    let c1 = text.charAt(start);
    if (c1 < "0" || c1 > "7") {
      return false;
    }
    
    if (start + 1 >= end) {
      return (c1 != "0"); // It would not be an octal escape, but the U+0000 escape sequence.
    }
    
    let c2 = text.charAt(start + 1);
    if (c2 < "0" || c2 > "7") {
      return (c1 != "0"); // It would not be an octal escape, but the U+0000 escape sequence.
    }
    
    if (start + 2 >= end) {
      return (c1 != "0" || c2 != "0"); // It would not be an octal escape, but the U+0000 escape sequence + '0'.
    }
    
    let c3 = text.charAt(start + 2);
    if (c3 < "0" || c3 > "7") {
      return (c1 != "0" || c2 != "0"); // It would not be an octal escape, but the U+0000 escape sequence + '0'.
    }
    
    return (c1 != "0" || c2 != "0" || c3 != "0"); // Check it's not U+0000 (escaped) + '00'
  }
  
  static func isOctalEscape(_ text : [Character], _ start : Int, _ end : Int) -> Bool {
    if (start >= end) {
      return false;
    }
    
    let c1 = text[start];
    if (c1 < "0" || c1 > "7") {
      return false;
    }
    
    if (start + 1 >= end) {
      return (c1 != "0"); // It would not be an octal escape, but the U+0000 escape sequence.
    }
    
    let c2 = text[start + 1];
    if (c2 < "0" || c2 > "7") {
      return (c1 != "0"); // It would not be an octal escape, but the U+0000 escape sequence.
    }
    
    if (start + 2 >= end) {
      return (c1 != "0" || c2 != "0"); // It would not be an octal escape, but the U+0000 escape sequence + '0'.
    }
    
    let c3 = text[start + 2];
    if (c3 < "0" || c3 > "7") {
      return (c1 != "0" || c2 != "0"); // It would not be an octal escape, but the U+0000 escape sequence + '0'.
    }
    
    return (c1 != "0" || c2 != "0" || c3 != "0"); // Check it's not U+0000 (escaped) + '00'
    
  }
  
  /*
   * Perform the first step unescape operation based on String.
   */
  static func unicodeUnescape(_ text : String) throws -> String {
    var strBuilder : StringBuilder? = nil
    
    let offset : Int = 0;
    let max = text.count
    
    var readOffset = offset;
    var referenceOffset = offset;
    
    for var i in offset..<max {
      let c = text.charAt(i);
      
      /*
       * Check the need for an unescape operation at this point
       */
      if (c != ESCAPE_PREFIX || (i + 1) >= max) {
        continue;
      }
      
      var codepoint = -1;
      
      if (c == ESCAPE_PREFIX) {
        let c1 = text.charAt(i + 1);
        
        if (c1 == ESCAPE_UHEXA_PREFIX2) {
          // This can be a uhexa escape, we need exactly four more characters
          
          var f = i + 2;
          // First, discard any additional 'u' characters, which are allowed
          while (f < max) {
            let cf = text.charAt(f);
            if (cf != ESCAPE_UHEXA_PREFIX2) {
              break;
            }
            f += 1
          }
          let s = f;
          // Parse the hexadecimal digits
          while (f < (s + 4) && f < max) {
            let cf = text.charAt(f);
            if (!((cf >= "0" && cf <= "9") || (cf >= "A" && cf <= "F") || (cf >= "a" && cf <= "f"))) {
              break;
            }
            f += 1
          }
          
          if ((f - s) < 4) {
            // We weren't able to consume the required four hexa chars, leave it as slash+'u', which
            // is invalid, and let the corresponding Java parser fail.
            i += 1
            continue;
          }
          codepoint = parseIntFromReference(text, s, f, 16);
          
          // Fast-forward to the first char after the parsed codepoint
          referenceOffset = f - 1;
          // Don't continue here, just let the unescape code below do its job
        }
        else {
          // Other escape sequences will not be processed in this unescape step.
          i += 1
          continue;
        }
      }
      
      /*
       * At this point we know for sure we will need some kind of unescape, so we
       * can increase the offset and initialize the string builder if needed, along with
       * copying to it all the contents pending up to this point.
       */
      if (strBuilder == nil) {
        strBuilder = StringBuilder()//max + 5);
      }
      if (i - readOffset > 0) {
        _ = strBuilder!.append(text, readOffset, i);
      }
      
      i = referenceOffset;
      readOffset = i + 1;
      
      /*
       * --------------------------
       *
       * Perform the real unescape
       *
       * --------------------------
       */
      if (codepoint > Int(Character("\u{FFFF}"))) {
        _ = strBuilder!.append(try Character.toChars(codepoint));
      }
      else {
        _ = strBuilder!.append(Character(codepoint))
      }
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: return the original String object if no unescape was actually needed. Otherwise
     *                 append the remaining escaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    if (strBuilder == nil) {
      return text;
    }
    
    if (max - readOffset > 0) {
      _ = strBuilder!.append(text, readOffset, max);
    }
    return strBuilder!.toString();
  }
  
  /*
   * Determine whether we will need unicode unescape or not, so that we avoid creating a writer object
   * if it is not needed.
   */
  static func requiresUnicodeUnescape(_ text : [Character], _ offset : Int, _ len : Int) -> Bool {
    let max = (offset + len);
    
    for i in offset..<max {
      let c = text[i];
      
      if (c != ESCAPE_PREFIX || (i + 1) >= max) {
        continue;
      }
      
      if (c == ESCAPE_PREFIX) {
        let c1 = text[i + 1];
        
        if (c1 == ESCAPE_UHEXA_PREFIX2) {
          // This can be a uhexa escape
          return true;
        }
      }
    }
    return false;
  }
  
  /*
   * Perform the first step unescape operation based on char[].
   *
   * NOTE: We should only be calling this if we already executed requiresUnicodeEscape and it returned true!
   */
  static func unicodeUnescape(_ text : [Character], _ offset : Int, _ len : Int, _ writer : java.io.Writer) throws {
    let max = (offset + len);
    
    var readOffset = offset;
    var referenceOffset = offset;
    
    for var i in offset..<max {
      let c = text[i];
      
      /*
       * Check the need for an unescape operation at this point
       */
      if (c != ESCAPE_PREFIX || (i + 1) >= max) {
        continue;
      }
      
      var codepoint = -1;
      
      if (c == ESCAPE_PREFIX) {
        let c1 = text[i + 1];
        
        if (c1 == ESCAPE_UHEXA_PREFIX2) {
          // This can be a uhexa escape, we need exactly four more characters
          
          var f = i + 2;
          // First, discard any additional 'u' characters, which are allowed
          while (f < max) {
            let cf = text[f];
            if (cf != ESCAPE_UHEXA_PREFIX2) {
              break;
            }
            f += 1
          }
          let s = f;
          // Parse the hexadecimal digits
          while (f < (s + 4) && f < max) {
            let cf = text[f];
            if (!((cf >= "0" && cf <= "9") || (cf >= "A" && cf <= "F") || (cf >= "a" && cf <= "f"))) {
              break;
            }
            f += 1
          }
          
          if ((f - s) < 4) {
            // We weren't able to consume the required four hexa chars, leave it as slash+'u', which
            // is invalid, and let the corresponding Java parser fail.
            i += 1
            continue;
          }
          
          codepoint = parseIntFromReference(text, s, f, 16);
          
          // Fast-forward to the first char after the parsed codepoint
          referenceOffset = f - 1;
          // Don't continue here, just let the unescape code below do its job
        }
        else {
          // Other escape sequences will not be processed in this unescape step.
          i += 1
          continue;
        }
      }
      
      /*
       * At this point we know for sure we will need some kind of unescape, so we
       * can copy all the contents pending up to this point.
       */
      if (i - readOffset > 0) {
        try writer.write(text, readOffset, (i - readOffset));
      }
      i = referenceOffset;
      readOffset = i + 1;
      
      /*
       * --------------------------
       *
       * Perform the real unescape
       *
       * --------------------------
       */
      if (codepoint > Int(Character("\u{FFFF}"))) {
        try writer.write(try Character.toChars(codepoint))
      }
      else {
        try writer.write(Character(codepoint))
      }
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: append the remaining escaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    if (max - readOffset > 0) {
      try writer.write(text, readOffset, (max - readOffset));
    }
  }
  
  /*
   * Perform an unescape operation based on String.
   */
  static func unescape(_ text : String) throws -> String {
    
    // Will be exactly the same object if no unicode escape was needed
    let unicodeEscapedText = try unicodeUnescape(text);
    
    var strBuilder : StringBuilder? = nil
    
    let offset = 0
    let max = unicodeEscapedText.count
    
    var readOffset = offset
    var referenceOffset = offset
    
    for var i in offset..<max {
      let c = unicodeEscapedText.charAt(i)
      
      /*
       * Check the need for an unescape operation at this point
       */
      if (c != ESCAPE_PREFIX || (i + 1) >= max) {
        continue;
      }
      
      var codepoint = -1;
      
      if (c == ESCAPE_PREFIX) {
        let c1 : Character = unicodeEscapedText.charAt(i + 1);
        
        switch (c1) {
        case "0":
          if (!isOctalEscape(unicodeEscapedText,i + 1,max)) {
            codepoint = 0x00; referenceOffset = i + 1
          }
          break
        case "b": codepoint = 0x08; referenceOffset = i + 1
          break
        case "t": codepoint = 0x09; referenceOffset = i + 1
          break
        case "n": codepoint = 0x0A; referenceOffset = i + 1
          break
        case "f": codepoint = 0x0C; referenceOffset = i + 1
          break
        case "r": codepoint = 0x0D; referenceOffset = i + 1
          break
        case "\"": codepoint = 0x22; referenceOffset = i + 1
          break
        case "'": codepoint = 0x27; referenceOffset = i + 1
          break
        case "\\": codepoint = 0x5C; referenceOffset = i + 1
          break
        default:
          break
        }
        
        if (codepoint == -1) {
          
          if (c1 >= "0" && c1 <= "7") {
            // This can be a octal escape, we need at least 1 more char, and up to 3 more.
            
            var f = i + 2;
            while (f < (i + 4) && f < max) { // We need only a max of two more chars
              let cf : Character = unicodeEscapedText.charAt(f);
              if (!(cf >= "0" && cf <= "7")) {
                break;
              }
              f += 1
            }
            
            codepoint = parseIntFromReference(unicodeEscapedText, i + 1, f, 8);
            
            if (codepoint > 0xFF) {
              // Maximum octal escape char is FF. Ignore the last digit
              codepoint = parseIntFromReference(unicodeEscapedText, i + 1, f - 1, 8);
              referenceOffset = f - 2;
            }
            else {
              referenceOffset = f - 1;
            }
            // Don't continue here, just let the unescape code below do its job
          }
          else {
            // Other escape sequences are not allowed by Java. So we leave it as is
            // and expect the corresponding Java parser to fail.
            i += 1
            continue;
          }
        }
      }
      
      /*
       * At this point we know for sure we will need some kind of unescape, so we
       * can increase the offset and initialize the string builder if needed, along with
       * copying to it all the contents pending up to this point.
       */
      
      if (strBuilder == nil) {
        strBuilder = StringBuilder()//max + 5);
      }
      
      if (i - readOffset > 0) {
        _ = strBuilder!.append(unicodeEscapedText, readOffset, i);
      }
      
      i = referenceOffset;
      readOffset = i + 1;
      
      /*
       * --------------------------
       *
       * Perform the real unescape
       *
       * --------------------------
       */
      
      if (codepoint > Int(Character("\u{FFFF}"))) {
        _ = strBuilder!.append(try Character.toChars(codepoint));
      } else {
        _ = strBuilder!.append(Character(codepoint))
      }
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: return the original String object if no unescape was actually needed. Otherwise
     *                 append the remaining escaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    if (strBuilder == nil) {
      return unicodeEscapedText;
    }
    
    if (max - readOffset > 0) {
      _ = strBuilder!.append(unicodeEscapedText, readOffset, max);
    }
    
    return strBuilder!.toString();
  }
  
  /*
   * Perform an unescape operation based on a Reader, writing the results to a Writer.
   *
   * Note this reader is going to be read char-by-char, so some kind of buffering might be appropriate if this
   * is an inconvenience for the specific Reader implementation.
   */
  static func unescape(_ reader : java.io.Reader, _ writer : java.io.Writer) throws {
    
    /*
     * Unescape in Java is a bit different because two different escape systems might have been applied one on
     * top of the other: Octal escapes (\041) are supported at runtime, whereas unicode escapes (\u00E1) are
     * applied at parse time. So it is technically possible to have an unicode-escaped octal escape. That means
     * one output char would be represented in input by 4 * 6 = 24 chars, corresponding to the 6 chars of each
     * of the unicode-escapes for each of the max-4 chars of the octal escape.
     *
     * This means that we will have to use a buffer and that, each time we fill the buffer, we will have to
     * check that at least the last 8 characters are not a '\', which will mean we can be sure that we are not
     * interrupting any escape sequence. That number (8) is so because that is the largest amount of non-\ chars
     * that can happen being involved in an escape sequence, combining both escape methods: "\u005C777"
     */
    
    var buffer : [Character] = Array(repeating: "\0", count: 20)
    
    var read = try reader.read(&buffer, 0, buffer.count);
    if (read < 0) {
      return
    }
    
    var bufferSize = read
    
    while (bufferSize > 0 || read >= 0) {
      
      var nonEscCounter = 0
      var n = bufferSize
      while nonEscCounter < 8 && n >= 0 {
        if buffer[n] == "\\" {
          nonEscCounter = 0
          n -= 1 // Dekrementieren von 'n'
          continue
        }
        nonEscCounter += 1
        n -= 1 // Dekrementieren von 'n'
      }

      
      if (nonEscCounter < 8 && read >= 0) {
        // not found an 8-char non-escape sequence in the whole buffer, will need to read more buffer
        
        if (bufferSize == buffer.length) {
          // Actually, there is no room for reading more, so let's grow the buffer
          
          var newBuffer : [Character] = Array(repeating: "\u{0}", count: buffer.length + (buffer.length / 2))
          System.arraycopy(buffer, 0, &newBuffer, 0, buffer.length);
          buffer = newBuffer;
        }
        
        read = try reader.read(&buffer, bufferSize, (buffer.length - bufferSize));
        if (read >= 0) {
          bufferSize += read;
        }
        continue;
      }
      n = (n < 0 ? bufferSize : n + nonEscCounter);
      
      // Once we have defined a 'safe' buffer, just call the char[]-based method
      try unescape(buffer, 0, n, writer);
      
      System.arraycopy(buffer, n, &buffer, 0, (bufferSize - n));
      bufferSize -= n;
      
      read = try reader.read(&buffer, bufferSize, (buffer.length - bufferSize));
      if (read >= 0) {
        bufferSize += read;
      }
    }
  }
  
  /*
   * Perform an unescape operation based on char[].
   */
  static func unescape(_ text : [Character], _ offset : Int, _ len : Int, _ writer : java.io.Writer) throws {
    
    var unicodeEscapedText = text
    var unicodeEscapedOffset = offset;
    var unicodeEscapedLen = len;
    if (requiresUnicodeUnescape(text, offset, len)) {
      let charArrayWriter = try java.io.CharArrayWriter(len + 2);
      try unicodeUnescape(text, offset, len, charArrayWriter);
      unicodeEscapedText = charArrayWriter.toCharArray();
      unicodeEscapedOffset = 0;
      unicodeEscapedLen = unicodeEscapedText.length;
    }
    
    let max = (unicodeEscapedOffset + unicodeEscapedLen);
    
    var readOffset = unicodeEscapedOffset;
    var referenceOffset = unicodeEscapedOffset;
    
    for var i in unicodeEscapedOffset..<max {
      
      let c : Character = unicodeEscapedText[i];
      
      /*
       * Check the need for an unescape operation at this point
       */
      if (c != ESCAPE_PREFIX || (i + 1) >= max) {
        continue;
      }
      
      var codepoint = -1;
      
      if (c == ESCAPE_PREFIX) {
        let c1 : Character = unicodeEscapedText[i + 1];
        
        switch (c1) {
        case "0":
          if (!isOctalEscape(unicodeEscapedText,i + 1,max)) {
            codepoint = 0x00; referenceOffset = i + 1;
          }
          break;
        case "b":  codepoint = 0x08; referenceOffset = i + 1; break;
        case "t":  codepoint = 0x09; referenceOffset = i + 1; break;
        case "n":  codepoint = 0x0A; referenceOffset = i + 1; break;
        case "f":  codepoint = 0x0C; referenceOffset = i + 1; break;
        case "r":  codepoint = 0x0D; referenceOffset = i + 1; break;
        case "\"": codepoint = 0x22; referenceOffset = i + 1; break;
        case "\'": codepoint = 0x27; referenceOffset = i + 1; break;
        case "\\": codepoint = 0x5C; referenceOffset = i + 1; break;
        default: break
        }
        
        if (codepoint == -1) {
          
          if (c1 >= "0" && c1 <= "7") {
            // This can be a octal escape, we need at least 1 more char, and up to 3 more.
            
            var f : Int = i + 2;
            while (f < (i + 4) && f < max) { // We need only a max of two more chars
              let cf : Character = unicodeEscapedText[f];
              if (!(cf >= "0" && cf <= "7")) {
                break;
              }
              f += 1
            }
            
            codepoint = parseIntFromReference(unicodeEscapedText, i + 1, f, 8);
            
            if (codepoint > 0xFF) {
              // Maximum octal escape char is FF. Ignore the last digit
              codepoint = parseIntFromReference(unicodeEscapedText, i + 1, f - 1, 8);
              referenceOffset = f - 2;
            } else {
              referenceOffset = f - 1;
            }
            // Don't continue here, just let the unescape code below do its job
          } else {
            // Other escape sequences are not allowed by Java. So we leave it as is
            // and expect the corresponding Java parser to fail.
            i += 1
            continue;
            
          }
        }
      }
      
      /*
       * At this point we know for sure we will need some kind of unescape, so we
       * can copy all the contents pending up to this point.
       */
      
      if (i - readOffset > 0) {
        try writer.write(unicodeEscapedText, readOffset, (i - readOffset));
      }
      
      i = referenceOffset;
      readOffset = i + 1;
      
      /*
       * --------------------------
       *
       * Perform the real unescape
       *
       * --------------------------
       */
      if (codepoint > Int(Character("\u{FFFF}"))) {
        try writer.write(try Character.toChars(codepoint));
      }
      else {
        try writer.write(Character(codepoint))
      }
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: append the remaining escaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    
    if (max - readOffset > 0) {
      try writer.write(unicodeEscapedText, readOffset, (max - readOffset))
    }
  }
  
  private static func codePointAt(_ c1 : Character, _ c2 : Character) -> Int{
    if (Character.isHighSurrogate(c1)) {
      if (Int(c2) >= 0) {
        if (Character.isLowSurrogate(c2)) {
          return Character.toCodePoint(Int(c1), Int(c2))
        }
      }
    }
    return Int(c1)
  }
}
