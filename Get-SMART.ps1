<#
.SYNOPSIS
  Run CDI and output PS Objects
.PARAMETER cdiPath
  The DiskInfo64.exe binary path
.EXAMPLE
  <>
#>

#----------[Initialisations]----------#

param (
    [Parameter(Mandatory=$True)]
    [Object]$cdiPath
)

#----------[Declarations]----------#

$outputPath = Split-Path "$cdiPath" -Parent
$binary = Split-Path "$cdiPath" -Leaf
$cdiOutput = "DiskInfo.txt"

#----------[Functions]----------#

Function runCDI {
    Set-Location $outputPath
    &  .\$binary /CopyExit
    $to = new-timespan -Seconds 30
    $sw = [diagnostics.stopwatch]::StartNew()
    While ($sw.elapsed -lt $to){
        if (Test-Path $cdiOutput){
        } Else {
            Start-Sleep -Seconds 1
        }
    }
}

Function parseOutput {
    # Get our data
    $raw = Get-Content -Raw $cdiOutput
    $splits = $raw -split "----------------------------------------------------------------------------"
    
    # Splits[0] is empty
    # Splits[1] is CDI version
    # Splits[2] is the OS info and disk list
    # Splits[3] is the first disk name
    # Splits[4] is the first disk info
    # splits[5] Repeat 3-4 from now on
    
    $report = @()
    $n = 4
    While ($n -lt $splits.Count) {
        $rawData0 = $splits[$n]
        # ID info is the top of this next split
        $rawData1 = $rawData0 -Split "-- S.M.A.R.T"
        $rawInfo = $rawData1[0]
        # One more split to isolate SMART
        $rawData2 = $rawData1 -Split "-- IDENTIFY_DEVICE"
        $rawSmart = $rawData2[1]
        
        # Organize our disk info. We combine these 3 lines into one.
        # $clean0 = $rawInfo.split([Environment]::NewLine) -Replace '^\s+',''
        # $clean1 = $clean0 | Where-Object {$_}
        # $clean2 = $clean1 -Replace ' : ',' = '
        $info = $rawInfo.split([Environment]::NewLine) -Replace '^\s+','' -Replace ' : ',' = ' | Where-Object {$_} | ConvertFrom-StringData
        
        # Get smart values into a usable state
        $smart0 = $rawSmart.split([Environment]::NewLine) | Where-Object {$_} 
        $smart1 = $smart0 | ? { $_ -ne $smart0[0] } | ? { $_ -ne $smart0[1] }
        $smart = $smart1 -Replace '(^.*)(\s[0-9A-F]{12})\s(.*)$','$3 = $2' | ConvertFrom-StringData
        
        # There are too many values to write/guess so get them with
        # $info.Keys
        # $info[0].Keys
        # $info[0].Values
        
        $inputs = $info + $smart
        $output = New-Object PSObject
        ForEach ($i in $inputs) {
            Add-Member -InputObject $output -MemberType NoteProperty -Name $i.Keys -Value $i.$($i.Keys)
        }
        $report += $output
        
        # Add 2 to get our next block
        $n = $n + 2
    }
    Return $report
}
Function cleanUp {
    Remove-Item -Force -Recurse ".\Smart",".\DiskInfo.txt",".\DiskInfo.ini" -ErrorAction SilentlyContinue
}
#----------[Execution]----------#

runcdi
parseOutput 2>$null
cleanUp
