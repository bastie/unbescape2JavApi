/*
 * =============================================================================
 * 
 *   Copyright (c) 2014-2025 Unbescape (http://www.unbescape.org)
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
import Foundation

/**
 * <p>
 *   Internal class in charge of performing the real escape/unescape operations.
 * </p>
 *
 * @author Daniel Fern&aacute;ndez
 *
 * @since 1.1.0
 *
 */
final class UriEscapeUtil {
  
  
  /*
   * Prefixes defined for use in escape and unescape operations
   */
  private static let ESCAPE_PREFIX : Character = "%"
  
  /*
   * Small utility char arrays for hexadecimal conversion.
   */
  private static let HEXA_CHARS_UPPER = "0123456789ABCDEF".toCharArray();
  private static let HEXA_CHARS_LOWER = "0123456789abcdef".toCharArray();
  
  private init() {
  }
  
  internal static func printHexa(_ b : UInt8) -> [Character] {
    var result : [Character] = [" ", " "]
    result[0] = HEXA_CHARS_UPPER[Int((b >> 4) & 0xF)];
    result[1] = HEXA_CHARS_UPPER[Int(b) & 0xF];
    return result;
  }
  

  internal static func parseHexa(_ c1 : Character, _ c2 : Character) -> UInt8 {
    
    var result : UInt8 = 0
    for j in 0..<HEXA_CHARS_UPPER.count {
      if (c1 == HEXA_CHARS_UPPER[j] || c1 == HEXA_CHARS_LOWER[j]) {
        result += UInt8((j << 4));
        break;
      }
    }
    for j in 0..<HEXA_CHARS_UPPER.count {
      if (c2 == HEXA_CHARS_UPPER[j] || c2 == HEXA_CHARS_LOWER[j]) {
        result += UInt8(j);
        break;
      }
    }
    return result;
  }
  
  /*
   * Perform an escape operation, based on String, according to the specified type.
   */
  static func escape(_ text : String?, _ escapeType : UriEscapeType, _ encoding : String) throws -> String? {
    guard text != nil else {
      return nil
    }

    var strBuilder : StringBuilder? = nil

    if let text {
      
      let offset = 0;
      let max = text.count
      
      var readOffset = offset
      
      for var i in offset..<max {
        
        let codepoint : Int = try Character.codePointAt(text.toCharArray(), i)
        
        /*
         * Shortcut: most characters will be alphabetic, and we won't need to do anything at
         * all for them. No need to use the complete UriEscapeType check system at all.
         */
        if (UriEscapeType.isAlpha(codepoint)) {
          continue;
        }
        
        /*
         * Check whether the character is allowed or not
         */
        if (escapeType.isAllowed(codepoint)) {
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
         * Perform the real escape
         *
         * -----------------------------------------------------------------------------------------
         */
        
        var charAsBytes : [UInt8] = []
        do {
          charAsBytes = try String(Character.toChars(codepoint)).getBytes(encoding);
        }
        catch {//(final UnsupportedEncodingException e) {
          throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
        }
        for b in charAsBytes {
          _ = strBuilder!.append("%");
          _ = strBuilder!.append(printHexa(b));
        }
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
    }
    return strBuilder!.toString();
  }
  
  /*
   * Perform an escape operation, based on a Reader, according to the specified type and writing the
   * result to a Writer.
   *
   * Note this reader is going to be read char-by-char, so some kind of buffering might be appropriate if this
   * is an inconvenience for the specific Reader implementation.
   */
  static func escape(_ reader : java.io.Reader, _ writer : java.io.Writer, _ escapeType : UriEscapeType, _ encoding : String) throws {
    var c1 : Int // c0: last char, c1: current char, c2: next char
    var c2 : Int // c0: last char, c1: current char, c2: next char
    
    c2 = try reader.read();
    
    while (c2 >= 0) {
      
      c1 = c2;
      c2 = try reader.read();
      
      let codepoint : Int = codePointAt(Character(c1), Character(c2))
      
      /*
       * Shortcut: most characters will be alphabetic, and we won't need to do anything at
       * all for them. No need to use the complete UriEscapeType check system at all.
       */
      if (UriEscapeType.isAlpha(codepoint)) {
        try writer.write(c1);
        continue;
      }
      
      /*
       * Check whether the character is allowed or not
       */
      if (escapeType.isAllowed(codepoint)) {
        try writer.write(c1);
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
       * Perform the real escape
       *
       * -----------------------------------------------------------------------------------------
       */
      
      var charAsBytes : [UInt8] = []
      do {
        charAsBytes = try String(try Character.toChars(codepoint)).getBytes(encoding);
      }
      catch {//}(final UnsupportedEncodingException e) {
        throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
      }
      for b in charAsBytes {
        try writer.write("%");
        try writer.write(printHexa(b));
      }
    }
    
  }
  
  /*
   * Perform an escape operation, based on char[], according to the specified type
   */
  static func escape(_ text : [Character], _ offset : Int, _ len : Int, _ writer : java.io.Writer,_ escapeType : UriEscapeType, _ encoding : String) throws {
    guard text.count > 0 else {
      return;
    }
    
    let max = (offset + len)
    var readOffset = offset
    
    for var i in offset..<max {
      
      let codepoint = try Character.codePointAt(text, i);
      
      /*
       * Shortcut: most characters will be alphabetic, and we won't need to do anything at
       * all for them. No need to use the complete UriEscapeType check system at all.
       */
      if (UriEscapeType.isAlpha(codepoint)) {
        continue;
      }
      
      /*
       * Check whether the character is allowed or not
       */
      if (escapeType.isAllowed(codepoint)) {
        continue;
      }
                  
      /*
       * At this point we know for sure we will need some kind of escape, so we
       * can write all the contents pending up to this point.
       */
      
      if (i - readOffset > 0) {
        try writer.write(text, readOffset, (i - readOffset));
      }
      
      if (Character.charCount(codepoint) > 1) {
        // This is to compensate that we are actually reading two char[] positions with a single codepoint.
        i += 1
      }
      
      readOffset = i + 1;
      
      /*
       * -----------------------------------------------------------------------------------------
       *
       * Perform the real escape
       *
       * -----------------------------------------------------------------------------------------
       */
      
      var charAsBytes : [UInt8] = []
      do {
        charAsBytes = try String(try Character.toChars(codepoint)).getBytes(encoding);
      }
      catch {//}(final UnsupportedEncodingException e) {
        throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
      }
      for b in charAsBytes {
        try writer.write("%");
        try writer.write(printHexa(b));
      }
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: return the original String object if no escape was actually needed. Otherwise
     *                 append the remaining unescaped text to the string builder and return.
     * -----------------------------------------------------------------------------------------------
     */
    
    if (max - readOffset > 0) {
      try writer.write(text, readOffset, (max - readOffset));
    }
  }
  
  /*
   * Perform an unescape operation based on String.
   */
  static func unescape(_ text : String, _ escapeType : UriEscapeType, _ encoding : String) throws -> String {
    
    var strBuilder : StringBuilder? = nil
    
    let offset = 0
    let max = text.count
    
    var readOffset = offset;
    
    for var i in offset..<max {
      
      let c : Character = text.charAt(i)
      
      /*
       * Check the need for an unescape operation at this point
       */
      
      if (c != ESCAPE_PREFIX && (c != "+" || !escapeType.canPlusEscapeWhitespace())) {
        continue;
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
            
      /*
       * Deal with possible '+'-escaped whitespace (application/x-www-form-urlencoded)
       */
      if (c == "+") {
        // if we reached this point with c == '+', it's escaping a whitespace
        _ = strBuilder!.append(" ");
        readOffset = i + 1;
        continue;
      }
      
      
      /*
       * ESCAPE PROCESS
       * --------------
       * If there are more than one percent-encoded/escaped sequences together, we will
       * need to unescape them all at once (because they might be bytes --up to 4-- of
       * the same char).
       */
      
      
      // Max possible size will be the remaining amount of chars / 3
      var bytes : [UInt8] = [] //new byte[(max-i)/3];
      var aheadC : Character = c
      var pos = 0
      
      while (((i + 2) < max) && aheadC == ESCAPE_PREFIX) {
        bytes[pos] = parseHexa(text.charAt(i + 1), text.charAt(i + 2))
        pos += 1
        i += 3;
        if (i < max) {
          aheadC = text.charAt(i);
        }
      }
      
      if (i < max && aheadC == ESCAPE_PREFIX) {
        // Incomplete escape sequence!
        throw Throwable.IllegalArgumentException("Incomplete escaping sequence in input");
      }
      
      do {
        _ = strBuilder!.append(try String(Array(bytes[0..<pos]), encoding))
      } catch {//}(final UnsupportedEncodingException e) {
        throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
      }
      readOffset = i;
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
   * Perform an unescape operation based on a Reader, writing the results to a Writer.
   *
   * Note this reader is going to be read char-by-char, so some kind of buffering might be appropriate if this
   * is an inconvenience for the specific Reader implementation.
   */
  static func unescape(_ reader : java.io.Reader, _ writer : java.io.Writer, _ escapeType : UriEscapeType, _ encoding : String) throws {
    
    var escapes : [UInt8] = [0x00, 0x00, 0x00, 0x00]// new byte[4];
    var c1 : Int // c1: current char
    var c2 : Int // c2: next char
    var ce0 : Int // ce0-ce2: current escape chars
    var ce1 : Int // ce0-ce2: current escape chars
    var ce2 : Int // ce0-ce2: current escape chars
    
    c2 = try reader.read();
    
    while (c2 >= 0) {
      c1 = c2;
      c2 = try reader.read();
      
      /*
       * Check the need for an unescape operation at this point
       */
      
      if ((c1 != ESCAPE_PREFIX || c2 < 0) && (c1 != "+" || !escapeType.canPlusEscapeWhitespace())) {
        try writer.write(c1);
        continue;
      }
      
      /*
       * Deal with possible '+'-escaped whitespace (application/x-www-form-urlencoded)
       */
      if (c1 == "+") {
        // if we reached this point with c == '+', it's escaping a whitespace
        try writer.write(" ");
        continue;
      }
      
      /*
       * ESCAPE PROCESS
       * --------------
       * If there are more than one percent-encoded/escaped sequences together, we will
       * need to unescape them all at once (because they might be bytes --up to 4-- of
       * the same char).
       */
      
      var pos = 0
      
      ce0 = c1;
      ce1 = c2;
      ce2 = try reader.read();
      
      while (ce0 == ESCAPE_PREFIX && ce1 >= 0 && ce2 >= 0) {
        if (pos == escapes.count) {
          // we need to grow!
          var newEscapes : [UInt8] = escapes
          newEscapes.append(contentsOf: [0x00, 0x00, 0x00, 0x00])//  new byte[escapes.length + 4];
          //System.arraycopy(escapes, 0, newEscapes, 0, escapes.length);
          escapes = newEscapes;
        }
        
        escapes[pos] = parseHexa(Character(ce1), Character(ce2))
        pos += 1
        
        ce0 = try reader.read()
        ce1 = ce0 < 0 ? ce0 : ce0 != ESCAPE_PREFIX ? 0x0 : try reader.read()
        ce2 = ce1 < 0 ? ce1 : ce0 != ESCAPE_PREFIX ? 0x0 : try reader.read()
      }
      
      if (ce0 == ESCAPE_PREFIX) {
        // Incomplete escape sequence!
        throw Throwable.IllegalArgumentException("Incomplete escaping sequence in input");
      }
      
      c2 = ce0;
      
      do {
        try writer.write(String(Array(escapes[0..<pos]), encoding))//String(escapes, 0, pos, encoding));
      }
      catch {//}(final UnsupportedEncodingException e) {
        throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
      }
    }
  }
  
  /*
   * Perform an unescape operation based on char[].
   */
  static func unescape(_ text : [Character], _ offset : Int, _ len : Int, _ writer : java.io.Writer,
                       _ escapeType : UriEscapeType, _ encoding : String) throws {
    
    let max = (offset + len);
    var readOffset = offset;
    
    for var i in offset..<max {
      let c = text[i]
      
      /*
       * Check the need for an unescape operation at this point
       */
      if (c != ESCAPE_PREFIX && (c != "+" || !escapeType.canPlusEscapeWhitespace())) {
        continue;
      }
      
      /*
       * At this point we know for sure we will need some kind of unescape, so we
       * can increase the offset copy all the contents pending up to this point.
       */
      if (i - readOffset > 0) {
        try writer.write(text, readOffset, (i - readOffset));
      }
      
      /*
       * Deal with possible '+'-escaped whitespace (application/x-www-form-urlencoded)
       */
      if (c == "+") {
        // if we reached this point with c == '+', it's escaping a whitespace
        try writer.write(" ");
        readOffset = i + 1;
        continue;
      }
      
      /*
       * ESCAPE PROCESS
       * --------------
       * If there are more than one percent-encoded/escaped sequences together, we will
       * need to unescape them all at once (because they might be bytes --up to 4-- of
       * the same char).
       */
      
      // Max possible size will be the remaining amount of chars / 3
      var bytes : [UInt8] = []// new byte[(max-i)/3];
      var aheadC = c;
      var pos = 0;
      
      while (((i + 2) < max) && aheadC == ESCAPE_PREFIX) {
        bytes[pos] = parseHexa(text[i + 1], text[i + 2]);
        pos += 1
        i += 3;
        if (i < max) {
          aheadC = text[i];
        }
      }
      
      if (i < max && aheadC == ESCAPE_PREFIX) {
        // Incomplete escape sequence!
        throw Throwable.IllegalArgumentException("Incomplete escaping sequence in input");
      }
      
      do {
        try writer.write(try String(bytes, 0, pos, encoding));
      } catch {//}(final UnsupportedEncodingException e) {
        throw Throwable.IllegalArgumentException("Exception while escaping URI: Bad encoding '\(encoding)'")//, e);
      }
      readOffset = i;
    }
    
    /*
     * -----------------------------------------------------------------------------------------------
     * Final cleaning: return the original String object if no unescape was actually needed. Otherwise
     *                 append the remaining escaped text and return.
     * -----------------------------------------------------------------------------------------------
     */
    if (max - readOffset > 0) {
      try writer.write(text, readOffset, (max - readOffset));
    }
  }
  
  private static func codePointAt(_ c1 : Character, _ c2 : Character) -> Int {
    if (Character.isHighSurrogate(c1)) {
      if (Int(c2) >= 0) {
        if (Character.isLowSurrogate(c2)) {
          return Character.toCodePoint(Int(c1), Int(c2));
        }
      }
    }
    return Int(c1)
  }
}
