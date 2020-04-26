/* -*- tab-width: 4 -*- */

/*
  Copyright 2018-2020 Michalis Kamburelis.

  This file is part of "Castle Game Engine".

  "Castle Game Engine" is free software; see the file COPYING.txt,
  included in this distribution, for details about the copyright.

  "Castle Game Engine" is distributed in the hope that it will be useful,
  but WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.

  ----------------------------------------------------------------------------
*/

package net.sourceforge.castleengine;

import android.app.Activity;
import android.util.Log;
import android.content.pm.PackageManager;
import android.content.pm.PackageManager.NameNotFoundException;
import android.content.pm.PackageInfo;
import android.os.Build;

import com.gameanalytics.sdk.*;

/**
 * Game Analytics (http://www.gameanalytics.com/)
 * integration with Castle Game Engine Android application.
 */
public class ServiceGameAnalytics extends ServiceAbstract
{
    private static final String CATEGORY = "ServiceGameAnalytics";
    // Enable log when implementing the SDK - remember to turn it off in production!
    // Watch by "adb logcat | grep --text -i gameanalytics"
    private final boolean debug = false;

    private boolean initialized;

    public ServiceGameAnalytics(MainActivity activity)
    {
        super(activity);
    }

    public String getName()
    {
        return "game-analytics";
    }

    /**
     * Initialize the integration. Pass gameKey and secretKey that should
     * be passed to GameAnalytics.initializeWithGameKey method ---
     * you should generate
     * these values when creating new game in your gameanalytics.com panel.
     */
    private void initialize(String gameKey, String secretKey)
    {
        // Set build version
        PackageManager manager = getActivity().getPackageManager();
        String version;
        try {
            PackageInfo info = manager.getPackageInfo(getActivity().getPackageName(), 0);
            version = info.versionName;
        } catch (NameNotFoundException e) {
            version = "unknown (NameNotFoundException)";
        }
        version = "android " + version;
        GameAnalytics.configureBuild(version);

        // Enable log
        if (debug) {
            GameAnalytics.setEnabledInfoLog(true);
            GameAnalytics.setEnabledVerboseLog(true);
        }

        // Initialize
        GameAnalytics.initializeWithGameKey(getActivity(), gameKey, secretKey);

        logInfo(CATEGORY, "GameAnalytics initialized with application version " + version);

        initialized = true;
    }

    @Override
    public void onResume()
    {
        if (!initialized) {
            return;
        }
    }

    @Override
    public void onPause()
    {
        if (!initialized) {
            return;
        }
    }

    @Override
    public void onStop()
    {
        if (!initialized) {
            return;
        }
    }

    private void sendScreenView(String screenName)
    {
        if (!initialized) {
            return;
        }
        GameAnalytics.addDesignEventWithEventId("screenView:" + screenName);
    }

    private void sendEvent(String category, String action, String label,
        long value, int dimensionIndex, String dimensionValue)
    {
        if (!initialized) {
            return;
        }
        String id = category + ":" + action + ":" + label;
        if (dimensionIndex > 0 && !dimensionValue.equals("")) {
            id = id + ":dimension" + dimensionIndex + "." + dimensionValue;
        }
        GameAnalytics.addDesignEventWithEventId(id, (float)value);
    }

    private void sendTiming(String category, String variable,
        String label, long timeMiliseconds)
    {
        if (!initialized) {
            return;
        }
        GameAnalytics.addDesignEventWithEventId(
            "timing:" + category + ":" + variable + ":" + label, (float)timeMiliseconds);
    }

    private void sendProgress(int status, String world, String level, String phase, int score)
    {
        if (!initialized) {
            return;
        }
        GAProgressionStatus gaStatus;
        switch (status) {
            case 0: gaStatus = GAProgressionStatus.Start; break;
			case 1: gaStatus = GAProgressionStatus.Fail; break;
			case 2: gaStatus = GAProgressionStatus.Complete; break;
            default:
                logWarning(CATEGORY, "Invalid analytics-send-progress status " + status);
                return;
        }
        GameAnalytics.addProgressionEventWithProgressionStatus(gaStatus, world, level, phase, score);
    }

    @Override
    public void onPurchase(AvailableProduct product, String purchaseData, String signature)
    {
        if (!initialized) {
            return;
        }
        // https://github.com/GameAnalytics/GA-SDK-ANDROID/wiki/Business-Event
        // http://www.gameanalytics.com/docs/ga-data

        // for GameAnalytics, currency must be valid
        String currency = product.priceCurrencyCode;
        if (currency == null || currency.equals("")) {
            currency = "USD";
        }

        // for GameAnalytics, category must be valid:
        // Cannot be (null), empty or above 64 characters
        String category = product.category;
        if (category == null || category.equals("")) {
            category = "defaultProductCategory";
        }
        if (category.length() > 64) {
            category = category.substring(0, 64);
        }

        int priceAmountCents = (int) (product.priceAmountMicros / 10000.0);

        GameAnalytics.addBusinessEventWithCurrency(
            currency, priceAmountCents, category,
            product.id, "defaultCart", purchaseData, "google_play", signature);
    }

    @Override
    public boolean messageReceived(String[] parts)
    {
        if (parts.length == 3 && parts[0].equals("game-analytics-initialize")) {
            initialize(parts[1], parts[2]);
            return true;
        } else
        if (parts.length == 2 && parts[0].equals("analytics-send-screen-view")) {
            sendScreenView(parts[1]);
            return true;
        } else
        if (parts.length == 7 && parts[0].equals("analytics-send-event")) {
            sendEvent(parts[1], parts[2], parts[3], Long.parseLong(parts[4]), Integer.parseInt(parts[5]), parts[6]);
            return true;
        } else
        if (parts.length == 5 && parts[0].equals("analytics-send-timing")) {
            sendTiming(parts[1], parts[2], parts[3], Long.parseLong(parts[4]));
            return true;
        } else
        if (parts.length == 6 && parts[0].equals("analytics-send-progress")) {
            sendProgress(Integer.parseInt(parts[1]), parts[2], parts[3], parts[4], Integer.parseInt(parts[5]));
            return true;
        } else
        {
            return false;
        }
    }
}
