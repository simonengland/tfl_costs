Function Format-StationName {
<#
.SYNOPSIS
    This function removes extraneous information from staion names.
.DESCRIPTION
    Powershell function to remove extraneous bracketted information from a station name, to send to TFL API.
.PARAMETER Name
    The mandatory parameter Name defines the station name to format.
.EXAMPLE
    The example below removes the brackets from the supplied station name.
    PS C:\> Format-StationName -Name London Bridge [Underground]
    PS C:\> London Bridge
.NOTES
    Author: Simon England
    Last Edit: 2019-09-02
    Version: 1.0
    Version 1.0 - 2019-09-02 Initial release of Format-StationName
#>
    Param(
        [Parameter(Position=0,
                   HelpMessage="Station name",
                   Mandatory=$true)]
        [string]
        $Name
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }

    Process {
        Write-Verbose -Message "Entering the PROCESS block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        $NameFormat = $Name
        $Parantheses = $NameFormat.IndexOf('(')
        If ($Parantheses -ge 0) {
            $NameFormat = $NameFormat.Substring(0, $Parantheses)
        }
        $SquareBrack = $NameFormat.IndexOf('[')
        If ($SquareBrack -ge 0) {
            $NameFormat = $NameFormat.Substring(0, $SquareBrack)
        }
        $NameFormat = $NameFormat.Trim()
        return $NameFormat
    }

    End {
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }
}


Function Find-JourneyCost {
<#
.SYNOPSIS
    This function finds the required journey cost from a journey object.
.DESCRIPTION
    Powershell function to extract the journey cost for the selected journey type from a PSObject, converted from TFL API JSON.
.PARAMETER Type
    The mandatory parameter Type defines the journey type (peak or off peak).
.PARAMETER Journey
    The mandatory parameter Journey is the journey object, converted from a TFL API JSON.
.EXAMPLE
    The example below returns the off peak cost for a journey in GBP.
    PS C:\> Find-JourneyCost -Type OffPeak -Journey $JourneyObject
    PS C:\> 2.75
.NOTES
    Author: Simon England
    Last Edit: 2019-09-03
    Version: 1.0
    Version 1.0 - 2019-09-03 Initial release of Find-JourneyCost
#>
    Param(
        [Parameter(Position=0,
                   HelpMessage="Journey type: Peak or OffPeak",
                   Mandatory=$true)]
        [ValidateSet('Peak','OffPeak')]
        [string]
        $Type,
        [Parameter(Position=1,
                   HelpMessage="Journey object, converted from TFL API JSON",
                   Mandatory=$true)]
        [PSObject]
        $Journey
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }

    Process {
        Write-Verbose -Message "Entering the PROCESS block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        $Cost = 0
        If ($Type -eq 'OffPeak') {
            $Phrase = 'Off Peak'
        } Elseif ($Type -eq 'Peak') {
            $Phrase = 'Peak'
        }

        For ($i = 0; $i -lt $Journey.rows[0].ticketsAvailable.length; $i++) {
            If ($Journey.rows[0].ticketsAvailable[$i].ticketType.type -eq 'Pay as you go') {
                If (($Journey.rows[0].ticketsAvailable[$i].ticketTime.type).Trim() -eq $Phrase) {
                    $Cost = $Journey.rows[0].ticketsAvailable[$i].cost
                }
            }
        }

        If ($Cost -eq 0) {
            $Phrase = 'Anytime'
            For ($i = 0; $i -lt $Journey.rows[0].ticketsAvailable.length; $i++) {
                If ($Journey.rows[0].ticketsAvailable[$i].ticketType.type -eq 'Pay as you go') {
                    If (($Journey.rows[0].ticketsAvailable[$i].ticketTime.type).Trim() -eq $Phrase) {
                        $Cost = $Journey.rows[0].ticketsAvailable[$i].cost
                    }
                }
            }
        }

        return $Cost
    }

    End {
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }
}

Function Find-HubTubeID {
<#
.SYNOPSIS
    This function finds the station ID of a tube station from the hub ID.
.DESCRIPTION
    Powershell function to fetch the tube station ID from a hub station ID.
.PARAMETER Type
    The mandatory parameter Station defines the station hub ID.
.PARAMETER AppID
    The mandatory parameter AppID defines your Application ID for TFL API.
.PARAMETER AppKey
    The mandatory parameter AppKey defines your Application Key for TFL API.
.EXAMPLE
    The example below returns the tube station ID for Kings Cross
    PS C:\> Find-HubTubeID -Station HUBKGX -AppID appid -AppKey appkey
    PS C:\> 2.75
.NOTES
    Author: Simon England
    Last Edit: 2019-09-03
    Version: 1.0
    Version 1.0 - 2019-09-03 Initial release of Find-HubTubeID
#>
    Param(
        [Parameter(Position=0,
                   HelpMessage="Station hub ID.",
                   Mandatory=$true)]
        [string]
        $Station,
        [Parameter(Position=1,
                   HelpMessage="Application ID for TFL API.",
                   Mandatory=$true)]
        [string]
        $AppID,
        [Parameter(Position=2,
                   HelpMessage="Application Key for TFL API.",
                   Mandatory=$true)]
        [string]
        $AppKey
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        # Set security protocol so Invoke-WebRequest works.
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
    }

    Process {
        Write-Verbose -Message "Entering the PROCESS block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        $QueryAppend = '?app_id=' + $AppID + '&app_key=' + $AppKey
        $Query = 'https://api.tfl.gov.uk/Stoppoint/' + $Station + $QueryAppend
        $Response = Invoke-WebRequest -uri $Query | ConvertFrom-Json

        $i = 0;
        $Answer = $False
        While (!$Answer -AND ($i -lt $Response.lineModeGroups.length)) {
            If ($Response.lineModeGroups[$i].modeName -eq 'tube') {
                $Line = $Response.lineModeGroups[$i].lineIdentifier[0]
                $j = 0
                While (!$Answer -AND ($j -lt $Response.lineGroup.length)) {
                    $k = 0
                    While (!$Answer -AND ($k -lt $Response.lineGroup[$j].lineIdentifier.length)) {
                        If ($Response.lineGroup[$j].lineIdentifier[$k] -eq $Line) {
                            $StationID = $Response.lineGroup[$j].stationAtcoCode
                            $Answer = $True
                        }
                        $k++
                    }
                    $j++
                }
            }
            $i++
        }

        return $StationID
    }

    End {
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }
}

Function Test-TFLRequestLimit {
<#
.SYNOPSIS
    This function tests whether the request limit is about to be exceeded.
.DESCRIPTION
    Powershell function to test the limit of requests per minute to TFL API.
.PARAMETER Requests
    The mandatory parameter Requests defines the current request count.
.PARAMETER MaxRequests
    The mandatory parameter MaxRequests defines the maximum requests per minute.
.PARAMETER StartTime
    The mandatory parameter StartTime defines when the count started.
.EXAMPLE
    The example below stops requests temporarily
    PS C:\> Test-TFLRequestLimit -Requests 500 -MaxRequests 500 -StartTime $StartTime
    PS C:\> True
.NOTES
    Author: Simon England
    Last Edit: 2019-10-14
    Version: 1.0
    Version 1.0 - 2019-10-14 Initial release of Find-HubTubeID
#>
    Param(
        [Parameter(Position=0,
                   HelpMessage="Number of requests to TFL API.",
                   Mandatory=$true)]
        [int]
        $Requests,
        [Parameter(Position=1,
                   HelpMessage="maximum requests per minute to TFL API.",
                   Mandatory=$true)]
        [int]
        $MaxRequests,
        [Parameter(Position=2,
                   HelpMessage="Start time for request count.",
                   Mandatory=$true)]
        [DateTime]
        $StartTime
    )

    Begin {
        Write-Verbose -Message "Entering the BEGIN block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }

    Process {
        Write-Verbose -Message "Entering the PROCESS block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."

        $Result = $False
        if ($Requests -ge $MaxRequests) {
            $CurrentTime = Get-Date
            $Seconds = (New-TimeSpan -Start $StartTime -End $CurrentTime).TotalSeconds
            if ($Seconds -le 60) {
                # Start-Sleep -Seconds (60 - $Seconds)
                # This could still result in 420s, so always wait 60 seconds after maximum requests.
                Start-Sleep -Seconds 60
                $Result = $True
            }
        }

        return $Result
    }

    End {
        Write-Verbose -Message "Entering the END block [$($MyInvocation.MyCommand.CommandType): $($MyInvocation.MyCommand.Name)]."
    }
}