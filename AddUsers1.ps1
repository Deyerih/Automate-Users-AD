# Importing Active Directory Module
Import-Module ActiveDirectory

#Path to the CSV file
$CSVFile = "C:\Scripts\users10.csv"

# Log file
$LogPath = "C:\Scripts\Logs"

$Date = Get-Date -Format "yyyy-MM-dd_HH-mm"

$LogFolderPath = "$LogPath\$Date adduser_log"
if (-Not (Test-Path $LogFolderPath)){
    New-Item -Path $LogFolderPath -ItemType Directory | Out-Null
    }

$LogFilePath = "$LogFolderPath\$Date.log"
New-Item -Path $LogFilePath -ItemType File -Force | Out-Null

import-Csv -Path $CSVFile -Delimiter "," | Out-File -FilePath $LogFilePath -Append

# Role Mapping
$RoleMapping = @{
    "ITManager" = @{
        "OrganizationalUnit" = "OU=Domain Admins,OU=Kielce,DC=DevSys,DC=pl"
        "Groups" = @("Read-Only Domain Controllers", "Group Policy Creator Owners", "Account Operators", "Event Log Readers")
        "Description" = "IT Manager"
    }

    "System Admin" = @{
        "OrganizationalUnit" = "OU=Domain Admins,OU=Krakow,DC=DevSys,DC=pl"
        "Groups" = @("Domain Admins", "Server Operators", "Backup Operators", "Group Policy Creator Owners")
        "Description" = "System Administrator"
    }

    "Junior DevOps Engineer" = @{
        "OrganizationalUnit" = "OU=Domain Users,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Remote Desktop Users", "Network Configuration Operators")
        "Description" = "Junior DevOps"
    }

    "Senior DevOps Engineer" = @{
        "OrganizationalUnit" = "OU=Domain Users,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Remote Desktop Users", "Network Configuration Operators", "Event Log Readers", "Backup Operators")
        "Description" = "Senior Devops"
    }

    "Junior Developer" = @{
        "OrganizationalUnit" = "OU=Domain Users,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Remote Desktop Users", "Network Configuration Operators")
        "Description" = "Junior Developer"
    }

    "Senior Developer" = @{
        "OrganizationalUnit" = "OU=Domain Users,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Remote Desktop Users", "Network Configuration Operators", "Event Log Readers", "Backup Operators")
        "Description" = "Senior Developer"
    }

    "Main Office" = @{
        "OrganizationalUnit" = "OU=Domain Admins,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Read-Only Domain Controllers", "Account Operators", "Event Log Readers")
        "Description" = "Main Office"
    }

    "Cyber Security Office" = @{
        "OrganizationalUnit" = "OU=Domain Admins,OU=Starobilsk,DC=DevSys,DC=pl"
        "Groups" = @("Event Log Readers", "Account Operators", "Group Policy Creator Owners", "Read-Only Domain Controllers")
        "Description" = "Cuber Security Office"
    }

    "Physical Security" = @{
        "OrganizationalUnit" = "OU=Doamin Users,OU=Kielce,DC=DevSys,DC=pl"
        "Groups" = @("Event Log Readers", "Read-Only Domain Controllers")
        "Description" = "Physical Scurity"
    }
}




# Import file into variable
# If the file path is not valid, then exit the script
if([System.IO.File]::Exists($CSVFile)){
    $CSV = Import-Csv -LiteralPath "$CSVFile"
} else {
    "File path specified was not valid" | Out-File -FilePath $LogFilePath -Append
    Exit
}



# Iterate over each line in the CSV file
foreach($user in $CSV){

    if (-not $user.'First Name' -or -not $user.'Last Name') {
        "User entry missing required fields. Skipping." | Out-File -FilePath $LogFilePath -Append
        Continue
    }

    #Create a secure password
    $SecurePassword = ConvertTo-SecureString "$($user.'First Name'[0])$($user.'Last Name')$($user.'Employee ID')!@##@!" -AsPlainText -Force
    #Format their username
    $Username = "$($user.'First Name').$($user.'Last Name')"
    $Username = $Username.Replace(" ", "")
    $Position = $user.'Job Title'
    #Cheking for existing user
    $ExistingUser = Get-ADUser -Filter {SamAccountName -eq $Username} -ErrorAction SilentlyContinue

    if($ExistingUser){
        "User $Username already exists" | Out-File -FilePath $LogFilePath -Append
        Continue
    }


    #Generating unique samaccountname
    do{
        $SamaccountnamePart1 = -join ((65..90) | Get-Random -Count 3  | ForEach-Object {[char]$_})  
        $SamaccountnamePart2 = Get-Random -Minimum 100000 -Maximum 999999   
  
        $Samaccountname = -join ($SamaccountnamePart1, $SamaccountnamePart2)  
    } while (Get-ADUser -Filter {SamAccountName -eq $Samaccountname})

    if($RoleMapping.ContainsKey($User.'Job Title')){
        $UserRole = $RoleMapping[$Position]
        $OrganizationalUnit = $UserRole["OrganizationalUnit"]
        $Groups = $UserRole["Groups"]
        $Description = $UserRole["Description"]



        try{
    #Create new user
    New-ADUser -Name "$($user.'First Name') $($user.'Last Name')" `
                -GivenName $user.'First Name' `
                -Surname $user.'Last Name' `
                -UserPrincipalName $Username `
                -SamAccountName $Samaccountname `
                -EmailAddress $user.'Email Address' `
                -Path $OrganizationalUnit `
                -ChangePasswordAtLogon $true `
                -OfficePhone $user.'Office Phone' `
                -AccountPassword $SecurePassword `
                -Enabled $([System.convert]::ToBoolean($user.Enabled)) `
                -Description $Description

    "Created $Username / $($user.'Email Address')" | Out-File -FilePath $LogFilePath -Append

    if($user){
        cd C:\Scripts | python .\Sendmail.py "User is created" "Your email was specified as a worck email for $($user.'First Name') $($user.'Last Name'). If this is not you, simply ignore this message or contact us. If ti is you, please follow the 
        link to confirm your identity (without this, you will not able to access to shared resources) : https://labianahol.com/login/virify" $($user.'Email Address')
    } else {
        cd C:\Scripts | python .\Sendmail.py "Error" "Your email was specified as a worck email but an error occurre during account creation" $($user.'Email Address')
        }
        

    #Add user to groups
    foreach($Group in $Groups){
        Add-ADGroupMember -Identity $Group -Members $Samaccountname
        "Added $Username/$Samaccountname to $Group group" | Out-File -FilePath $LogFilePath -Append
            }
    } catch {
        "Error creating user $Username : $_" | Out-File -FilePath $LogFilePath -Append
    }
} else {
    "Role $Position does not exist in Role Mapping" | Out-File -FilePath $LogFilePath -Append
}

"Created user $Username with groups $($User.'Add Groups (csv)')" | Out-File -FilePath $LogFilePath -Append

}
if (-not $CSV) {
    "File path specified was not valid" | Out-File -FilePath $LogFilePath -Append
    Exit 
}


