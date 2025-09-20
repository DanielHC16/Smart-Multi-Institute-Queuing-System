# ==============================
# Captive Portal on Windows (with Mobile Hotspot)
# Run this script *after* turning on Mobile Hotspot in Settings.
# ==============================

# Variables
$PortalIP   = "192.168.137.1"   # Default gateway for Windows hotspot
$PortalPort = 1000
$FirewallRuleName = "CaptivePortalRedirect"

# Stop old listeners if any
Get-Process -Name "powershell" -ErrorAction SilentlyContinue | 
    Where-Object { $_.MainWindowTitle -like "*CaptivePortal*" } | 
    Stop-Process -Force

# Remove existing firewall rule if it exists
if (Get-NetFirewallRule -DisplayName $FirewallRuleName -ErrorAction SilentlyContinue) {
    Remove-NetFirewallRule -DisplayName $FirewallRuleName
}

# Add firewall rule to redirect HTTP (80) → captive portal port
# NOTE: This uses netsh since Windows Firewall cmdlets don't support port redirection
Start-Process -FilePath "netsh" -ArgumentList "interface portproxy add v4tov4 listenport=80 listenaddress=0.0.0.0 connectport=$PortalPort connectaddress=$PortalIP" -Wait -NoNewWindow

# Function to serve a basic HTML portal
function Start-CaptivePortal {
    param([string]$ip, [int]$port)

    $listener = New-Object System.Net.HttpListener
    $prefix = "http://${ip}:${port}/"
    $listener.Prefixes.Add($prefix)
    $listener.Start()

    Write-Host "✅ Captive portal running at $prefix"
    Write-Host "Press Ctrl+C to stop."

    while ($listener.IsListening) {
        try {
            $context = $listener.GetContext()
            $response = $context.Response
            $response.ContentType = "text/html"

            $html = @"
<!DOCTYPE html>
<html>
<head>
  <title>Welcome to My Captive Portal</title>
  <style>
    body { font-family: Arial, sans-serif; background: #f0f0f0; text-align:center; padding:50px; }
    .box { background:white; padding:20px; border-radius:10px; display:inline-block; }
    button { padding:10px 20px; font-size:16px; }
  </style>
</head>
<body>
  <div class="box">
    <h1>Welcome to My Hotspot</h1>
    <p>You must log in to access the internet.</p>
    <form>
      <input type="text" placeholder="Username"><br><br>
      <input type="password" placeholder="Password"><br><br>
      <button type="submit">Login</button>
    </form>
  </div>
</body>
</html>
"@

            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $response.OutputStream.Write($buffer, 0, $buffer.Length)
            $response.OutputStream.Close()
        } catch {
            Write-Warning "Error handling request: $_"
        }
    }
}

# Start the captive portal
Start-CaptivePortal -ip $PortalIP -port $PortalPort
