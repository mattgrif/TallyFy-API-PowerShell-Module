<#
NAME: TallyFy.psm1
AUTHOR: Matt Griffin
CREATED  : 08/09/2018
MODIFIED : 08/23/2018
COMMENT: Script module to connect and interact with the TallyFy API.
#>
function Get-TallyFyAccessToken {
    <#
        .SYNOPSIS

            Get's and Access Token for the TallyFy API for future API Get/Set actions in a specific TallyFy Instance.

        .PARAMETER ClientID

            ClientID is found after logging into TallyFy website and going under Account Settings -> Integrations

        .PARAMETER ClientSecret

            ClientSecret is found after logging into TallyFy website and going under Account Settings -> Integrations

        .PARAMETER OrganizationID

            OrganizationID is found after logging into TallyFy website and going under Account Settings -> Integrations

        .PARAMETER GrantType

            At the time of creating this module GrantType should always be developer. During initial Meeting Amit mentioned this can be used in the future to identify different integrations.

        .PARAMETER ApiURI

            If the TallyFy API URL changes in the future you can specify the new one here. This is jsut the base API Address not specific to the functions. Those are hard coded into the Module Functions.

        .OUTPUTS

            Access_Token Object that will be used to interact with other Functions in Module. This should be saved to a variable for easier future use.

        .EXAMPLE

            $token = Get-TallyFyAccessToken

        .EXAMPLE

            $token = Get-TallyFyAccessToken -ClientID 'AAAAAAAAAA' -ClientSecret 'BBBBBBBBBB' -OrganizationID 'CCCCCCCCCCC'
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $ClientID,
        [Parameter(Mandatory=$true)]
        $ClientSecret,
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        $GrantType = 'developer',
        $ApiUri = 'https://go.tallyfy.com/api'
    )

    begin {
    }

    process {
        $uri = "$ApiUri/token"
        $body = @{
            client_id = $ClientID;
            client_secret = $ClientSecret;
            grant_type = $GrantType
        }
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        $token = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Body $body
    }

    end {
        return $token
    }
}

function Get-TallyFyOrganization {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $uri = "$ApiUri/organizations/$organizationID"
        $organization = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($Token.access_token)"; org = $OrganizationID}
    }
    
    end {
        return $organization | Select-Object -ExpandProperty data
    }
}

function Set-TallyFyOrganization {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$Name = (Get-TallyFyOrganization -Token $Token -OrganizationID $OrganizationID).name,
        [string]$Welcome_Title,
        [string]$Welcome_Description,
        [string]$Description,
        [string]$Address1,
        [string]$Address2,
        [string]$Address3,
        [string]$Country,
        [string]$State,
        [string]$City,
        [string]$ZipCode,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
    }
    
    process {
        $body = @{}
        foreach($param in $ParameterList){
            $variables =  (Get-Variable -Name $param.Values.Name -ErrorAction SilentlyContinue)
            foreach($var in $variables){
                if((("Token", "OrganizationID", "ApiUri") -NOTCONTAINS $($var.Name)) -AND (![string]::IsNullOrEmpty($($var.Value)))){
                    $valueName = $($var.Name).ToString().ToLower()
                    $body += @{"$valueName" = "$($var.Value)"}
                }
            }
        }
        $uri = "$ApiUri/organizations/$organizationID"
        $organization = Invoke-RestMethod -uri $uri -Method PUT -ContentType 'application/json' -Headers @{Authorization = "Bearer $($Token.access_token)"; org = $OrganizationID} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $organization.data
    }
}

function Get-TallyFyChecklist {
    [CmdletBinding(DefaultParameterSetName='AllChecklists')]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        [parameter(Mandatory=$false, ParameterSetName="AllChecklists")]
        [parameter(Mandatory=$true, ParameterSetName="Checklist")]
        [string]$ChecklistID,
        [string]$Version,
        [string]$With,
        $ApiUri = 'https://go.tallyfy.com/api'
    )

    begin {
    }

    process {
        if(![string]::IsNullOrEmpty($ChecklistID)){
            $uri = "$ApiUri/organizations/$OrganizationID/checklists/$ChecklistID"
        }
        else{
            $uri = "$ApiUri/organizations/$OrganizationID/checklists"
        }

        $second = $false
        
        if((![string]::IsNullOrEmpty($Version)) -AND ($second -eq $false)){
            $uri += "?version=$Version"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($Version)) {
            $uri += "&version=$Version"
        }

        if((![string]::IsNullOrEmpty($With)) -AND ($second -eq $false)){
            $uri += "?with=$With"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($With)) {
            $uri += "&with=$With"
        }

        $checklists = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($Token.access_token)"; org = $OrganizationID}
    }

    end {
        return $checklists | Select-Object -ExpandProperty data
    }
}

function Remove-TallyFyChecklist {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        [parameter(Mandatory=$true)]
        [string]$ChecklistID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $uri = "$ApiUri/organizations/$OrganizationID/checklists/$ChecklistID"
        $checklists = Invoke-RestMethod -uri $uri -Method Delete -ContentType 'application/json' -Headers @{Authorization = "Bearer $($Token.access_token)"; org = $OrganizationID}
    }
    
    end {
        return $checklists.data
    }
}

#Needs Written
function Remove-TallyFyChecklistPrerun {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
    }
    
    process {
    }
    
    end {
    }
}

#Needs Written
function Import-TallyFyChecklist {
    [CmdletBinding()]
    param (
        
    )
    
    begin {
    }
    
    process {
    }
    
    end {
    }
}

function Get-TallyFyBillingInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $uri = "$ApiUri/organizations/$OrganizationID/billing-info"
        $billinginfo = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($Token.access_token)"; org = $OrganizationID}
    }
    
    end {
        return $billinginfo.data
    }
}

function Get-TallyFyRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$With,
        [string]$Owners,
        [string]$Status,
        [string]$ChecklistID,
        [string]$Starred,
        [string]$ApiUri = 'https://go.tallyfy.com/api'

    )

    begin {
    }

    process {
        $uri = "$ApiUri/organizations/$organizationID/runs"
        $second = $false

        if((![string]::IsNullOrEmpty($With)) -AND ($second -eq $false)){
            $uri += "?with=$With"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($With)) {
            $uri += "&with=$With"
        }

        if((![string]::IsNullOrEmpty($Owners)) -AND ($second -eq $false)){
            $uri += "?owners=$Owners"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($Owners)) {
            $uri += "&owners=$Owners"
        }

        if((![string]::IsNullOrEmpty($Status)) -AND ($second -eq $false)){
            $uri += "?status=$Status"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($Status)) {
            $uri += "&status=$Status"
        }

       if((![string]::IsNullOrEmpty($ChecklistID)) -AND ($second -eq $false)){
            $uri += "?checklist_id=$ChecklistID"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($ChecklistID)) {
            $uri += "&checklist_id=$ChecklistID"
        }

        if((![string]::IsNullOrEmpty($Starred)) -AND ($second -eq $false)){
            $uri += "?starred=$Starred"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($Starred)) {
            $uri += "&starred=$Starred"
        }

        $runs = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"}
    }

    end {
        return $runs.data
    }
}

function New-TallyFyRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        $KickoffFormFields,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )

    begin {
    }

    process {
        $uri = "$ApiUri/organizations/$organizationID/runs"
        $process = Invoke-RestMethod -uri $uri -Method Post -ContentType 'application/json' -Body $KickoffFormFields -Headers @{Authorization = "Bearer $($token.access_token)"}
    }

    end {
        return $process
    }
}

function Get-TallyFyLibrary {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $uri = "$ApiUri/library"
        $library = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"}
    }
    
    end {
        return $library
    }
}

function Get-TallyFyUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$ID,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        if(![string]::IsNullOrEmpty($ID)){
            $uri = "$ApiUri/organizations/$organizationID/users/$ID"
        }
        else{
            $uri = "$ApiUri/organizations/$organizationID/users"
        }
        $users = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"}
    }
    
    end {
        return $users.data
    }
}

function Remove-TallyFyUser {
    [CmdletBinding(DefaultParameterSetName='RemoveUser')]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$UsernameOrID,
        [parameter(Mandatory=$false, ParameterSetName="RemoveUser")]
        [parameter(Mandatory=$true, ParameterSetName="RemoveandReassign")]
        [boolean]$With_Reassignment,
        [parameter(Mandatory=$true, ParameterSetName="RemoveandReassign")]
        [string]$AssignTo,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $uri = "$ApiUri/organizations/$organizationID/users/$UsernameOrID"
        if($With_Reassignment -eq $true){
            $uri = "$ApiUri/organizations/$organizationID/users/$($UsernameOrID)?with_reassignment=$With_Reassignment&to=$AssignTo"
        }
        $users = Invoke-RestMethod -uri $uri -Method Delete -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"}
    }
    
    end {
        return $users.data
    }
}

function New-TallyFyUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$FirstName,
        [Parameter(Mandatory=$true)]
        [string]$LastName,
        [Parameter(Mandatory=$true)]
        [string]$Email,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        $body = @{
            'first_name'    = $FirstName;
            'last_name'     = $LastName;
            'email'         = $Email
        }
        $uri = "$ApiUri/organizations/$organizationID/users/invite"
        $users = Invoke-RestMethod -uri $uri -Method Post -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $users.data
    }
}

function Set-TallyFyUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$ID,
        [string]$First_Name = (Get-TallyFyUser -Token $Token -OrganizationID $OrganizationID | Where-Object id -eq $ID).first_name,
        [string]$Last_Name = (Get-TallyFyUser -Token $Token -OrganizationID $OrganizationID | Where-Object id -eq $ID).last_name,
        [string]$Email,
        [string]$UserName,
        [string]$Phone,
        [string]$Job_Title,
        [string]$TimeZone = (Get-TallyFyUser -Token $Token -OrganizationID $OrganizationID | Where-Object id -eq $ID).timezone,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
        if([string]::IsNullOrEmpty($Email)){
            $Email = (Get-TallyFyUser -Token $Token -OrganizationID $OrganizationID -ID $ID).email
        }
        if([string]::IsNullOrEmpty($UserName)){
            $UserName = (Get-TallyFyUser -Token $Token -OrganizationID $OrganizationID -ID $ID).username
        }
    }
    
    process {
        $body = @{}
        foreach($param in $ParameterList){
            $variables =  (Get-Variable -Name $param.Values.Name -ErrorAction SilentlyContinue)
            foreach($var in $variables){
                if((("Token", "OrganizationID", "ApiUri", "ID") -NOTCONTAINS $($var.Name)) -AND (![string]::IsNullOrEmpty($($var.Value)))){
                    $valueName = $($var.Name).ToString().ToLower()
                    $body += @{"$valueName" = "$($var.Value)"}
                }
            }
        }
        Write-Output ($body | ConvertTo-Json)
        $uri = "$ApiUri/organizations/$organizationID/accounts/$ID"
        Write-Output $uri
        $users = Invoke-RestMethod -uri $uri -Method Put -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $users.data
    }
}

function Get-TallyFyTask {
    [CmdletBinding(DefaultParameterSetName='AllTasks')]
    param (
        [Parameter(Mandatory=$true)]
        $Token,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [parameter(Mandatory=$true, ParameterSetName="MyTasks")]
        [boolean]$MyTasks,
        [parameter(Mandatory=$true, ParameterSetName="OtherUserTasks")]
        [string]$User_ID,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string[]]$Owners,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string]$Status,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string]$Created,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
    }
    
    process {
        if($MyTasks -eq $true){
            $uri = "$ApiUri/organizations/$organizationID/me/tasks"
        }
        elseif(![string]::IsNullOrEmpty($User_ID)){
            $uri = "$ApiUri/organizations/$organizationID/users/$User_ID/tasks"
        }
        else{
            $uri = "$ApiUri/organizations/$organizationID/tasks"

            $second = $false
        
            if((![string]::IsNullOrEmpty($Owners)) -AND ($second -eq $false)){
                ###Needs updated to handle array
                $uri += "?owners=$Owners"
                $second = $true
            }
            elseif(![string]::IsNullOrEmpty($Owners)) {
                ###Needs updated to handle array
                $uri += "&owners=$Owners"
            }
    
            if((![string]::IsNullOrEmpty($Status)) -AND ($second -eq $false)){
                $uri += "?status=$Status"
                $second = $true
            }
            elseif(![string]::IsNullOrEmpty($Status)) {
                $uri += "&status=$Status"
            }    

            if((![string]::IsNullOrEmpty($Created)) -AND ($second -eq $false)){
                $uri += "?created=$Created"
                $second = $true
            }
            elseif(![string]::IsNullOrEmpty($Created)) {
                $uri += "&created=$Created"
            }
        }
        #Write-Output $uri
        $tasks = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = "Bearer $($token.access_token)"}
    }
    
    end {
        return $tasks.data
    }
}
