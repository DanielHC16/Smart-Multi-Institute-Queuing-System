# Option #1

1. Run MyPublicWifi
2. Host a hotspot
3. Create a captive portal

FAIL: Captive Portal is not customizable. 

# Option #2
1. Setup a hosted network using windows script

FAIL: Hosted network is not supported in the device

# Option 3
1. Turn on hosted network manually
2. Setup the captive network using windows script

FAIL: Certificate, Linux, Nasira firewall ko 

# Option 4
1. Use MyPublicWifi
2. Use DNSChef to redirect gstatic
3. Redirect to landing page

SUCCESS: Landing page is accessible even through custom network
FAIL: Redirection is not working. Port 53 is used. Windows won't allow stopping even as admin