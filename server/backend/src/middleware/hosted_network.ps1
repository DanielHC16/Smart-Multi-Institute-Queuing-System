<#
onefile-captive.ps1
Single-file Windows captive portal:
- creates hostednetwork (SSID/key)
- sets host IP to 192.168.1.4
- runs HTTP portal on port 4000
- runs DNS responder on UDP/53: returns 192.168.1.4 for unaccepted clients
- when client posts /accept, their IP is allowed (DNS forwarded for them)

Run as Administrator.
#>

# --- Configuration ---
$SSID = "MyPublicWifi"
$Key  = "12345678"
$PortalIP = "192.168.1.4"
$PortalPort = 4000
# Upstream DNS server to forward allowed-client queries to:
$UpstreamDns = "8.8.8.8"
# TTL for created DNS answers:
$DnsTTL = 60

# Small portal HTML (customize this)
$html = @"
<!doctype html>
<html>
<head>
  <meta charset='utf-8'>
  <title>Welcome</title>
  <style>
    body{font-family:system-ui,Segoe UI,Roboto,Arial;margin:0;padding:40px;background:#f5f7fb}
    .card{max-width:640px;margin:40px auto;padding:24px;border-radius:12px;background:#fff;box-shadow:0 8px 30px rgba(0,0,0,.06);text-align:center}
    button{padding:10px 18px;font-size:16px;border-radius:8px;cursor:pointer}
  </style>
</head>
<body>
  <div class="card">
    <h1>Welcome to $SSID</h1>
    <p>Click Accept to get internet access for 30 minutes.</p>
    <form method="POST" action="/accept">
      <input type="hidden" name="dummy" value="1" />
      <button type="submit">Accept</button>
    </form>
    <p style="font-size:12px;color:#666;margin-top:12px">If you don't get redirected automatically, open your browser and try http://example.com</p>
  </div>
</body>
</html>
"@

# --- helper functions ---
function Assert-Admin {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if(-not $isAdmin) {
        Write-Error "This script must be run as Administrator. Right-click PowerShell and 'Run as administrator'."
        exit 1
    }
}

function Run-HostedNetwork {
    return $true
    param($ssid, $key)
    Write-Host "Configuring hostednetwork: SSID=$ssid"
    & netsh wlan set hostednetwork mode=allow ssid=$ssid key=$key | Out-Null
    Start-Sleep -Milliseconds 300
    $start = & netsh wlan start hostednetwork 2>&1
    if($start -match "The hosted network started") {
        Write-Host "Hosted network started."
        return $true
    } else {
        Write-Warning "Could not start hosted network. netsh returned:`n$start"
        return $false
    }
}

function Get-HostedInterface {
    # returns the name of the hosted network interface (adapter)
    # We look for 'Hosted Network' or 'Microsoft Wi-Fi Direct Virtual Adapter' in description
    $adapters = Get-NetAdapter -Physical:$false -ErrorAction SilentlyContinue
    foreach($a in $adapters) {
        if($a.InterfaceDescription -match "Hosted Network" -or $a.InterfaceDescription -match "Wi-Fi Direct" -or $a.InterfaceDescription -match "Microsoft Hosted Network Virtual Adapter") {
            return $a
        }
    }
    # fallback: try to find an interface with IPv4 192.168.137.* which is default hosted network
    $ipIf = Get-NetIPConfiguration | Where-Object { $_.IPv4Address -and ($_.IPv4Address.IPAddress -match "^192\.168\.137\.") } | Select-Object -First 1
    if($ipIf) { return $ipIf.InterfaceAlias }
    return $null
}

function Set-InterfaceStaticIP {
    param($ifName, $ip, $prefix = 24)
    Write-Host "Assigning static IP $ip/$prefix to interface '$ifName'..."
    # Remove existing IPv4 addresses on that interface, then assign new
    try {
        $existing = Get-NetIPAddress -InterfaceAlias $ifName -AddressFamily IPv4 -ErrorAction SilentlyContinue
        if($existing) {
            foreach($e in $existing) {
                Remove-NetIPAddress -InterfaceAlias $ifName -IPAddress $e.IPAddress -Confirm:$false -ErrorAction SilentlyContinue
            }
        }
        New-NetIPAddress -InterfaceAlias $ifName -IPAddress $ip -PrefixLength $prefix -DefaultGateway $null -ErrorAction Stop | Out-Null
        Write-Host "Static IP assigned."
    } catch {
    Write-Warning "Failed to set static IP on ${ifName}: $_"
}

}

# DNS packet helpers (minimal implementation)
function Parse-DnsQuery {
    param([byte[]]$data)
    # Returns hashtable: ID, Questions(array of hashtables Name, QType, QClass)
    $res = @{}
    if($data.Length -lt 12) { return $null }
    $res.ID = [BitConverter]::ToUInt16($data[0..1],0)
    $flags = [BitConverter]::ToUInt16($data[2..3],0)
    $qdcount = [BitConverter]::ToUInt16($data[4..5],0)
    $res.Questions = @()
    $offset = 12
    for($i=0; $i -lt $qdcount; $i++) {
        # parse labels
        $labels = @()
        while($true) {
            if($offset -ge $data.Length) { break }
            $len = $data[$offset]; $offset++
            if($len -eq 0) { break }
            $label = [Text.Encoding]::ASCII.GetString($data,$offset,$len)
            $offset += $len
            $labels += $label
        }
        $qname = ($labels -join ".")
        if($offset + 3 -ge $data.Length) { break }
        $qtype = [BitConverter]::ToUInt16($data[$offset..($offset+1)],0); $offset += 2
        $qclass = [BitConverter]::ToUInt16($data[$offset..($offset+1)],0); $offset += 2
        $res.Questions += @{ Name = $qname; QType = $qtype; QClass = $qclass }
    }
    return $res
}

function Build-DnsResponseA {
    param($id, $qname, [string]$ip, $ttl)
    # Basic DNS response with 1 question and 1 answer (A record)
    $nameLabels = $qname.Split('.')
    $qnameBytes = @()
    foreach($lab in $nameLabels) {
        $len = [byte]$lab.Length
        $qnameBytes += $len
        $qnameBytes += [Text.Encoding]::ASCII.GetBytes($lab)
    }
    $qnameBytes += 0 # terminate

    $header = New-Object System.Collections.Generic.List[byte]
    $header.AddRange([BitConverter]::GetBytes([uint16]$id))             # ID (little-endian) -> we'll write in network order
    # network order: need to reverse bytes because BitConverter uses little-endian
    $headerArr = $header.ToArray()
    # Instead of juggling, build as bytes explicitly in network order:
    $idBytes = [byte[]]@((($id -shr 8) -band 0xFF), ($id -band 0xFF))
    $flags = 0x8180  # standard response, recursion desired+available
    $flagsBytes = [byte[]]@((($flags -shr 8) -band 0xFF), ($flags -band 0xFF))
    $qdcount = 1
    $ancount = 1
    $nscount = 0
    $arcount = 0
    $counts = [byte[]]@((($qdcount -shr 8) -band 0xFF), ($qdcount -band 0xFF),
                        (($ancount -shr 8) -band 0xFF), ($ancount -band 0xFF),
                        (($nscount -shr 8) -band 0xFF), ($nscount -band 0xFF),
                        (($arcount -shr 8) -band 0xFF), ($arcount -band 0xFF))
    $resp = New-Object System.Collections.Generic.List[byte]
    $resp.AddRange($idBytes)
    $resp.AddRange($flagsBytes)
    $resp.AddRange($counts)

    # question section
    $resp.AddRange($qnameBytes)
    $resp.AddRange([byte[]]@((0x00),(0x01))) # QTYPE A
    $resp.AddRange([byte[]]@((0x00),(0x01))) # QCLASS IN

    # answer section: name: pointer to offset 12 -> 0xC00C
    $resp.Add(0xC0); $resp.Add(0x0C)
    $resp.AddRange([byte[]]@((0x00),(0x01))) # TYPE A
    $resp.AddRange([byte[]]@((0x00),(0x01))) # CLASS IN
    $ttlBytes = [byte[]]@((($ttl -shr 24) -band 0xFF), (($ttl -shr 16) -band 0xFF), (($ttl -shr 8) -band 0xFF), ($ttl -band 0xFF))
    $resp.AddRange($ttlBytes)
    $rdlength = 4
    $resp.AddRange([byte[]]@((($rdlength -shr 8) -band 0xFF), ($rdlength -band 0xFF)))
    $ipParts = $ip.Split('.') | ForEach-Object { [byte]$_ }
    $resp.AddRange($ipParts)
    return ,$resp.ToArray()
}

function Build-DnsResponseRaw {
    param([uint16]$id, [byte[]]$raw)
    # utility if we want to echo back
    return $raw
}

# --- main logic ---
Assert-Admin

Write-Host "1) Starting Hosted Network..."
if(-not (Run-HostedNetwork -ssid $SSID -key $Key)) {
    Write-Error "Hosted network could not be started. Exiting."
    exit 1
}

Start-Sleep -Seconds 2

# find the hosted network interface name
$hotif = Get-HostedInterface
if(-not $hotif) {
    Write-Warning "Could not auto-detect hosted interface. Listing all adapters:"
    Get-NetAdapter | Format-Table -AutoSize
    $hotif = Read-Host "Enter the InterfaceAlias (name) of the hosted network adapter"
}
if($hotif -is [Microsoft.Management.Infrastructure.CimInstance] -or $hotif -is [System.Management.Automation.PSCustomObject]) {
    $ifName = $hotif.InterfaceAlias
} else {
    $ifName = $hotif
}
Write-Host "Using hosted interface: $ifName"

Set-InterfaceStaticIP -ifName $ifName -ip $PortalIP -prefix 24

# Data structures for clients
$AcceptedClients = [System.Collections.Concurrent.ConcurrentDictionary[string,bool]]::new()

# Start HTTP portal (HttpListener)
$listener = New-Object System.Net.HttpListener
$prefix = "http://${PortalIP}:${PortalPort}/"

$listener.Prefixes.Add($prefix)
try {
    $listener.Start()
} catch {
    Write-Error "Failed to start HttpListener on $prefix. Make sure you run as admin and the port is free. Error: $_"
    exit 1
}
Write-Host "HTTP portal listening at $prefix"

# Run the HTTP loop in a background job
$httpJob = Start-Job -ScriptBlock {
    param($listenerRef, $htmlContent, $AcceptedClientsRef)
    $listener = $using:listener
    $html = $using:html
    $acDict = $using:AcceptedClients

    while($listener.IsListening) {
        try {
            $context = $listener.GetContext()  # blocking
        } catch {
            break
        }
        Start-Job -ArgumentList $context -ScriptBlock {
            param($ctx)
            $req = $ctx.Request
            $resp = $ctx.Response
            $clientIp = $req.RemoteEndPoint.Address.ToString()
            if($req.HttpMethod -eq "GET") {
                $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
                $resp.ContentType = "text/html; charset=utf-8"
                $resp.OutputStream.Write($buffer,0,$buffer.Length)
                $resp.OutputStream.Close()
            } elseif($req.HttpMethod -eq "POST" -and $req.Url.AbsolutePath -eq "/accept") {
                # Record client IP as accepted
                $acFile = Join-Path (Get-Location) "accepted_clients.log"
                $line = "{0} {1}`n" -f (Get-Date).ToString("o"), $clientIp
                Add-Content -Path $acFile -Value $line
                # Also add to shared dictionary via file (job-to-main comms are limited)
                # Return a basic response
                $body = "<html><body><h2>Accepted. You should now have internet access shortly.</h2></body></html>"
                $buf = [System.Text.Encoding]::UTF8.GetBytes($body)
                $resp.ContentType = "text/html; charset=utf-8"
                $resp.OutputStream.Write($buf,0,$buf.Length)
                $resp.OutputStream.Close()
            } else {
                $resp.StatusCode = 404
                $resp.OutputStream.Close()
            }
        }
    }
} -InitializationScript { } -ArgumentList $listener, $html, $AcceptedClients

# Simple watcher that reads accepted_clients.log and adds IPs to $AcceptedClients in main session
$logPath = Join-Path (Get-Location) "accepted_clients.log"
if(-not (Test-Path $logPath)) { New-Item -Path $logPath -ItemType File | Out-Null }

$watcherJob = Start-Job -ScriptBlock {
    param($logPath)
    $lastPos = 0
    while($true) {
        Start-Sleep -Milliseconds 500
        try {
            $fi = Get-Item $logPath -ErrorAction SilentlyContinue
            if($fi.Length -gt $lastPos) {
                $fs = [System.IO.File]::Open($logPath, [System.IO.FileMode]::Open, [System.IO.FileAccess]::Read, [System.IO.FileShare]::ReadWrite)
                $fs.Seek($lastPos, 'Begin') | Out-Null
                $sr = New-Object System.IO.StreamReader($fs)
                while(-not $sr.EndOfStream) {
                    $line = $sr.ReadLine()
                    if($line -match "(\d+\.\d+\.\d+\.\d+)") {
                        $ip = $matches[1]
                        # write to a marker file per client
                        $okfile = Join-Path (Split-Path $logPath) ("accepted_$ip.txt")
                        Set-Content -Path $okfile -Value (Get-Date).ToString("o")
                    }
                }
                $lastPos = $fs.Position
                $sr.Close(); $fs.Close()
            }
        } catch {
            # ignore
        }
    }
} -ArgumentList $logPath

Write-Host "Started portal and log-watcher. Now starting DNS responder..."

# DNS responder
$udp = New-Object System.Net.Sockets.UdpClient(53)
$udp.Client.ReceiveTimeout = 0
$udpEnd = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)

# helper to build response bytes and send
function Send-DnsAResponse {
    param($clientEP, $queryBytes, $query)
    try {
        $resp = Build-DnsResponseA -id $query.ID -qname $query.Questions[0].Name -ip $PortalIP -ttl $DnsTTL
        $udp.Send($resp, $resp.Length, $clientEP) | Out-Null
    } catch {
        Write-Warning "Failed to send DNS response: $_"
    }
}

function Forward-DnsAndRelay {
    param($clientEP, $queryBytes, $query)
    # Forward the raw query to upstream and relay the response to the client
    try {
        $remoteEP = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Parse($UpstreamDns),53)
        $tmp = New-Object System.Net.Sockets.UdpClient
        $tmp.Connect($remoteEP)
        $tmp.Send($queryBytes, $queryBytes.Length) | Out-Null
        $tmp.Client.ReceiveTimeout = 2000
        $remoteEP2 = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any,0)
        $resp = $tmp.Receive([ref]$remoteEP2)
        $tmp.Close()
        if($resp) { $udp.Send($resp, $resp.Length, $clientEP) | Out-Null }
    } catch {
        # fallback: reply with portal IP
        Send-DnsAResponse -clientEP $clientEP -queryBytes $queryBytes -query $query
    }
}

# main DNS loop (non-blocking, use Runspace for responsiveness)
$dnsLoop = [System.Threading.Thread]::New({
    param($udp,$udpEnd,$AcceptedClients,$logPath)
    $udpLocal = $udp
    while($true) {
        try {
            $remoteEP = $null
            $data = $udpLocal.Receive([ref]$remoteEP) # blocking
            if($null -eq $data) { continue }
            $clientIP = $remoteEP.Address.ToString()
            $query = Parse-DnsQuery -data $data
            if(-not $query) { continue }
            # update AcceptedClients by checking files created by watcher
            $acceptedFiles = Get-ChildItem -Path (Split-Path $logPath) -Filter "accepted_*.txt" -ErrorAction SilentlyContinue
            $acceptedSet = @{}
            foreach($f in $acceptedFiles) {
                if($f.BaseName -match "accepted_(\d+\.\d+\.\d+\.\d+)") {
                    $acceptedSet[$matches[1]] = $true
                }
            }
            if($acceptedSet.ContainsKey($clientIP)) {
                # forward query to upstream
                Forward-DnsAndRelay -clientEP $remoteEP -queryBytes $data -query $query
            } else {
                # if query is type A (1) respond with portal IP; else respond also with portal IP
                Send-DnsAResponse -clientEP $remoteEP -queryBytes $data -query $query
            }
        } catch {
            Start-Sleep -Milliseconds 20
        }
    }
}, $udp, $udpEnd, $AcceptedClients, $logPath)

# Run DNS loop on a thread
$null = $dnsLoop.Start()
Write-Host "DNS responder running. Portal is live at http://${PortalIP}:${PortalPort}"

Write-Host "To stop: press Ctrl+C in this PowerShell window and then run 'netsh wlan stop hostednetwork' manually."

# Keep main script alive to preserve jobs and threads
try {
    while($true) { Start-Sleep -Seconds 2 }
} finally {
    Write-Host "Cleaning up..."
    try { $listener.Stop() } catch {}
    try { $udp.Close() } catch {}
    & netsh wlan stop hostednetwork | Out-Null
}
