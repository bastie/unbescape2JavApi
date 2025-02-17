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

/*
 * This is basically a very simplified, thread-unsafe version of StringReader that should
 * perform better than the original StringReader by removing all synchronization structures.
 *
 * Note the only implemented methods are those that we know are really used from within the
 * stream-based escape/unescape operations.
 */
internal final class InternalStringReader : java.io.Reader, @unchecked Sendable {
  
  private var str : String
  private var length : Int
  private var next = 0;
  
  public init(_ s : String) {
    self.str = s
    self.length = s.count
    super.init()
  }
  
  public override func read() throws -> Int{
    if (self.next >= length) {
      return -1
    }
    let result = self.str.charAt(self.next)
    self.next += 1
    return Int(result)
  }
  
  public override func read(_ cbuf : inout [Character], _ off : Int, _ len : Int) throws -> Int {
    if ((off < 0) || (off > cbuf.length) || (len < 0) ||
        ((off + len) > cbuf.length) || ((off + len) < 0)) {
      throw Throwable.IndexOutOfBoundsException()
    } else if (len == 0) {
      return 0;
    }
    if (self.next >= self.length) {
      return -1
    }
    let n : Int = Math.min(self.length - self.next, len)
    self.str.getChars(self.next, self.next + n, &cbuf, off)
    self.next += n
    return n
  }
  }
