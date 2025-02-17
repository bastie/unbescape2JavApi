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
 *   Levels defined for Java escape/unescape operations:
 * </p>
 *
 * <ul>
 *     <li><strong>Level 1</strong>: Escape only the basic escape set. Note the result of a level-1 escape
 *         operation might still contain non-ASCII characters if they existed in input, and therefore you
 *         will still need to correctly manage your input/output character encoding settings. Such
 *         <em>basic set</em> consists of:
 *         <ul>
 *           <li>The <em>Single Escape Characters</em>:
 *               <kbd>&#92;b</kbd> (<kbd>U+0008</kbd>),
 *               <kbd>&#92;t</kbd> (<kbd>U+0009</kbd>),
 *               <kbd>&#92;n</kbd> (<kbd>U+000A</kbd>),
 *               <kbd>&#92;f</kbd> (<kbd>U+000C</kbd>),
 *               <kbd>&#92;r</kbd> (<kbd>U+000D</kbd>),
 *               <kbd>&#92;&quot;</kbd> (<kbd>U+0022</kbd>),
 *               <kbd>&#92;&#39;</kbd> (<kbd>U+0027</kbd>),
 *               <kbd>&#92;&#92;</kbd> (<kbd>U+005C</kbd>). Note <kbd>&#92;&#39;</kbd> is not really needed in
 *               String literals (only in Character literals), so it won't be used until escape level 3.
 *           </li>
 *           <li>
 *               Two ranges of non-displayable, control characters (some of which are already part of the
 *               <em>single escape characters</em> list): <kbd>U+0000</kbd> to <kbd>U+001F</kbd>
 *               and <kbd>U+007F</kbd> to <kbd>U+009F</kbd>.
 *           </li>
 *         </ul>
 *     </li>
 *     <li><strong>Level 2</strong>: Escape the basic escape set (as defined in level 1), plus all
 *         non-ASCII characters. The result of a level-2 escape operation is therefore always ASCII-only text, and
 *         safer to use in complex scenarios with mixed input/output character encodings.</li>
 *     <li><strong>Level 3</strong>: Escape all non-alphanumeric characters, this is, all but those in the
 *         <kbd>A</kbd>-<kbd>Z</kbd>, <kbd>a</kbd>-<kbd>z</kbd> and <kbd>0</kbd>-<kbd>9</kbd> ranges. This level
 *         can be safely used for completely escaping texts, including whitespace, line feeds, punctuation, etc. in
 *         scenarios where this adds an extra level of safety.</li>
 *     <li><strong>Level 4</strong>: Escape all characters, even alphanumeric ones.</li>
 * </ul>
 *
 * <p>
 *   For further information, see the <em>Glossary</em> and the <em>References</em> sections at the
 *   documentation for the {@link org.unbescape.java.JavaEscape} class.
 * </p>
 *
 * @author Daniel Fern&aacute;ndez
 *
 * @since 1.0.0
 *
 */
public enum JavaEscapeLevel {
  
  /**
   * Level 1 escape: escape only the basic escape set: Single Escape Chars plus non-displayable control chars.
   */
  case LEVEL_1_BASIC_ESCAPE_SET(value : Int = 1)
  
  /**
   * Level 2 escape: escape the basic escape set plus all non-ASCII characters (result will always be ASCII).
   */
  case LEVEL_2_ALL_NON_ASCII_PLUS_BASIC_ESCAPE_SET(value : Int = 2)
  
  /**
   * Level 3 escape: escape all non-alphanumeric characteres (escape all but those in the
   * <kbd>A</kbd>-<kbd>Z</kbd>, <kbd>a</kbd>-<kbd>z</kbd> and <kbd>0</kbd>-<kbd>9</kbd> ranges).
   */
  case LEVEL_3_ALL_NON_ALPHANUMERIC(value : Int = 3)
  
  /**
   * Level 4 escape: escape all characters, including alphanumeric.
   */
  case LEVEL_4_ALL_CHARACTERS(value : Int = 4)
  
  /**
   * <p>
   *   Utility method for obtaining an enum value from its corresponding <kbd>int</kbd> level value.
   * </p>
   *
   * @param level the level
   * @return the escape level enum constant, or <kbd>IllegalArgumentException</kbd> if level does not exist.
   */
  public static func forLevel (_ level : Int) throws -> JavaEscapeLevel {
    switch (level) {
    case 1: return LEVEL_1_BASIC_ESCAPE_SET()
    case 2: return LEVEL_2_ALL_NON_ASCII_PLUS_BASIC_ESCAPE_SET()
    case 3: return LEVEL_3_ALL_NON_ALPHANUMERIC()
    case 4: return LEVEL_4_ALL_CHARACTERS()
    default:
      throw Throwable.IllegalArgumentException("No escape level enum constant defined for level: \(level)")
    }
  }
  
  /**
   * Return the <kbd>int</kbd> escape level.
   *
   * @return the escape level.
   */
  public func getEscapeLevel() -> Int {
    switch self {
    case let .LEVEL_1_BASIC_ESCAPE_SET(v): fallthrough
    case let .LEVEL_2_ALL_NON_ASCII_PLUS_BASIC_ESCAPE_SET(v): fallthrough
    case let .LEVEL_3_ALL_NON_ALPHANUMERIC(v): fallthrough
    case let .LEVEL_4_ALL_CHARACTERS(v):
      return v
    }
  }
  
}
