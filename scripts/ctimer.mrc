/*
 ** ctimer module - Version 0.1.0
 **
 ** Requires the functions.mrc module by Sierra
 **
 ** Provides a timer system for mIRC/mSL with more functionality and ease of use features than the
 **     built in /timer commands.
 ** This module makes use of hash tables and .ini files, and a single /timer command running every N
 **     seconds, where N is a configurable number. The module can also be configured to run this
 **     single master timer as a high-resolution multimedia timer if desired. See the mIRC
 **     documentation on the /timer command for details.
 ** The master timer is the only usage of the built in /timer command by this module, and is used to
 **     repetitively process all active ctimers without running a neverending while() loop that can
 **     cause mIRC to hang or crash. Each time the master timer is triggered, the module checks and
 **     compares every active ctimer's ctime entry (The next time the timer is supposed to be
 **     triggered) with the current output of $ctime. Any cases where $ctime exceeds or equals this
 **     value, the ctimer is question is triggered.
 **
 ** NOTE: The full functionality of scope isn't actually programmed yet; This parameter will have no
 **     effect on new timers at this time.
 **
 ** Author: Sierra "SierraKomodo" Brown - http://github.com/sierrakomodo
 */

alias -l VERSION return 0.1.0
alias -l CONFIG_FILE_PATH return config\ctimer.ini
alias -l CONFIG_HASH_PATH return ctimer.config
alias -l TIMER_FILE_PATH return config\ctimer_timers.ini
alias -l TIMER_HASH_PATH return ctimer.timers


on *:START: {
    ;; Pre-start cleanup
    timerctimer.MasterClock off
    if ($hget($CONFIG_HASH_PATH)) {
        hfree $CONFIG_HASH_PATH
    }
    if ($hget($TIMER_HASH_PATH)) {
        hfree $TIMER_HASH_PATH
    }
    var %masterHashPath = $TIMER_HASH_PATH $+ . $+ master
    if ($hget(%masterHashPath)) {
        hfree %masterHashPath
    }
    unset %ctimerLastError
    
    
    ;; Fetch configuration data
    ; Create default config entries
    if ($file(config) == $null) {
        mkdir config
    }
    defaultini $CONFIG_FILE_PATH config iMasterTimerInterval 5
    defaultini $CONFIG_FILE_PATH config bUseHighResolutionTimer 0
    
    ; Create the hashtable for config entries
    hmake $CONFIG_HASH_PATH 10
    hload -i $CONFIG_HASH_PATH $CONFIG_FILE_PATH config
    
    
    ;; Create and load hashtable for ctimer entries
    hmake $TIMER_HASH_PATH 100
    hmake %masterHashPath 10
    hload -i %masterHashPath $TIMER_FILE_PATH master
    
    var %count = 1
    while (%count <= $hfind(%masterHashPath, *, 0, w)) {
        var %timerName = $hfind(%masterHashPath, *, %count, w)
        
        noop $ctimer.NewTimer(%timerName, $readini($TIMER_FILE_PATH, n, %timerName, commands), $readini($TIMER_FILE_PATH, n, %timerName, interval), $readini($TIMER_FILE_PATH, n, %timerName, repetitions), $readini($TIMER_FILE_PATH, n, %timerName, scope), $readini($TIMER_FILE_PATH, n, %timerName, network), $true)
        
        inc %count
    }
    
    
    ;; Create the master clock timer
    var %params = o
    var %time = $hget($CONFIG_HASH_PATH, iMasterTimerInterval)
    
    ; High resolution timer option
    if ($hget($CONFIG_HASH_PATH, bUseHighResolutionTimer) == 1) {
        var %params = %params $+ h
        ; High resolution timers use millisecond instead of second counters
        var %time = $calc(%time * 1000)
    }
    
    ; Run the /timer command
    timerctimer.MasterClock - [ $+ [ %params ] ] 0 %time ctimer.ClockCycle
}


/**
 ** Method that executes active timers
 */
alias ctimer.ClockCycle {
    var %count = 1
    while (%count <= $hfind($TIMER_HASH_PATH, *, 0, w)) {
        var %timerName = $hfind($TIMER_HASH_PATH, *, %count, w)
        var %timerHashPath = $TIMER_HASH_PATH $+ . $+ %timerName
        
        ; Skip paused timers
        if ($hget(%timerHashPath, paused) == $true) {
            goto :next
        }
        
        ; Check execution ctime, compare against current ctime
        if ($ctime >= $hget(%timerHashPath, ctime)) {
            ; Fetch commands in case the timer is 'stopped' below
            var %commands = $hget(%timerHashPath, commands)
            
            ; Check for repetitions
            if ($hget(%timerHashPath, repetitions) > 0) {
                if ($hget(%timerHashPath, repetitions) == 1) {
                    if ($hget(%timerHashPath, offline) == $true) {
                        remini $TIMER_FILE_PATH %timerName
                        remini $TIMER_FILE_PATH master %timerName
                    }
                    
                    hfree %timerHashPath
                    hdel $TIMER_HASH_PATH %timerName
                }
                else {
                    hadd %timerHashPath repetitions $calc($v1 - 1)
                    hadd %timerHashPath ctime $calc($ctime + $hget(%timerHashPath, interval))
                    
                    if ($hget(%timerHashPath, offline) == $true) {
                        hsave -i %timerHashPath $TIMER_FILE_PATH %timerName
                    }
                }
            }
            
            ; Execute commands
            [ [ %commands ] ]
        }
        
        :next
        inc %count
    }
}


/**
 ** Method used to create a new timer
 **
 ** NOTE: The full functionality of scope isn't actually programmed yet; This parameter will have no
 **     effect on new timers at this time.
 **
 ** string  %parTimerName           The internal name to use for this timer
 ** string  %parTimerCommands       The command(s) to be run by this timer. Separate individual
 **                                     commands with a pipe (|)
 ** int     %parTimerInterval       The amount of time in seconds the timer should wait. Must be a
 **                                     non-negative integer.
 ** int     %parTimerRepetitions    The number of times the timer should repeat. 0 means
 **                                     indefinitely. Must be a non negative integer.
 ** enum    %parTimerScope          One of 'g' or 'n'. 'g' means the timer is considered 'global'
 **                                     and will continue to be processed even if disconnected from
 **                                     the network the command was run from (Equivalent to the -o
 **                                     flag in the /timer command), 'n' means the timer is specific
 **                                     to a network.
 ** bool    %parTimerOffline        If $true, the timer will be stored when mIRC goes offline (For
 **                                     scope 'n'), or shuts down (For scope 'g') and reloaded on
 **                                     reconnect/restart (Scopes 'n'/'g' respectively). Reloaded
 **                                     timers are checked against the current $ctime, and executed
 **                                     if the timer's command(s) should have been executed prior to
 **                                     being reloaded.
 */
alias ctimer.NewTimer {
    var %parTimerName        = $1
    var %parTimerCommands    = $2
    var %parTimerInterval    = $3
    var %parTimerRepetitions = $iif($4, $4, 1)
    var %parTimerScope       = $iif($5, $5, n)
    var %parTimerNetwork     = $iif($6, $6, $network)
    var %parTimerOffline     = $iif($7, $7, $false)
    
    
    ;; Validation
    if ($hget($TIMER_HASH_PATH, %parTimerName) != $null) {
        var -g %ctimerLastError = Unable to create new timer: Timer named $qt(%parTimerName) already exists
        return $false
    }
    if ($hget($TIMER_HASH_PATH, %parTimerName) == master) {
        var -g %ctimerLastError = Unable to create new timer: Timer name $qt(%parTimerNamer) is reserved for internal use
        return $false
    }
    
    
    ;; Generate the hash table entries
    var %timerPath = $TIMER_HASH_PATH $+ . $+ %parTimerName
    if ($hget(%timerPath)) {
        hfree %timerPath
    }
    hmake %timerPath 10
    hadd %timerPath name %parTimerName
    hadd %timerPath commands %parTimerCommands
    hadd %timerPath interval %parTimerInterval
    hadd %timerPath repetitions %parTimerRepetitions
    hadd %timerPath scope %parTimerScope
    hadd %timerPath offline %parTimerOffline
    hadd %timerPath network %parTimerNetwork
    hadd %timerPath cid $cid
    hadd %timerPath paused $false
    hadd %timerPath ctime $calc($ctime + %parTimerInterval)
    
    hadd $TIMER_HASH_PATH %parTimerName %parTimerName
    
    
    ;; Create offline timer entry
    if (%parTimerOffline == $true) {
        var %timerHashPath = $TIMER_HASH_PATH $+ . $+ %parTimerName
        
        writeini $TIMER_FILE_PATH master %parTimerName %parTimerName
        hsave -i %timerHashPath $TIMER_FILE_PATH %parTimerName
    }
    
    
    return $true
}


/**
 ** Method used to delete an existing timer
 **
 ** string  %parTimerName   The name of the timer to delete
 */
alias ctimer.DeleteTimer {
    var %parTimerName = $1
    var %timerPath = $TIMER_HASH_PATH $+ . $+ %parTimerName
    
    
    if ($hget($TIMER_HASH_PATH, %parTimerName) != $null) {
        hdel $TIMER_HASH_PATH %parTimerName
    }
    
    if ($hget(%timerPath) != $null) {
        hfree %timerPath
    }
    
    return $true
}
