package com.repea.studytrack

import android.content.Context
import android.os.Bundle
import android.os.Build
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.core.view.WindowCompat
import androidx.hilt.navigation.compose.hiltViewModel
import androidx.navigation.compose.rememberNavController
import com.repea.studytrack.ui.components.BottomNavigationBar
import com.repea.studytrack.ui.components.LiquidGlassParams
import com.repea.studytrack.ui.components.LiquidBackground
import com.repea.studytrack.ui.navigation.NavGraph
import com.repea.studytrack.ui.theme.StudyTrackTheme
import com.repea.studytrack.viewmodel.MainViewModel
import com.repea.studytrack.viewmodel.UserPreferencesViewModel
import com.kyant.backdrop.backdrops.rememberLayerBackdrop
import androidx.compose.ui.graphics.rememberGraphicsLayer
import com.repea.studytrack.repository.AppThemeStyle
import com.repea.studytrack.ui.components.ProvideLiquidGlass
import dagger.hilt.android.AndroidEntryPoint

@AndroidEntryPoint
class MainActivity : ComponentActivity() {
    private var widgetLink by androidx.compose.runtime.mutableStateOf<android.net.Uri?>(null)
    private var linkSequence by androidx.compose.runtime.mutableIntStateOf(0)

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        WindowCompat.setDecorFitsSystemWindows(window, false) // Ensure edge-to-edge
        widgetLink = intent?.data
        setContent {
            com.repea.studytrack.ui.parity.PlatformApp(widgetLink,linkSequence)
        }
    }
    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent); setIntent(intent); widgetLink = intent.data; linkSequence++
    }
}

@Composable
fun AppRoot(
    prefsViewModel: UserPreferencesViewModel = hiltViewModel()
) {
    val prefs by prefsViewModel.preferences.collectAsState()
    StudyTrackTheme(themeStyle = prefs.themeStyle) {
        MainScreen(userPrefs = prefs)
    }
}

@Composable
fun MainScreen(
    userPrefs: com.repea.studytrack.repository.UserPreferencesState,
    viewModel: MainViewModel = hiltViewModel()
) {
    val navController = rememberNavController()
    val isFirstLaunch by viewModel.isFirstLaunch.collectAsState(initial = true)

    val isProbablyEmulator =
        Build.FINGERPRINT.startsWith("generic", ignoreCase = true) ||
            Build.FINGERPRINT.lowercase().contains("emulator") ||
            Build.MODEL.contains("google_sdk", ignoreCase = true) ||
            Build.MODEL.contains("sdk_gphone", ignoreCase = true) ||
            Build.MODEL.contains("Emulator", ignoreCase = true) ||
            Build.MODEL.contains("Android SDK built for x86", ignoreCase = true) ||
            Build.HARDWARE.contains("goldfish", ignoreCase = true) ||
            Build.HARDWARE.contains("ranchu", ignoreCase = true) ||
            (Build.BRAND.startsWith("generic", ignoreCase = true) &&
                Build.DEVICE.startsWith("generic", ignoreCase = true))

    val enableBackdrop = userPrefs.themeStyle == AppThemeStyle.LIQUID_GLASS && !isProbablyEmulator

    val backdrop = if (enableBackdrop) {
        rememberLayerBackdrop(graphicsLayer = rememberGraphicsLayer()) {
            drawRect(Color.White)
            drawContent()
        }
    } else {
        null
    }

    val glassParams = LiquidGlassParams(
        blurRadiusDp = userPrefs.glassBlurRadiusDp,
        refractionHeightDp = userPrefs.glassRefractionHeightDp,
        refractionAmountDp = userPrefs.glassRefractionAmountDp,
        tintAlpha = userPrefs.glassTintAlpha,
        borderAlpha = userPrefs.glassBorderAlpha,
        vibrancyEnabled = userPrefs.glassVibrancyEnabled,
        chromaticAberration = userPrefs.glassChromaticAberration
    )

    ProvideLiquidGlass(backdrop = backdrop, params = glassParams) {
        LiquidBackground(
            backdrop = backdrop,
            themeStyle = userPrefs.themeStyle,
            customWallpaperUri = userPrefs.customWallpaperUri
        ) {
            Scaffold(
                bottomBar = { BottomNavigationBar(navController) },
                containerColor = Color.Transparent,
                contentWindowInsets = WindowInsets(0, 0, 0, 0)
            ) { innerPadding ->
                Box(
                    modifier = Modifier
                        .padding(innerPadding)
                        .statusBarsPadding()
                ) {
                    NavGraph(
                        navController = navController,
                        startDestination = if (isFirstLaunch) "welcome" else "home",
                        onOnboardingComplete = { viewModel.completeOnboarding() }
                    )
                }
            }
        }
    }
}
