package com.rewise.spaced.learning

import android.content.Intent
import android.os.Bundle
import com.rewise.spaced.learning.managers.UpdateManager
import com.rewise.spaced.learning.managers.PaymentManager
import com.rewise.spaced.learning.managers.AdManager
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {
    private lateinit var updateManager: UpdateManager
    private lateinit var paymentManager: PaymentManager
    private lateinit var adManager: AdManager

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        
        // 1. Initialize Managers
        updateManager = UpdateManager(this)
        paymentManager = PaymentManager(this)
        adManager = AdManager(this)

        // 2. Trigger active policies
        updateManager.checkForAppUpdate()
        
        // FUTURE: Activate when billing and ads are fully wired up
        // paymentManager.initialize()
        // adManager.initialize()
    }

    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        // Delegate to UpdateManager to handle rejection/fallback
        updateManager.handleActivityResult(requestCode, resultCode, data)
    }

    override fun onResume() {
        super.onResume()
        // Delegate to UpdateManager to restore abandoned updates
        updateManager.onResume()
    }
}
