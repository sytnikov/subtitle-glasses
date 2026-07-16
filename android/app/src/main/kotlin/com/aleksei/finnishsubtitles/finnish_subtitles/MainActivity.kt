package com.aleksei.finnishsubtitles.finnish_subtitles

import io.flutter.embedding.android.FlutterFragmentActivity

// meta_wearables_dat_flutter requires FlutterFragmentActivity (a
// ComponentActivity) because the registration deep-link flow and the
// camera permission contract both rely on ActivityResultRegistry, which
// FlutterActivity does not expose.
class MainActivity : FlutterFragmentActivity()
