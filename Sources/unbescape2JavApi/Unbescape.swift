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

import Foundation
import JavApi


///
/// Class meant to keep some constants related to the version of the Unbescape library being used.
///
/// - Authors: Daniel Fern&aacute;ndez
/// - Authors: Sͬeͥbͭaͭsͤtͬian (Swift translation)
///
/// - Since: 1.1.6
/// - Version: 1.1.6
///
public struct Unbescape {
  
  public static let VERSION_MAJOR = 1
  public static let VERSION_MINOR = 1
  public static let VERSION_BUILD = 6
  public static let VERSION_TYPE = "RELEASE"
  
  public static let VERSION = "\(VERSION_MAJOR).\(VERSION_MINOR).\(VERSION_BUILD)-\(VERSION_TYPE)"

  public static func isVersionStableRelease() -> Bool {
    return "RELEASE".equals(VERSION_TYPE);
  }
  
  private init() {
  }
}
