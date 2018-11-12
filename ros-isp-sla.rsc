#
# Primary ISP default route should be set to AD = 4
# Secondary ISP default route should be set to AD = 6
#
# Vars:
# gwPrimary - Primary ISP gateway ip address
# gwSecondary - Secondary ISP gateway ip address
# gwSecondaryAD - Secondary ISP gateway route distance
# gwFailoverAD - Failover AD distance. We change default route to secondary ISP by rising 0.0.0.0/0 distance
# succPings - Amount of successful pings returned in ping check
# probes - Amount of pings sent to check gateway reliability
# threshold - if successfull amount of pings is less than threshold value - try to switch to secondary ISP

:local gwPrimary 86.0.0.1;
:local gwSecondary 152.0.0.1;
:local gwSecondaryAD 6;
:local gwFailoverAD 2;
:local succPings 0;
:local probes 10;
:local threshold 8;

# check, if routes exists --------------------------------------------------------------------
:local gwPrimaryExists ([/ip route print as-value where dst-address=0.0.0.0/0 gateway=$gwPrimary])
:local gwSecondaryExists ([/ip route print as-value where dst-address=0.0.0.0/0 gateway=$gwSecondary])

:put "---  ---> Checking if default routes exists";
# check primary ISP default route
:put "---  ---> Checking primary default route exists";
:if ([:len $gwPrimaryExists] > 0) do={
    :put "> OK ---> Primary default route exists";
} else={
    :put "> Fail -> Primary default route does not exists. Exiting.";
    :log error "Script: Fail. Primary default route does not exists. Exiting.";
    :error "Primary default route does not exists. Exiting.";
}

# check secondary ISP default route
:put "---  ---> Checking secondary default route exists";
:if ([:len $gwSecondaryExists] > 0) do={
    :put "> OK ---> Secondary default route exists";
} else={
    :put "> Fail -> Secondary default route does not exists. Exiting.";
    :log error "Script: Fail. Secondary default route does not exists. Exiting.";
    :error "Secondary default route does not exists. Exiting.";
}

# check, if routes are enabled (not disabled)------------------------------------------------------
:local gwPrimaryEnabled ([/ip route print as-value where  dst-address=0.0.0.0/0 gateway=$gwPrimary disabled =no])
:local gwSecondaryEnabled ([/ip route print as-value where  dst-address=0.0.0.0/0 gateway=$gwSecondary disabled =no])

:put "---  ---> Checking default routes are not disabled";
# check primary ISP default route is enabled
:put "---  ---> Checking primary default route is not disabled";
:if ([:len $gwPrimaryEnabled] > 0) do={
    :put "> OK ---> Primary default route is enabled";
} else={
    :put "> Fail -> Primary default route is disabled. Exiting.";
    :log error "Script: Fail. Primary default route is disabled. Exiting.";
    :error "Primary default route is disabled. Exiting.";
}

# check secondary ISP default route is enabled
:put "---  ---> Checking primary default route is not disabled";
:if ([:len $gwSecondaryEnabled] > 0) do={
    :put "> OK ---> Secondary default route is enabled";
} else={
    :put "> Fail -> Secondary default route is disabled. Exiting.";
    :log error "Script: Fail. Secondary default route is disabled. Exiting.";
    :error "Secondary default route is disabled. Exiting.";
}

# running primary ISP ping check ---------------------------------------------------------------
:put "---  ---> Checking Primary ISP quality:"
# returns successful amount of probes
:set succPings ([/ping $gwPrimary ttl=1 count=$probes])
:put ("---  ---> Got: " . $succPings . " pings of: " . $probes)

# if passed pings amount count is less than threshold, switch to secondary ISP
:if ($succPings<$threshold) do={
    :put ("---  ---> Successful amount of pings is: " . $succPings . " < than threshold of: " . $threshold);

    # checking secondary ISP quality
    :put ("---  ---> Checking Secondary ISP quality")
    :local succPingsSecondary ([/ping $gwSecondary ttl=1 count=$probes])
    # if secondary ISP successful pings are under threshold, stay on Primary ISP
    :if ($succPingsSecondary<$threshold) do={
        :put ("---  ---> Secondary ISP quality is worst than Primary")
        :put ("---  ---> Switching to Secondary ISP Canceled!")
        :put ("---  ---> Sent = " . $probes . ", Received = " . $succPingsSecondary)
        :log error ("Switching to secondary ISP Canceled! Sent = " . $probes . ", Received = " . $succPingsSecondary)
        :error ("Switching to secondary ISP Canceled! Sent = " . $probes . ", Received = " . $succPingsSecondary);
    } else={
        # check if secondary isp is already active
        :local gatewaySecondaryParams ([/ip route print as-value where dst-address=0.0.0.0/0 gateway=$gwSecondary])
        :if ($gatewaySecondaryParams->0->"distance" = $gwFailoverAD) do={
            :put "> OK ---> Already running on Secondary ISP";
            :log info ("Primary ISP Fail! Running on Secondary ISP!")
        # increase secondary gateway distance
        } else={
            [/ip route set distance=$gwFailoverAD [find gateway=$gwSecondary]]
            :put "Switched to Secondary ISP!"
            :log warning ("Primary ISP Fail! Switched to Secondary ISP!")
        }
    }
# Primary ISP is Ok
} else={
    :put "> OK ---> Primary ISP is OK"
    :local gatewaySecondaryParams ([/ip route print as-value where dst-address=0.0.0.0/0 gateway=$gwSecondary])
    # check if secondary ISP route has its default distance
    :if ($gatewaySecondaryParams->0->"distance" = $gwSecondaryAD) do={
        :put "Ok. Secondary ISP has its default distance.";
    # else set it to default value
    } else={
        :put "---  ---> Switching to Primary ISP"
        [/ip route set distance=$gwSecondaryAD [find dst-address=0.0.0.0/0 gateway=$gwSecondary]]
        :put "> OK ---> Switched back to Primary ISP!"
        :log info ("Switched back to Primary ISP!")
    }
} 