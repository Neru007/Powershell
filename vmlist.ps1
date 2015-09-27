#Add Powershell Snapin
Add-PSSnapin VMware.VimAutomation.Core

#Import SecureCredentials
$username = "account-for-connecting-esxi"
# Getting Password from the secure file that is saved in encryped format at location z:\project\cred.txt
$cred = New-Object System.Management.Automation.PsCredential $username,(Get-Content z:\project\cred.txt| ConvertTo-SecureString)
#Ignore Certificate Warning
set-PowerCLIConfiguration -invalidCertificateAction "ignore" -confirm:$false

#Connect To Esxi
Connect-VIServer -Credential $cred -Server #Specify Server IP or FQDN if you've a working DNS after this.

#Variable for Report Styling
$a = "<style>"
$a = $a + "BODY{background-color:white; font-family:Tahoma; font-size:9pt;}"  
$a = $a + "TABLE{border-width: 1px;border-style: solid;boder-color: black;border-collapse: collapse;}"
$a = $a + "TH{border-width: 1px;padding: 5px;border-style: solid;boder-color: black;background-color: Silver}"
$a = $a + "TD{border-width: 1px;padding: 5px;border-style: solid;boder-color: black;background-color: white}"
$a = $a + "</style>"

#Date and Time timestamp
$date = Get-Date -format "dd-MMM-yyyy HH:mm"
#Generate Report
Get-VM | Select-Object @{n="ESXI"; E={$_.VMHost}},@{n="SERVER-NAME"; E={$_.Name}},Version,PowerState,@{n="CPU"; E={$_.NumCPU}},@{n="RAM(GB)"; E={[math]::round($_.MemoryGB)}},@{n="HDD(GB)"; E={[math]::round($_.ProvisionedSpaceGB)}},Notes | Sort-Object ESXI,SERVER-NAME | ConvertTo-HTML -head $a -body "<H2>VM List - Last Updated at $date | Update Frequency : 120 Minutes</H2>" | Out-File "z:\project\VMList.htm"

#Disconnect from VI server as Job Completed
disconnect-viserver * -confirm:$false

#Upload file to FTP
$Dir="z:\project\"    
 
#ftp details 
$ftp = "ftp://IPAddress/folder/location/" 
$user = "ftpuser" 
$pass = "ftpuserpassword"  
$webclient = New-Object System.Net.WebClient 

#Authenticating 
$webclient.Credentials = New-Object System.Net.NetworkCredential($user,$pass)  
 
#Upload .htm file that is created
foreach($item in (dir $Dir "VMList.htm")){ 
    "Uploading $item..." 
    $uri = New-Object System.Uri($ftp+$item.Name) 
    $webclient.UploadFile($uri, $item.FullName) 
 } 
