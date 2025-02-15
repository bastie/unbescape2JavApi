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
extension UriEscapeUtil {

  
  /*
   * URI ESCAPE/UNESCAPE OPERATIONS
   * ------------------------------
   *
   *   See: http://www.ietf.org/rfc/rfc3986.txt
   *        http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
   *
   *   Different parts of an URI allow different characters, and therefore require different sets of
   *   characters to be escaped (see RFC3986 for a list of reserved characters for each URI part) - but
   *   the escaping method is always the same: convert the character to the bytes representing it in a
   *   specific encoding (UTF-8 by default) and then percent-encode these bytes with two hexadecimal
   *   digits, like '%0A'.
   *
   *   - PATH:            Part of the URI path, might include several path levels/segments:
   *                      '/admin/users/list?x=1' -> 'users/list'
   *   - PATH SEGMENT:    Part of the URI path, can include only one path level ('/' chars will be escaped):
   *                      '/admin/users/list?x=1' -> 'users'
   *   - QUERY PARAMETER: Names and values of the URI query parameters:
   *                      '/admin/users/list?x=1' -> 'x' (name), '1' (value)
   *   - URI FRAGMENT ID: URI fragments:
   *                      '/admin/users/list?x=1#something' -> '#something'
   *
   */
  
  internal enum UriEscapeType {
    
    case PATH /*{
      public func isAllowed(_ c : Int) -> Bool {
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c;
      }
    }*/
    
    case PATH_SEGMENT /*{
      public func isAllowed(_ c : Int) -> Bool {
        return UriEscapeUtil.UriEscapeType.isPchar(c);
      }
    }*/
    
    case QUERY_PARAM /*{
      public func isAllowed(_ c : Int) -> Bool {
        // We specify these symbols separately because some of them are considered 'pchar'
        if (Int("=") == c || Int("&") == c || Int("+") == c || Int("#") == c) {
          return false;
        }
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c || Int("?") == c
      }
      public func canPlusEscapeWhitespace() -> Bool {
        return true;
      }
    }*/
    
    case FRAGMENT_ID /*{
      public func isAllowed(_ c : Int) -> Bool{
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c || Int("?") == c
      }
    }*/
    
    
    public func isAllowed (_ c : Int) -> Bool {
      switch self {
      case .PATH :
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c
      case .PATH_SEGMENT :
        return UriEscapeUtil.UriEscapeType.isPchar(c)
      case .QUERY_PARAM :
        if (Int("=") == c || Int("&") == c || Int("+") == c || Int("#") == c) {
          return false
        }
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c || Int("?") == c
      case .FRAGMENT_ID :
        return UriEscapeUtil.UriEscapeType.isPchar(c) || Int("/") == c || Int("?") == c
      }
      
    }

    /*
     * Determines whether whitespace could appear escaped as '+' in the
     * current escape type.
     *
     * This allows unescaping of application/x-www-form-urlencoded
     * URI query parameters, which specify '+' as escape character
     * for whitespace instead of the '%20' specified by RFC3986.
     *
     * http://www.w3.org/TR/html401/interact/forms.html#h-17.13.4
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    public func canPlusEscapeWhitespace() -> Bool {
      // Will only be true for QUERY_PARAM
      switch self {
      case .QUERY_PARAM :
        return true
      default :
        return false
      }
    }
    
    /*
     * Specification of 'pchar' according to RFC3986
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    private static func isPchar(_ c : Int) -> Bool {
      return isUnreserved(c) || isSubDelim(c) || Int(":") == c || Int("@") == c
    }
    
    /*
     * Specification of 'unreserved' according to RFC3986
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    private static func isUnreserved(_ c : Int) -> Bool {
      return isAlpha(c) || isDigit(c) || Int("-") == c || Int(".") == c || Int("_") == c || Int("~") == c
    }
    
    /*
     * Specification of 'reserved' according to RFC3986
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    private static func isReserved(_ c : Int) -> Bool {
      return isGenDelim(c) || isSubDelim(c);
    }
    
    /*
     * Specification of 'sub-delims' according to RFC3986
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    private static func isSubDelim(_ c : Int) -> Bool {
      return Int("!") == c || Int("$") == c || Int("&") == c || Int("\'") == c || Int("(") == c || Int(")") == c || Int("*") == c || Int("+") == c || Int(",") == c || Int(";") == c || Int("=") == c
    }
    
    /*
     * Specification of 'gen-delims' according to RFC3986
     * http://www.ietf.org/rfc/rfc3986.txt
     */
    private static func isGenDelim(_ c : Int) -> Bool {
      return Int(":") == c || Int("/") == c || Int("?") == c || Int("#") == c || Int("[") == c || Int("]") == c || Int("@") == c
    }
    
    /*
     * Character.isLetter() is not used here because it would include
     * non a-to-z letters.
     */
    static func isAlpha(_ c : Int) -> Bool {
      return c >= Int("A") && c <= Int("Z") || c >= Int("a") && c <= Int("z")
    }
    
    /*
     * Character.isDigit() is not used here because it would include
     * non 0-to-9 numbers like i.e. arabic or indian numbers.
     */
    private static func isDigit(_ c : Int) -> Bool{
      return c >= Int("0") && c <= Int("9")
    }
    
  }

}
