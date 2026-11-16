package id.my.nabilcf.orbit_app

import android.content.Context
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.ExistingWorkPolicy
import androidx.work.NetworkType
import androidx.work.OneTimeWorkRequestBuilder
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import androidx.work.Worker
import androidx.work.WorkerParameters
import java.util.concurrent.TimeUnit

class OrbitBackgroundWorker(
    appContext: Context,
    workerParams: WorkerParameters
) : Worker(appContext, workerParams) {

    override fun doWork(): Result {
        runCatching {
            OrbitWidgetStore.updateAllWidgets(applicationContext)
        }
        return Result.success()
    }

    companion object {
        private const val PERIODIC_WORK_NAME = "orbit_periodic_widget_sync"
        private const val ONETIME_WORK_NAME = "orbit_onetime_widget_sync"

        fun schedulePeriodic(context: Context) {
            runCatching {
                val constraints = Constraints.Builder()
                    .setRequiredNetworkType(NetworkType.CONNECTED)
                    .build()

                val request = PeriodicWorkRequestBuilder<OrbitBackgroundWorker>(
                    15,
                    TimeUnit.MINUTES
                )
                    .setConstraints(constraints)
                    .build()

                WorkManager.getInstance(context).enqueueUniquePeriodicWork(
                    PERIODIC_WORK_NAME,
                    ExistingPeriodicWorkPolicy.KEEP,
                    request
                )
            }
        }

        fun enqueueOneTime(context: Context) {
            runCatching {
                val request = OneTimeWorkRequestBuilder<OrbitBackgroundWorker>().build()
                WorkManager.getInstance(context).enqueueUniqueWork(
                    ONETIME_WORK_NAME,
                    ExistingWorkPolicy.REPLACE,
                    request
                )
            }
        }
    }
}
