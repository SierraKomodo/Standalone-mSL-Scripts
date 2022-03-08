alias ctimeToReadable {
    var %seconds = $1
    
    
    ; Minutes
    var %minutes = 0
    if (%seconds >= 60) {
        var %minutes = $floor($calc(%seconds / 60))
        var %seconds = $calc(%seconds % 60)
    }
    
    ; Hours
    var %hours = 0
    if (%minutes >= 60) {
        var %hours = $floor($calc(%minutes / $v2))
        var %minutes = calc(%minutes % $v2)
    }
    
    ; Days
    var %days = 0
    if (%hours >= 60) {
        var %days = $floor($calc(%hours / $v2))
        var %hours = calc(%hours % $v2)
    }
    
    ; Months
    var %months = 0
    if (%days >= 60) {
        var %months = $floor($calc(%days / $v2))
        var %days = calc(%days % $v2)
    }
    
    ; Years
    var %years = 0
    if (%months >= 60) {
        var %years = $floor($calc(%months / $v2))
        var %months = calc(%months % $v2)
    }
    
    
    var %return = $null
    var %multiple = $false
    if (%years > 0) {
        if (%multiple == $false) {
            var %return = %years year $+ $iif(%years > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %years year $+ $iif(%years > 1, s)
        }
    }
    if (%months > 0) {
        if (%multiple == $false) {
            var %return = %months month $+ $iif(%months > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %months month $+ $iif(%months > 1, s)
        }
    }
    if (%days > 0) {
        if (%multiple == $false) {
            var %return = %days day $+ $iif(%days > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %days day $+ $iif(%days > 1, s)
        }
    }
    if (%hours > 0) {
        if (%multiple == $false) {
            var %return = %hours hour $+ $iif(%hours > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %hours hour $+ $iif(%hours > 1, s)
        }
    }
    if (%minutes > 0) {
        if (%multiple == $false) {
            var %return = %minutes minute $+ $iif(%minutes > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %minutes minute $+ $iif(%minutes > 1, s)
        }
    }
    if (%seconds > 0) {
        if (%multiple == $false) {
            var %return = %seconds second $+ $iif(%seconds > 1, s)
            var %multiple = $true
        }
        else {
            var %return = %return $+ $chr(44) %seconds second $+ $iif(%seconds > 1, s)
        }
    }
    
    
    return $iif(%return != $null, %return, 0 seconds)
}


alias readableToCtime {
    var %num = $null
    var %ctime = 0
    
    var %count = 1
    while (%count <= $len($1)) {
        var %char = $right($left($1, %count), 1)
        
        if (%char isnum) {
            var %num = %num $+ %char
        }
        else {
            if (%char === y) {
                inc %ctime $calc(%num * 31536000)
            }
            elseif (%char === M) {
                inc %ctime $calc(%num * 2592000)
            }
            elseif (%char === w) {
                inc %ctime $calc(%num * 604800)
            }
            elseif (%char === d) {
                inc %ctime $calc(%num * 86400)
            }
            elseif (%char === h) {
                inc %ctime $calc(%num * 3600)
            }
            elseif (%char === m) {
                inc %ctime $calc(%num * 60)
            }
            elseif (%char === s) {
                inc %ctime %num
            }
            
            var %num = $null
        }
        
        inc %count
    }
    
    return %ctime
}


; /defaultini -n <filename> <section> <key> <default value>
; $defaultini([nNP], <filename>, <section>, <key>, <default value>)
alias defaultini {
    var %flagsWrite = $null
    var %flagsRead = $null
    var %fileName = $null
    var %iniSection = $null
    var %iniKey = $null
    var %defaultValue = $null
    
    
    ;; Parameters
    if ($isid == $true) {
        if (N isincs $1) {
            var %flagsRead = %flagsRead $+ n
        }
        if (P isincs $1) {
            var %flagsRead = %flagsRead $+ p
        }
        if (n isincs $1) {
            var %flagsWrite = %flagsWrite $+ n
        }
        
        var %fileName = $2
        var %iniSection = $3
        var %iniKey = $4
        var %defaultValue = $5
    }
    else {
        var %i = 1
        
        ; Check for flags
        if ($left([ $ [ $+ [ %i ] ] ], 1) == -) {
            if (n isincs $1) {
                var %flagsWrite = %flagsWrite $+ n
            }
            
            inc %i
        }
        
        var %fileName = [ $ [ $+ [ %i ] ] ]
        inc %i
        var %iniSection = [ $ [ $+ [ %i ] ] ]
        inc %i
        var %iniKey = [ $ [ $+ [ %i ] ] ]
        inc %i
        var %defaultValue = [ $ [ $+ [ %i ] $+ - ] ]
    }
    
    
    ;; Fetch and compare current value
    if ($readini(%fileName, %iniSection, %iniKey) == $null) {
        writeini $iif(%flagsWrite, - $+ %flagsWrite) %fileName %iniSection %iniKey %defaultValue
    }
    
    if ($isid == $true) {
        if (%flagsRead != $null) {
            return $readini(%fileName, %flagsRead, %iniSection, %iniKey)
        }
        else {
            return $readini(%fileName, %iniSection, %iniKey)
        }
    }
}


; /dumphash <hashtable> [@window]
alias dumphash {
    var %parHashTable = $1
    var %parWindow = $2
    
    var %count = 1
    while (%count <= $hfind(%parHashTable, *, 0, w)) {
        var %entryKey = $hfind(%parHashTable, *, %count, w).data
        var %entryValue = $hget(%parHashTable, %entryKey)
        
        if (%parWindow != $null) {
            echo %parWindow %count %entryKey %entryValue
        }
        else {
            echo -a HASHDUMP: %count %entryKey %entryValue
        }
        
        inc %count
    }
    
    echo -a ---
}
