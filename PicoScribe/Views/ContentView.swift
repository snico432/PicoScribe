/*
See LICENSE.txt for licensing information.

Abstract:
Root SwiftUI view.
*/

import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            TranscriptionView()
        }
    }
}
