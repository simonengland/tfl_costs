 <#
.SYNOPSIS
    This script calculates the theoretical cost of a journey on TFL from a journey history CSV.
.DESCRIPTION
    Journey history from TFL does not contain the cost if you have a season ticket. This script takes the journey information, and queries the TFL API to find that cost if you did not have a season ticket.
.INPUTS
    TFL journey history CSV in .\input
.OUTPUTS
    Annotated journey history CSV in .\output
.NOTES
    Author: Simon England
    Last Edit: 2019-10-14
    Version: 1.0
    Version 0.9 - 2019-07-02 Initial script development
    Version 1.0 - 2019-10-14 Usable script
#>

# Input CSV headers
#     Date,Start Time,End Time,Journey/Action,Charge,Credit,Balance,Note
# Journey/Action possible values
#     Station to Station
#                [no touch out]
#             [], ()
#     Bus Journey..
#     Entered and exited...
#     Season ticket added...
#     Auto top-up...

# Import module.
Import-Module -Name '.\tfl_fun.psm1'

# Import parameters
$Params = Get-Content '.\params.json' | ConvertFrom-Json

# Initilise
$BadSearch = $False
$TFLRequestsPerMinute = $Params.max_requests_minute
$TFLRequests = 0
$QueryStart = Get-Date

# Location of CSV files
$FileLocation = '.\input\'
$ExportCSV = '.\output\tfl_costs.csv'
$Results = @()

# Set security protocol so Invoke-WebRequest works.
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

# API parameters
$AppID = $Params.app_id
$AppKey = $Params.app_key
$QueryAppend = 'app_id=' + $AppID + '&app_key=' + $AppKey

# TFL variables
$BusCharge = $Params.bus_cost
$PeakMornStart = [datetime]::parseexact($Params.times.peak_morn_start, 'HH:mm', $null)
$PeakMornEnd = [datetime]::parseexact($Params.times.peak_morn_end, 'HH:mm', $null)
$PeakEveStart = [datetime]::parseexact($Params.times.peak_eve_start, 'HH:mm', $null)
$PeakEveEnd = [datetime]::parseexact($Params.times.peak_eve_end, 'HH:mm', $null)

# Bank holidays
$BankHolidays = Invoke-WebRequest -uri 'https://www.gov.uk/bank-holidays.json' | ConvertFrom-Json

# Recurse through CSV files.
Get-ChildItem -Path $FileLocation* -Include *.csv | Foreach-Object {
    $FileName = $_.FullName
    # Skip first line.
    While ((Get-Content $FileName -First 1) -eq '') {
        (Get-Content $FileName | Select-Object -Skip 1) | Set-Content $FileName
    }
    $Data = Import-Csv -Path $FileName
    For ($i = 0; $i -lt $Data.length; $i++) {
        $JourneyAction = $Data[$i].'Journey/Action'
        If ($JourneyAction.Substring(0, 3) -eq 'Bus') {
            $TheoCharge = $BusCharge
            $StartLoc = ''
            $EndLoc = ''
        } Elseif ($JourneyAction.Substring(1, 8) -eq 'No touch') {
            $TheoCharge = 0
            $StartLoc = ''
            $EndLoc = ''
        } Elseif ($JourneyAction.Substring(0, 7) -eq 'Entered') {
            $TheoCharge = 0
            $StartLoc = ''
            $EndLoc = ''
        } Elseif ($JourneyAction.Substring(0, 13)-eq 'Season ticket') {
            $TheoCharge = 0
            $StartLoc = ''
            $EndLoc = ''
        } Elseif ($JourneyAction.Substring(0, 8) -eq 'Auto top') {
            $TheoCharge = 0
            $StartLoc = ''
            $EndLoc = ''
        } Else {
            $Split = $JourneyAction.IndexOf(' to ')
            $StartLoc = $JourneyAction.Substring(0, $Split)
            $StartLoc = Format-StationName -Name $StartLoc
            $EndLoc = $JourneyAction.Substring($Split + 4)
            If ($EndLoc.length -gt 8) {
                If ($EndLoc.Substring(1, 8) -eq 'no touch') {
                    $BadSearch = $True
                }
            }
            $EndLoc = Format-StationName -Name $EndLoc
            Write-Host $StartLoc
            Write-Host $EndLoc
            If (!$BadSearch) {
                $Uri1 = 'https://api.tfl.gov.uk/StopPoint/Search?query=' + $StartLoc + '&modes=tube,overground,dlr&' + $QueryAppend
                if (Test-TFLRequestLimit -Requests $TFLRequests -MaxRequests $TFLRequestsPerMinute -StartTime $QueryStart) {
                    $QueryStart = Get-Date
                    $TFLRequests = 0
                }
                $ResponseStation1 = Invoke-WebRequest -uri $Uri1 | ConvertFrom-Json
                $TFLRequests++
                If (($ResponseStation1.total -eq 1) -or ($ResponseStation1.matches[0].name -eq $StartLoc)) {
                    $Station1 = $ResponseStation1.matches[0].id
                    If ($Station1.Substring(0,3) -eq 'HUB') {
                        if (Test-TFLRequestLimit -Requests $TFLRequests -MaxRequests $TFLRequestsPerMinute -StartTime $QueryStart) {
                            $QueryStart = Get-Date
                            $TFLRequests = 0
                        }
                        $Station1 = Find-HubTubeID -Station $Station1 -AppID $AppID -AppKey $AppKey
                        $TFLRequests++
                    }
                    $Uri2 = 'https://api.tfl.gov.uk/StopPoint/Search?query=' + $EndLoc + '&modes=tube,overground,dlr&' + $QueryAppend
                    if (Test-TFLRequestLimit -Requests $TFLRequests -MaxRequests $TFLRequestsPerMinute -StartTime $QueryStart) {
                        $QueryStart = Get-Date
                        $TFLRequests = 0
                    }
                    $ResponseStation2 = Invoke-WebRequest -uri $Uri2 | ConvertFrom-Json
                    $TFLRequests++
                    If (($ResponseStation2.total -eq 1) -or ($ResponseStation2.matches[0].name -eq $EndLoc)) {
                        $Station2 = $ResponseStation2.matches[0].id
                        If ($Station2.Substring(0,3) -eq 'HUB') {
                            if (Test-TFLRequestLimit -Requests $TFLRequests -MaxRequests $TFLRequestsPerMinute -StartTime $QueryStart) {
                                $QueryStart = Get-Date
                                $TFLRequests = 0
                            }
                            $Station2 = Find-HubTubeID -Station $Station2 -AppID $AppID -AppKey $AppKey
                            $TFLRequests++
                        }
                        $Uri3 = 'https://api.tfl.gov.uk/Stoppoint/' + $Station1 + '/FareTo/' + $Station2 + '?' + $QueryAppend
                        Write-Host $Uri3
                        if (Test-TFLRequestLimit -Requests $TFLRequests -MaxRequests $TFLRequestsPerMinute -StartTime $QueryStart) {
                            $QueryStart = Get-Date
                            $TFLRequests = 0
                        }
                        $ResponseJourney = Invoke-WebRequest -uri $Uri3 | ConvertFrom-Json
                        $TFLRequests++
                        Write-Host $Data[$i].Date
                        $Date = [datetime]::parseexact($Data[$i].Date, 'dd-MMM-yyyy', $null)
                        If (($Date.DayOfWeek.value -eq 0) -OR ($Date.DayOfWeek.value -eq 6)) {
                            $TicketType = 'OffPeak'
                        } Else {
                            $BHCheck = $False
                            $k = 0;
                            While (!$BHCheck -AND ($k -lt $BankHolidays.'england-and-wales'.events.length)) {
                                $BH =[datetime]::parseexact($BankHolidays.'england-and-wales'.events[$k].date, 'yyyy-MM-dd', $null)
                                If ($Date -eq $BH) {
                                    $BHCheck = $True
                                }
                                $k++
                            }
                            If ($BHCheck) {
                                $TicketType = 'OffPeak'
                            } Else {
                                $StartTime = [datetime]::parseexact($Data[$i].'Start Time', 'HH:mm', $null)
                                $EndTime = [datetime]::parseexact($Data[$i].'End Time', 'HH:mm', $null)
                                $PeakMorn = ($StartTime -ge $PeakMornStart -AND $StartTime -le $PeakMornEnd) -OR ($EndTime -ge $PeakMornStart -AND $EndTime -le $PeakMornEnd)
                                $PeakEve = ($StartTime -ge $PeakEveStart -AND $StartTime -le $PeakEveEnd) -OR ($EndTime -ge $PeakEveStart -AND $EndTime -le $PeakEveEnd)
                                If ($PeakMorn -OR $PeakEve) {
                                    $TicketType = 'Peak'
                                } Else {
                                    $TicketType = 'OffPeak'
                                }
                            }
                        }
                        $TheoCharge = Find-JourneyCost -Type $TicketType -Journey $ResponseJourney
                        Write-Host $TheoCharge
                        Write-Host $BadSearch
                    } Else {
                        $BadSearch = $True
                    }
                } Else {
                    $BadSearch = $True
                }
            }
        }
        If ($BadSearch) {
            $TheoCharge = 0
            $StartLoc = ''
            $EndLoc = ''
        }
        $NewLineProperties = [ordered]@{
            Date = $Data[$i].'Date'
            StartTime = $Data[$i].'Start Time'
            EndTime = $Data[$i].'End Time'
            JourneyAction = $Data[$i].'Journey/Action'
            Charge = $Data[$i].'Charge'
            Credit = $Data[$i].'Credit'
            Balance =$Data[$i].'Balance'
            Note = $Data[$i].'Note'
            Start = $StartLoc
            End = $EndLoc
            TheoCharge = $TheoCharge
        }
        $Results += New-Object PSObject -Property $NewLineProperties

        # Reset
        Clear-Variable TheoCharge
        Clear-Variable JourneyAction
        $BadSearch = $False
    }
    $Results | Export-Csv -Path $ExportCSV -NoTypeInformation
}
    