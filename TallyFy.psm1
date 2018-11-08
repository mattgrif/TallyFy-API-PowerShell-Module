<#
NAME: TallyFy.psm1
AUTHOR: Matt Griffin
CREATED  : 08/09/2018
MODIFIED : 11/07/2018
COMMENT: Script module to connect and interact with the TallyFy API.
MODIFIED NOTES:
    2018.11.07: Re-factored authentication with TallyFy API. Updated module to use OAuth authentication coming out on 2018.11.08.
#>

function Connect-TallyFyAPI {
    <#
        .SYNOPSIS

            Connects to TallyFy API for future API Get/Set actions in a specific TallyFy Instance.

        .PARAMETER ClientID

            ClientID is found after logging into TallyFy website and going under Account Settings -> Integrations.

        .PARAMETER ClientSecret

            ClientSecret is found after logging into TallyFy website and going under Account Settings -> Integrations.

        .PARAMETER Credential

            Username and Password for TallyFy account that will be making the changes/accessing the information.

        .PARAMETER GrantType

            At the time of creating this module GrantType should always be developer. During initial Meeting Amit mentioned this can be used in the future to identify different integrations.

        .PARAMETER GrantType
        
            Access level you want to request a token for. Default is all access your account has permissions to.

        .PARAMETER ApiURI

            If the TallyFy API URL changes in the future you can specify the new one here. This is jsut the base API Address not specific to the functions. Those are hard coded into the Module Functions.

        .OUTPUTS

            None

        .EXAMPLE

            Connect-TallyFyAPI -ClientID 'AAAAAAAAAA' -ClientSecret 'BBBBBBBBBB' -Credential (Get-Credential)
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $ClientID,
        [Parameter(Mandatory=$true)]
        $ClientSecret,
        [System.Management.Automation.PSCredential]$Credential,
        $GrantType = 'password',
        $Scope = '*',
        $ApiUri = 'https://go.tallyfy.com/api'
    )

    begin {
        if($null -eq $Credential){
            $Credential = Get-Credential
        }

        $userName = $Credential.UserName
        $password = $Credential.GetNetworkCredential().Password
    }

    process {
        $uri = "$ApiUri/oauth/token"

        $body = @{
            grant_type = $GrantType;
            client_id = $ClientID;
            client_secret = $ClientSecret;
            username = $userName;
            password = $password;
            scope = $Scope
        }

        $body = ($body | ConvertTo-Json)
        [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
        try{
            $token = Invoke-RestMethod -uri $uri -Method POST -ContentType 'application/json' -Body $body
        }
        catch{
            throw 'Failed to connect to TallyFy API'
        }

        $Global:TallyFyAuth = "$($token.token_type) $($token.access_token)"
    }

    end {
        return "Connected to TallyFy!"
    }
}

function Get-TallyFyOrganization {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $uri = "$ApiUri/organizations/$organizationID"
        $organization = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID}
    }
    
    end {
        return $organization | Select-Object -ExpandProperty data
    }
}

function Set-TallyFyOrganization {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$Name,
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
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }

        if([string]::IsNullOrEmpty($Name)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $Name = (Get-TallyFyOrganization -OrganizationID $OrganizationID -ApiUri $ApiUri).name
            }
            else{
                $Name = (Get-TallyFyOrganization -OrganizationID $OrganizationID).name
            }
        }

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
        $organization = Invoke-RestMethod -uri $uri -Method PUT -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $organization.data
    }
}

function Get-TallyFyChecklist {
    [CmdletBinding(DefaultParameterSetName='AllChecklists')]
    param (
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
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
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

        $checklists = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID}
    }

    end {
        return $checklists | Select-Object -ExpandProperty data
    }
}

function Remove-TallyFyChecklist {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        [parameter(Mandatory=$true)]
        [string]$ChecklistID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $uri = "$ApiUri/organizations/$OrganizationID/checklists/$ChecklistID"
        $checklists = Invoke-RestMethod -uri $uri -Method Delete -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID}
    }
    
    end {
        return $checklists.data
    }
}

function Get-TallyFyChecklistDeadlines {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$ChecklistID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $uri = "$ApiUri/organizations/$OrganizationID/checklists/$ChecklistID/steps-deadlines"
        $checklists = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID}
    }
    
    end {
        return $checklists | Select-Object -ExpandProperty data
    }
}

function Get-TallyFyBillingInformation {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $uri = "$ApiUri/organizations/$OrganizationID`?with=billing_info"
        $billinginfo = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth; org = $OrganizationID}
    }
    
    end {
        return $billinginfo.data.billing_info.data
    }
}

function Get-TallyFyRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$RunID,
        [string]$With,
        [string]$Owners,
        [string]$Status,
        [string]$ChecklistID,
        [string]$Starred,
        [string]$Results,
        [string]$ApiUri = 'https://go.tallyfy.com/api'

    )

    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }

    process {
        if(![string]::IsNullOrEmpty($RunID)){
            $uri = "$ApiUri/organizations/$organizationID/runs/$RunID"
        }
        else{
            $uri = "$ApiUri/organizations/$organizationID/runs"
        }

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

        if((![string]::IsNullOrEmpty($Results)) -AND ($second -eq $false)){
            $uri += "?per_page=$Results"
            $second = $true
        }
        elseif(![string]::IsNullOrEmpty($Results)) {
            $uri += "&per_page=$Results"
        }

        $runs = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth}
    }

    end {
        return $runs.data
    }
}

function New-TallyFyRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        $Name,
        [Parameter(Mandatory=$true)]
        $Checklist_ID,
        $PrerunValue,
        $TaskOwner,
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        $ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
        if($ApiUri -ne 'https://go.tallyfy.com/api'){
            $stepDeadlines = Get-TallyFyChecklistDeadlines -Token $Token -OrganizationID $OrganizationID -ChecklistID $Checklist_ID -ApiUri $ApiUri
        }
        else{
            $stepDeadlines = Get-TallyFyChecklistDeadlines -Token $Token -OrganizationID $OrganizationID -ChecklistID $Checklist_ID
        }
    }
    
    process {
        $body = @{
            name = $Name
            checklist_id = $Checklist_ID
        }
        if($null -ne $PrerunValue){
            $body.prerun = @()
            foreach($key in $PrerunValue.Keys){
                $body.prerun += @{$key = $($prerunValue.($key))}
            }
        }

        if($null -ne $TaskOwner){
            foreach($step in $stepDeadlines){
                if($taskOwner.Keys -contains $($step.step_id)){
                    #Write Hashtable with Owners values
                    $users = @()
                    foreach($value in $($TaskOwner.Item($($step.step_id)))){
                        $users += $value 
                    }
                    $body.tasks += @{
                        $($step.step_id) = @{
                            'owners' = @{
                                'users' = $users
                            }
                            'taskdata' = @{
                                'deadline' = $($step.deadline_time)
                            }
                        }
                    }
                }
                else{
                    #write Hashtable without Owners values
                    $body.tasks += @{
                        $($step.step_id) = @{
                            'taskdata' = @{
                                'deadline' = $($step.deadline_time)
                            }
                        }
                    }
                }
            }
        }

        $uri = "$ApiUri/organizations/$organizationID/runs"
        $json = ($body | ConvertTo-Json -Depth 5)
        $process = Invoke-RestMethod -uri $uri -Method Post -ContentType 'application/json' -Body $json -Headers @{Authorization = $TallyFyAuth}
    }
    
    end {
        return $process.data
    }
}

function Set-TallyFyRun {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$Run_ID,
        [hashtable]$RunData,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $body = ConvertTo-Json -Depth 5 @{
            taskdata = $RunData
        }
        $uri = "$ApiUri/organizations/$organizationID/tasks/$ID"
        $runs = Invoke-RestMethod -uri $uri -Method Put -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth} -Body $body
    }
    
    end {
        return $runs.data
    }
}

function Get-TallyFyUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [string]$ID,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        if(![string]::IsNullOrEmpty($ID)){
            $uri = "$ApiUri/organizations/$organizationID/users/$ID"
        }
        else{
            $uri = "$ApiUri/organizations/$organizationID/users"
        }
        $users = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth}
    }
    
    end {
        return $users.data
    }
}

function Remove-TallyFyUser {
    [CmdletBinding(DefaultParameterSetName='RemoveUser')]
    param (
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
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $uri = "$ApiUri/organizations/$organizationID/users/$UsernameOrID"
        if($With_Reassignment -eq $true){
            $uri = "$ApiUri/organizations/$organizationID/users/$($UsernameOrID)?with_reassignment=$With_Reassignment&to=$AssignTo"
        }
        $users = Invoke-RestMethod -uri $uri -Method Delete -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth}
    }
    
    end {
        return $users.data
    }
}

function New-TallyFyUser {
    [CmdletBinding()]
    param (
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
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $body = @{
            'first_name'    = $FirstName;
            'last_name'     = $LastName;
            'email'         = $Email
        }
        $uri = "$ApiUri/organizations/$organizationID/users/invite"
        $users = Invoke-RestMethod -uri $uri -Method Post -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $users.data
    }
}

function Set-TallyFyUser {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$ID,
        [string]$First_Name,
        [string]$Last_Name,
        [string]$Email,
        [string]$UserName,
        [string]$Phone,
        [string]$Job_Title,
        [string]$TimeZone,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }

        #Capture current First Name if null - accounts for bug in TallyFy API that will make it null if not provided.
        if([string]::IsNullOrEmpty($First_Name)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $First_Name = (Get-TallyFyUser -OrganizationID $OrganizationID -ApiUri $ApiUri | Where-Object id -eq $ID).first_name
            }
            else{
                $First_Name = (Get-TallyFyUser -OrganizationID $OrganizationID | Where-Object id -eq $ID).first_name
            }
        }

        #Capture current Last Name if null - accounts for bug in TallyFy API that will make it null if not provided.
        if([string]::IsNullOrEmpty($Last_Name)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $Last_Name = (Get-TallyFyUser -OrganizationID $OrganizationID -ApiUri $ApiUri | Where-Object id -eq $ID).last_name
            }
            else{
                $Last_Name = (Get-TallyFyUser -OrganizationID $OrganizationID | Where-Object id -eq $ID).last_name
            }
        }

        #Capture current Time zone if null - accounts for bug in TallyFy API that will make it null if not provided.
        if([string]::IsNullOrEmpty($TimeZone)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $TimeZone = (Get-TallyFyUser -OrganizationID $OrganizationID -ApiUri $ApiUri | Where-Object id -eq $ID).timezone
            }
            else{
                $TimeZone = (Get-TallyFyUser -OrganizationID $OrganizationID | Where-Object id -eq $ID).timezone
            }
        }

        $ParameterList = (Get-Command -Name $MyInvocation.InvocationName).Parameters;
        if([string]::IsNullOrEmpty($Email)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $Email = (Get-TallyFyUser -OrganizationID $OrganizationID -ID $ID -ApiUri $ApiUri).email
            }
            else{
                $Email = (Get-TallyFyUser -OrganizationID $OrganizationID -ID $ID).email
            }
        }
        if([string]::IsNullOrEmpty($UserName)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                $UserName = (Get-TallyFyUser -OrganizationID $OrganizationID -ID $ID -ApiUri $ApiUri).username
            }
            else{
                $UserName = (Get-TallyFyUser -OrganizationID $OrganizationID -ID $ID).username
            }
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
        $uri = "$ApiUri/organizations/$organizationID/users/$ID"
        $users = Invoke-RestMethod -uri $uri -Method Put -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth} -Body ($body | ConvertTo-Json)
    }
    
    end {
        return $users.data
    }
}

function Get-TallyFyTask {
    [CmdletBinding(DefaultParameterSetName='AllTasks')]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [parameter(Mandatory=$true, ParameterSetName="MyTasks")]
        [boolean]$MyTasks,
        [parameter(Mandatory=$true, ParameterSetName="OtherUserTasks")]
        [string]$User_ID,
        [parameter(Mandatory=$true, ParameterSetName="SingleTask")]
        [string]$TaskID,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string[]]$Owners,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string]$Status,
        [parameter(Mandatory=$false, ParameterSetName="AllTasks")]
        [string]$Created,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        if($MyTasks -eq $true){
            $uri = "$ApiUri/organizations/$organizationID/me/tasks"
        }
        elseif(![string]::IsNullOrEmpty($User_ID)){
            $uri = "$ApiUri/organizations/$organizationID/users/$User_ID/tasks"
        }
        elseif(![string]::IsNullOrEmpty($TaskID)){
            $uri = "$ApiUri/organizations/$organizationID/tasks/$TaskID"
            Write-Output $uri
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

        $tasks = Invoke-RestMethod -uri $uri -Method Get -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth}
    }
    
    end {
        return $tasks.data
    }
}

function Set-TallyFyTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$TaskID,
        [Parameter(Mandatory=$true)]
        [string]$RunID,
        [hashtable]$TaskData,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $body = ConvertTo-Json -Depth 5 @{
            taskdata = $TaskData
        }
        $uri = "$ApiUri/organizations/$organizationID/runs/$RunID/tasks/$TaskID"
        $tasks = Invoke-RestMethod -uri $uri -Method Put -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth} -Body $body
    }
    
    end {
        return $tasks.data
    }
}

function Complete-TallyFyTask {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory=$true)]
        [string]$OrganizationID,
        [Parameter(Mandatory=$true)]
        [string]$TaskID,
        [Parameter(Mandatory=$true)]
        [string]$RunID,
        [string]$ApiUri = 'https://go.tallyfy.com/api'
    )
    
    begin {
        if([string]::IsNullOrEmpty($TallyFyAuth)){
            if($ApiUri -ne 'https://go.tallyfy.com/api'){
                Connect-TallyFyAPI -ApiUri $ApiUri
            }
            else {
                Connect-TallyFyAPI
            }
        }
    }
    
    process {
        $body = ConvertTo-Json -Depth 5 @{
            task_id = $TaskID
        }
        $uri = "$ApiUri/organizations/$organizationID/runs/$RunID/completed-tasks"
        $tasks = Invoke-RestMethod -uri $uri -Method Post -ContentType 'application/json' -Headers @{Authorization = $TallyFyAuth} -Body $body
    }
    
    end {
        return $tasks.data
    }
}