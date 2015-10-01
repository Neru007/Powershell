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

# Create Function to Grab Esxi info
function Get-VMHostinventory {   
   foreach ($vmhost in Get-VMHost) {  
     Write-host "------------------------- Collecting Esx Information Esxi $vmhost ------------------------------------" 
     if ($vmhost.Version -ne "4.1.0") {  
       $esxcli = $vmhost | Get-EsxCli  
       $serviceTag = $esxcli.hardware.platform.get().SerialNumber  
     }  
        else {  
             $serviceTag = $vmhost.ExtensionData.summary.hardware.otheridentifyinginfo | select-object -ExpandProperty IdentifierValue -last 1  
        }
        
     #Esx Name
     $esxname = $vmhost | Get-View      
             
     #Esxihost Management IP and vlan ID  
     $Managementinfo = $vmhost | Get-VMHostNetworkAdapter | Where-Object {$_.ManagementTrafficEnabled -eq $true}  
     $IPinfo = $Managementinfo | select-object -ExpandProperty ip   
     $ManagementIP = $IPinfo -join ", "                 
   
     #All Virtual Machines Info  
     $VMs = $vmhost | Get-VM   
     $PoweredOnVM = $VMs | Where-Object {$_.PowerState -eq "PoweredOn"}  
   
     #EsxiHost and VM -- CPU calculation  
     $AssignedTotalvCPU = $VMs | Measure-Object NumCpu -Sum | Select-Object -ExpandProperty sum  
     $PoweredOnvCPU = $PoweredOnVM | Measure-Object NumCpu -Sum | Select-Object -ExpandProperty sum  
     $onecoreMhz = $vmhost.CPUTotalMhz / $vmhost.NumCpu  
       
     #EsxiHost and VM -- Memory calculation  
     $TotalMemory = [math]::round($vmhost.MemoryTotalGB)  
     $Calulatedvmmemory = $VMs | Measure-Object MemoryGB -sum | Select-Object -ExpandProperty sum  
     $TotalvmMemory = [math]::round($Calulatedvmmemory)  
     $Calulatedvmmemory = $PoweredOnVM | Measure-Object MemoryGB -sum | Select-Object -ExpandProperty sum    
   
     #vmhost SSH service Staus  
     $SSHservice = $vmhost | Get-VMHostService | Where-object {$_.key -eq "Tsm-ssh"} | Select-Object -ExpandProperty running  
   
     #vmhost Uptime  
     $UPtime = (Get-Date) - ($vmhost.ExtensionData.Runtime.BootTime) | Select-Object -ExpandProperty days  
   
   
     $VmHostresult = New-Object PSObject   
     $VmHostresult | add-member -MemberType NoteProperty -Name "Name" -Value $esxname.Name  
     $VmHostresult | add-member -MemberType NoteProperty -Name "MGMT_IP" -Value $ManagementIP  
     $VmHostresult | add-member -MemberType NoteProperty -Name "PwrState" -Value $vmhost.PowerState   
     $VmHostresult | add-member -MemberType NoteProperty -Name "Model" -Value $vmhost.Model
     $VmHostresult | add-member -MemberType NoteProperty -Name "Esxi-Version" -Value $vmhost.Version   
     $VmHostresult | add-member -MemberType NoteProperty -Name "SrvTag" -Value $serviceTag  
     $VMHostresult | add-member -MemberType NoteProperty -Name "TotalVms" -Value $VMs.count  
     $VMHostresult | add-member -MemberType NoteProperty -Name "PwrOnVMs" -Value $PoweredOnvm.Count     
     $VmHostresult | add-member -MemberType NoteProperty -Name "Total_Mhz" -Value $vmhost.CPUTotalMhz  
     $VmHostresult | add-member -MemberType NoteProperty -Name "AsgnTotal_vCPUs" -Value $AssignedTotalvCPU  
     $VmHostresult | add-member -MemberType NoteProperty -Name "PwrOnCPUs" -Value $PoweredOnvCPU    
     $VmHostresult | add-member -MemberType NoteProperty -Name "Memory(GB)" -Value $TotalMemory  
     $VmHostresult | add-member -MemberType NoteProperty -Name "AsgnTotal-vMem(GB)" -Value $TotalvmMemory       
     $VMHostresult | add-member -MemberType NoteProperty -Name "SSH" -Value $SSHservice  
     $VMHostresult | add-member -MemberType NoteProperty -Name "Uptime" -Value $UPtime    
     $VmHostresult   
   }  
 }
  
# Function to Calculate free % will be used further in Datastore Information function 
Function Percentcal {
    param(
    [parameter(Mandatory = $true)]
    [int]$InputNum1,
    [parameter(Mandatory = $true)]
    [int]$InputNum2)
    $InputNum1 / $InputNum2*100
}

#Function to Grab Datastore Information
Function Get-Dstore {
foreach ($vm in Get-VMHost) {
            
            Write-host "------------------------- Collecting Datastore Information Esxi $vm ------------------------------------" 

            foreach ( $ds in Get-Datastore -Server $vm.Name) {
            #Esxi Name and IP
            $esxname = $vm | Get-View
            $esxname = $esxname.Name
            $vmip = $vm.Name

            $dsfs = $ds.Name

            #Free %
            $PercentFree = Percentcal $ds.FreeSpaceMB $ds.CapacityMB
            $PercentFree = “{0:N2}” -f $PercentFree
            $PercentFree = [math]::round($PercentFree)

            #DataStore Alert Mail Function for Sending Email
            if ($PercentFree -le 10) {
            $bd = "Disk Space on $dsfs is less then $PercentFree % on $vmip - $esxname. Please Check"
            Send-MailMessage -To 'support@i2k2.com,opsteam@i2k2.com' -Body $bd -Subject "DataStore Space Alert - NOIDA on Esxi $vmip" -from 'alerts@i2k2.com' -smtpServer 127.0.0.1
            }
            
            #Used Space         
            $VmHostresult = New-Object PSObject
            $VmHostresult | add-member -MemberType NoteProperty -Name "HostIP" -Value $vmip
            $VmHostresult | add-member -MemberType NoteProperty -Name "HostName" -Value $esxname
            $VmHostresult | add-member -MemberType NoteProperty -Name "DataStore" -Value $dsfs
            $VmHostresult | add-member -MemberType NoteProperty -Name "Capacity(GB)" -Value ([math]::round($ds.CapacityGB))
            $VmHostresult | add-member -MemberType NoteProperty -Name "FreeSpace(GB) " -Value ([math]::round($ds.FreeSpaceGB))
            $VmHostresult | add-member -MemberType NoteProperty -Name "Free(%) " -Value $PercentFree
            $VmHostresult

        }         
    
 }
 }
  

$date = Get-Date -format "dd-MMM-yyyy HH:mm" 
$Esxinv = Get-VMHostinventory | Sort MGMT_IP |  ConvertTo-HTML -Fragment
$Dstinv = Get-Dstore | sort HostIP,DataStore | ConvertTo-HTML -Fragment
Write-host "------------------------- Generating Report ------------------------------------"
$bodydata = "<H1>ESXI & DATASTORE Info - Last Updated at $date | Update Frequency : 4 Hours</H1> <H2>ESXI</H2> $Esxinv <H2>DATASTORE</H2> $Dstinv"
ConvertTo-Html -head $a -body $bodydata | Out-File z:\project\EsxDst.htm

#Disconnect from VI server as Job Completed
disconnect-viserver * -confirm:$false 

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
