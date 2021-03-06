#
# AntiBotAlert by LetsBash.de
# 15.11.2021
# --------------------
# Function: Makes Bot Follower silent by automaticly pressing a hotkey
# Works best with OBS & Streamlabs
# 


# User vars - Can be edited by YOU
$release           = 40                            # Seconds to press the hotkey again
$webserverport     = "8085"                        # Local port for temporarly webserver (must match with OAuth Redirect URL - eg. http://127.0.0.1:8085)
$webserverwait     = 120                           # Seconds; How long should the webserver listen for an oauth request
$interval          = 2                             # Time between requests to twitch for checking the lastest follower
$filterbots        = 10                            # Bots must be active in the last x days
$maxfollowsatonce  = 5                             # Limit max follows in the range of $maxfollowsintime minutes (eg. max 5 follows in the last 10 minutes)
$maxfollowsintime  = 3                             # Defines the timerange in minutes for $maxfolloswatonce
$pattern           = @()                           # Do not modify
$pattern          += ".*(H|h)(o|0|O).*(s|S){2}.*"  # Regular expression of a bad follower


# Runtime vars - Modified by the process - Should you NOT edit
$hotkey       = ""                           # Hotkey for OBS
$clientid     = ""                           # Your extention client id
$channel      = ""                           # Name of your channel
$token        = ""                           # Your current authentication token or secret
$basedir      = ($PSScriptRoot + "\")        # Current path of your script
$channelid    = ""                           # Your channelid extracted by your provided channel- oder username
$latestfollow = ""                           # Your lastest follower on twitch
$matchfollow  = ""                           # Compare value for change detection
$botlist      = @()                          # Dynamic list of Botnames
$followcounts = @{}                          # Temporary store of your follower count

# Assemblies
$codeHotkeySender = @"
using System;
using System.Threading;
using System.Collections.Generic;
using System.Runtime.InteropServices;

public static class HotkeySender {    
    public enum InputType : uint {
        INPUT_MOUSE = 0,
        INPUT_KEYBOARD = 1,
        INPUT_HARDWARE = 3
    }

    [Flags]
    internal enum KEYEVENTF : uint
    {
        KEYDOWN = 0x0,
        EXTENDEDKEY = 0x0001,
        KEYUP = 0x0002,
        SCANCODE = 0x0008,
        UNICODE = 0x0004
    }

    [Flags]
    internal enum MOUSEEVENTF : uint
    {
        ABSOLUTE = 0x8000,
        HWHEEL = 0x01000,
        MOVE = 0x0001,
        MOVE_NOCOALESCE = 0x2000,
        LEFTDOWN = 0x0002,
        LEFTUP = 0x0004,
        RIGHTDOWN = 0x0008,
        RIGHTUP = 0x0010,
        MIDDLEDOWN = 0x0020,
        MIDDLEUP = 0x0040,
        VIRTUALDESK = 0x4000,
        WHEEL = 0x0800,
        XDOWN = 0x0080,
        XUP = 0x0100
    }

    // Master Input structure
    [StructLayout(LayoutKind.Sequential)]
    public struct lpInput {
        internal InputType type;
        internal InputUnion Data;
        internal static int Size { get { return Marshal.SizeOf(typeof(lpInput)); } }            
    }

    // Union structure
    [StructLayout(LayoutKind.Explicit)]
    internal struct InputUnion {
        [FieldOffset(0)]
        internal MOUSEINPUT mi;
        [FieldOffset(0)]
        internal KEYBDINPUT ki;
        [FieldOffset(0)]
        internal HARDWAREINPUT hi;
    }

    // Input Types
    [StructLayout(LayoutKind.Sequential)]
    internal struct MOUSEINPUT
    {
        internal int dx;
        internal int dy;
        internal int mouseData;
        internal MOUSEEVENTF dwFlags;
        internal uint time;
        internal UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct KEYBDINPUT
    {
        internal short wVk;
        internal short wScan;
        internal KEYEVENTF dwFlags;
        internal int time;
        internal UIntPtr dwExtraInfo;
    }

    [StructLayout(LayoutKind.Sequential)]
    internal struct HARDWAREINPUT
    {
        internal int uMsg;
        internal short wParamL;
        internal short wParamH;
    }

    private class unmanaged {
        [DllImport("user32.dll", SetLastError = true)]
        internal static extern uint SendInput (
            uint cInputs, 
            [MarshalAs(UnmanagedType.LPArray)]
            lpInput[] inputs,
            int cbSize
        );

        [DllImport("user32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
        public static extern short VkKeyScan(char ch);
    }

    internal static short VkKeyScan(char ch) {
        return unmanaged.VkKeyScan(ch);
    }

    internal static uint SendInput(uint cInputs, lpInput[] inputs, int cbSize) {
        return unmanaged.SendInput(cInputs, inputs, cbSize);
    }

    public static void SendScanCode(short scanCode) {
        lpInput[] KeyInputs = new lpInput[1];
        lpInput KeyInput = new lpInput();
        // Generic Keyboard Event
        KeyInput.type = InputType.INPUT_KEYBOARD;
        KeyInput.Data.ki.wScan = 0;
        KeyInput.Data.ki.time = 0;
        KeyInput.Data.ki.dwExtraInfo = UIntPtr.Zero;


        // Push the correct key
        KeyInput.Data.ki.wVk = scanCode;
        KeyInput.Data.ki.dwFlags = KEYEVENTF.KEYDOWN;
        KeyInputs[0] = KeyInput;
        SendInput(1, KeyInputs, lpInput.Size);
        Thread.Sleep(200);
        // Release the key
        KeyInput.Data.ki.dwFlags = KEYEVENTF.KEYUP;
        KeyInputs[0] = KeyInput;
        SendInput(1, KeyInputs, lpInput.Size);

        return;
    }

    public static void SendKeyboard(char ch) {
        lpInput[] KeyInputs = new lpInput[1];
        lpInput KeyInput = new lpInput();
        // Generic Keyboard Event
        KeyInput.type = InputType.INPUT_KEYBOARD;
        KeyInput.Data.ki.wScan = 0;
        KeyInput.Data.ki.time = 0;
        KeyInput.Data.ki.dwExtraInfo = UIntPtr.Zero;


        // Push the correct key
        KeyInput.Data.ki.wVk = VkKeyScan(ch);
        KeyInput.Data.ki.dwFlags = KEYEVENTF.KEYDOWN;
        KeyInputs[0] = KeyInput;
        SendInput(1, KeyInputs, lpInput.Size);

        // Release the key
        KeyInput.Data.ki.dwFlags = KEYEVENTF.KEYUP;
        KeyInputs[0] = KeyInput;
        SendInput(1, KeyInputs, lpInput.Size);

        return;
    }
}
"@
Add-Type -TypeDefinition $codeHotkeySender



function init_main {
    show_welcome
    init_hotkey
    init_channel
    init_clientid
    init_token
    init_channelid
    init_botdefinition
    init_testing
    
    # Enter processing state
    write-host ""
    write-host ""
    write-host "Start looking for followers..."
    write-host ""
    
    while($true) {
    
    	# Show progress
    	write-host "." -nonewline
	
	# Check latest follower
        init_cleanup_followcounts
        init_follower
        init_detector
	
	# Let the CPU rest
        sleep($Global:interval)
    }
}

function show_welcome {
    
    # Just show a simple header
    cls
    write-host ""
    write-host "Anti Bot Alert script (by LetsBash.de)"
    write-host "--------------------------------------"
    write-host ""
    write-host "How it works:"
    write-host ("This script connects to twitchinsights.net and retrives the latest known bots. After the script connects continuously to your twitch account and retrive the lastest follower. If the latest follower is somehow known as a bot then a hotkey press will be issued to hide your alertbox overlay in OBS Studio. After a delay the hotkey will be pressed again to show the alertbox as usual. Additionally, the number of your followers is kept in mind to detect possible bot raids.")
    write-host ""
}

function init_testing {

    # Testing hotkeys by pressing 4 times
    write-host ""
    write-host ("Testing Hotkey...")
    for ($i = 0; $i -lt 4; $i++){
        keypress
        sleep(3)
    }
    write-host ("Result: "+$i+" times pressed")
    write-host ("Testing Hotkey done")
}

function init_hotkey {
    # Create filepath string for channel
    $path = ($Global:basedir + "hotkey.txt")

    # Read filepath string if pressent
    if(test-path -path $path){
        $Global:hotkey = get-content -path $path
    }
    
    # Request hotkey until value is not empty
    while(($Global:hotkey).Length -eq 0) {
        $Global:hotkey = Read-Host -Prompt "What 'F' Key shoud be used as your hotkey (9 for F9)"

        # Throw error if still empty
        if(($Global:hotkey).Length -eq 0){
            write-host "Warning: Hotkey is empty!"
            write-host "         Please try again..."
        }

        # Add space to next output
        write-host ""
    }

    # Save to disk
    $Global:hotkey | Out-File -FilePath $path -NoNewline
}

function init_channel{

    # Create filepath string for channel
    $path = ($Global:basedir + "channel.txt")

    # Read filepath string if pressent
    if(test-path -path $path){
        $Global:channel = get-content -path $path
    }

    # Request clientid until value is not empty
    while(($Global:channel).Length -eq 0) {
        $Global:channel = Read-Host -Prompt "What is your Twitch channel name (eg. LetsBashDE)"

        # Throw error if still empty
        if(($Global:channel).Length -eq 0){
            write-host "Warning: Channel is empty!"
            write-host "         Please try again..."
        }

        # Add space to next output
        write-host ""
    }

    # Save to disk
    $Global:channel | Out-File -FilePath $path -NoNewline
}

function init_clientid {

    # Create filepath string for clientid
    $path = ($Global:basedir + "clientid.txt")

    # Read filepath string if pressent
    if(test-path -path $path){
        $Global:clientid = get-content -path $path
    }

    # Request clientid until value is not empty
    while(($Global:clientid).Length -eq 0) {

        # Open default browser and redirect client to twitch dev page and request client id for input
        start-process "https://dev.twitch.tv/console"
        write-host ("Please create a new extention with the OAuth Redirect URL 'http://127.0.0.1:"+$Global:webserverport+"'")
        $Global:clientid = Read-Host -Prompt "Client ID of the new Extention"

        # Throw error if still empty
        if(($Global:clientid).Length -eq 0){
            write-host "Warning: Client-ID is empty!"
            write-host "         Please try again..."
        }

        # Add space to next output
        write-host ""
    }

    # Save to disk
    $Global:clientid | Out-File -FilePath $path -NoNewline
}

function init_token {
    
    # Create filepath string for clientid
    $path = ($Global:basedir + "token.txt")

    # Load token if exist
    if(test-path -path $path){
        $Global:token = get-content -path $path
        return 
    }

    # Prepare Webserver for callback authentication
    $http = [System.Net.HttpListener]::new() 
    $http.Prefixes.Add(("http://127.0.0.1:"+$Global:webserverport+"/"))
    $http.Start()

    # Trigger emergency webserver close first
    start-process ("http://127.0.0.1:"+$Global:webserverport+"/emergency/")
    sleep(1)

    # Start Oauth request to twitch
    start-process ("https://id.twitch.tv/oauth2/authorize?client_id="+$Global:clientid+"&response_type=token&redirect_uri=http://127.0.0.1:"+$Global:webserverport+"&scope=user:read:follows")

    # Wait for incomming transmissions
    while ($http.IsListening) {

        # Retrive Request from Webserver
        $context = $http.GetContext()

        # Request one: First time response from twitch
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -eq '/') {
            echo "Webserver: Catch Twitch token"
            [string]$html = ("<script>var z = (((window.location.href).split('access_token='))[1].split('&scope'))[0]; window.location.replace(('http://127.0.0.1:"+$Global:webserverport+"/x/'+z))</script>")
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $context.Response.OutputStream.Close()
        }

        # Request two: Javascript corrected response
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -like '/x/*') {
            echo "Webserver: Storing Twitch token"
            [string]$html = "<html><body><center><br><br><br><br><h1><font face='arial'>Bashys Twitch Authentication Helper</font></h1><h2><font face='arial'>Powerd by <a href='https://letsbash.de' target='_blank'>LetsBash.de</a></font></h2><h3><font face='arial'>You can close this window now</font></h3></center></body></html>"
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $context.Response.OutputStream.Close()

            # Stop Webserver
            sleep(2)
            $http.stop()
            
            # Store token
            $url = ($context.Request.RawUrl)
            $Global:token = ($url -split "[\/]x[\/]")[1]
            $Global:token | Out-File -FilePath $path -NoNewline
        }

        # Prepare emergengy stop with delay
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -like '/emergency/') {
            echo "Webserver: Emergency shutdown timer [Enabled]"
            [string]$html = ("<html><head><meta http-equiv=`"refresh`" content=`""+$webserverwait+"; URL='http://127.0.0.1:"+$Global:webserverport+"/close/'`"></head><body><center><h1><a href='http://127.0.0.1:"+$Global:webserverport+"/close/'>Emergency Webserver Shutdown</a></h1></center></body><html>")
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $context.Response.OutputStream.Close()
        }

        # Site for emergengy listener stop
        if ($context.Request.HttpMethod -eq 'GET' -and $context.Request.RawUrl -like '/close/') {
            echo "Webserver: Emergency shutdown [Completed]"
            [string]$html = ("<html><body><h1>Notice</h1><h2>Local Webserver has been shutdown</h2></body></html>")
            $buffer = [System.Text.Encoding]::UTF8.GetBytes($html)
            $context.Response.ContentLength64 = $buffer.Length
            $context.Response.OutputStream.Write($buffer, 0, $buffer.Length)
            $context.Response.OutputStream.Close()

            # Stop Webserver
            sleep(2)
            $http.stop()
        }
    }
}


function init_destroy_token {

    # Prepare fresh start
    del ($Global:basedir + "token.txt")
    write-host "Error: Token seams to be invalid. Please restart application and refresh token."

}

function init_destroy_channel {

    # Prepare fresh start
    del ($Global:basedir + "channel.txt")
    del ($Global:basedir + "clientid.txt")
    write-host "Error: Channel seams to be invalid. Please restart application and reenter your channelname."

}

function init_kill {

    # Come to an end
    write-host "Error: Could not retrive latest follower."
    sleep(5)
    exit

}


function init_channelid {
    
    # Prepare Webrequest
    $url = ("https://api.twitch.tv/helix/users?login="+$Global:channel)
    $webquery = New-Object -ComObject "Msxml2.ServerXMLHTTP.6.0"
    $webquery.SetOption(2, 'objHTTP.GetOption(2) - SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS')
    $webquery.open('GET', $url, $false)
    $webquery.setRequestHeader("Authorization", ("Bearer "+$Global:token))
    $webquery.setRequestHeader("Client-Id", $Global:clientid)
    $webquery.SetRequestHeader("Pragma", "no-cache")
    $webquery.SetRequestHeader("Cache-Control", "no-cache")
    $webquery.SetRequestHeader("If-Modified-Since", "Sat, 1 Jan 2000 00:00:00 GMT")
    [long]$timeout = 2000
    $webquery.SetTimeouts($timeout,$timeout,$timeout,$timeout)
    $webquery.send()
    
    # Extract channel id
    if($webquery.statusText -like "*OK*"){
        if($webquery.responseText -like ("*"+'"id":"'+"*")){
            $Global:channelid = (((($webquery.responseText) -split "id`":`"")[1]) -split "`"")[0]
        }
    }

    # Start fresh again on error
    if(($Global:channelid).Length -eq 0) {
        init_destroy_token
        init_destroy_channel
        init_kill
    }
}

function init_cleanup_followcounts {

    # Cleanup followercounts
    if($Global:followcounts.count -ge 0) {
        $limit = (((get-date -Uformat %s)-split ",")[0]) - ($Global:maxfollowsintime * 60)
        $keys = @($Global:followcounts.keys)
        foreach($key in $keys) {
            if($key -le $limit) {
                $Global:followcounts.remove($key)
            }
        }
    }
}

function init_follower {

    # Prepare Webrequest
    $url = ("https://api.twitch.tv/helix/users/follows?to_id="+$Global:channelid)
    $webquery = New-Object -ComObject "Msxml2.ServerXMLHTTP.6.0"
    $webquery.SetOption(2, 'objHTTP.GetOption(2) - SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS')
    $webquery.open('GET', $url, $false)
    $webquery.setRequestHeader("Authorization", ("Bearer "+$Global:token))
    $webquery.setRequestHeader("Client-Id", $Global:clientid)
    $webquery.SetRequestHeader("Pragma", "no-cache")
    $webquery.SetRequestHeader("Cache-Control", "no-cache")
    $webquery.SetRequestHeader("If-Modified-Since", "Sat, 1 Jan 2000 00:00:00 GMT")
    [long]$timeout = 2000
    $webquery.SetTimeouts($timeout,$timeout,$timeout,$timeout)
    
    # Silently drop errors if twitch does not respond
    try { 
    	$webquery.send()
    } catch {}
    
    # Extract latest follower and follower count
    if($webquery.statusText -like "*OK*"){
        if($webquery.responseText -like ("*"+'"from_name":"'+"*")){
            $Global:latestfollow = (((($webquery.responseText) -split "from_name`":`"")[1]) -split "`"")[0]
        }
        if($webquery.responseText -like ("*"+'"total":'+"*")){
            $Global:followcounts[(((get-date -Uformat %s) -split ",")[0])] = (((($webquery.responseText) -split ",")[0]) -split ":")[1]
        }
    }

    # If first request failes than exit
    if(($Global:latestfollow).Length -eq 0) {
        init_kill
    }

    # Remember latest follow next time
    if(($Global:matchfollow).Length -eq 0) {
         $Global:matchfollow = $Global:latestfollow
    }

}

function init_botdefinition {

    # Create filepath string for clientid
    $path = ($Global:basedir + "bots.txt")

    # Status output
    write-host "Start downloading Bot definitions from twitchinsights.net"
    
    # Prepare Webrequest
    $url = ("https://api.twitchinsights.net/v1/bots/all")
    $webquery = New-Object -ComObject "Msxml2.ServerXMLHTTP.6.0"
    $webquery.SetOption(2, 'objHTTP.GetOption(2) - SXH_SERVER_CERT_IGNORE_ALL_SERVER_ERRORS')
    $webquery.open('GET', $url, $false)
    $webquery.SetRequestHeader("Pragma", "no-cache")
    $webquery.SetRequestHeader("Cache-Control", "no-cache")
    $webquery.SetRequestHeader("If-Modified-Since", "Sat, 1 Jan 2000 00:00:00 GMT")
    [long]$timeout = 10000
    $webquery.SetTimeouts($timeout,$timeout,$timeout,$timeout)
    $webquery.send()
    
    # Extract channel id
    if($webquery.statusText -like "*OK*"){

        # Check if Json is valid
        if($webquery.responseText -like ("*"+'"bots":'+"*")){

            # Make Json addressable
            $json = ConvertFrom-Json -InputObject $webquery.responseText

            # Define minimum timestamp
            $mintimestamp = [int](Get-Date -UFormat %s -Millisecond 0) - ($Global:filterbots * 86400)

            # For each Bot in list
            foreach($bot in $json.bots){
                
                # If latest activity is lower than defined timerange then skip
                if($bot[2] -lt $mintimestamp){
                    continue
                }

                # Add definiton to active list
                $Global:botlist += $bot[0]
            }

            # Status output
            write-host ("Downloaded "+(($Global:botlist).count)+" definitions of Bots")

            # Save to disk
            if(($Global:botlist).count -gt 0){
                $Global:botlist -join ";" | Out-File -FilePath $path -NoNewline
            }
        }
    }

    # If Bot definition is still empty load last known good
    if(($Global:botlist).count -eq 0){
        write-host ("Could not download lastest Bot definitions")
        if(test-path -Path $path){
            $Global:botlist = (get-content -path $path) -split ";"
            write-host ("Loaded "+(($Global:botlist).count)+" definitions of Bots from disk")
        }
        else {
            write-host ("Could not find any local cached Bot definitions on disk")
        }
    }

}

function init_detector {
    
    # Check if a new follower appers
    if($Global:matchfollow -eq $Global:latestfollow){
        return
    }
    
    # Show information if change has been detected
    write-host ""
    write-host ("Latest follower changed: "+$Global:latestfollow)

    # Remember the new follower on next matchmaking
    $Global:matchfollow = $Global:latestfollow

    # Define default value
    $bot = $false


    foreach($expression in $Global:pattern){
        
        # If expression matches then set action to go
        if(($Global:latestfollow) -match $expression) {
            $bot = $true
            break
        }
    }

    # Check botlist for entry
    if($bot -eq $false) {
        if($Global:botlist -contains (($Global:latestfollow).ToLower())){
            $bot = $true
        }
    }

    # Check followercount
    if($bot -eq $false -and $Global:followcounts.count -ge 1) {
        $oldestkey = @($Global:followcounts.keys)[$Global:followcounts.count - 1]
        $newestkey = @($Global:followcounts.keys)[0]
        $difference = $Global:followcounts[$newestkey] - $Global:followcounts[$oldestkey]
        if($difference -gt $Global:maxfollowsatonce) {
            $massfollows = $true
        }
    }

    # Commence action if bad guy or mass follows has been detected
    if($bot -eq $true -or $massfollows -eq $true){

        # Output to console
        if($bot -eq $true){
            write-host ("Follower "+$Global:latestfollow+" looks like a bad guy!") -ForegroundColor Yellow
        }
        else {
            write-host ("Mass Follows ("+($Global:followcounts[$oldestkey])+" to "+($Global:followcounts[$newestkey])+") detected!") -ForegroundColor Yellow
        }

        # Press hotkey and wait
        keypress 
        write-host ("Wait "+$Global:release+" seconds for release") -ForegroundColor Cyan
        sleep($Global:release)
        keypress

        # Clear current followercount
        $Global:followcounts = @{}
    }
    
    write-host ""
}

function keypress {
    
    # Write Keypress to console
    write-host ("Action: Hotkey F"+$Global:hotkey+" send") -ForegroundColor Cyan
    
    # Execute Keypress
    switch ($Global:hotkey) {
        1 { [HotkeySender]::SendScanCode(0x70); break; }
        2 { [HotkeySender]::SendScanCode(0x71); break; }
        3 { [HotkeySender]::SendScanCode(0x72); break; }
        4 { [HotkeySender]::SendScanCode(0x73); break; }
        5 { [HotkeySender]::SendScanCode(0x74); break; }
        6 { [HotkeySender]::SendScanCode(0x75); break; }
        7 { [HotkeySender]::SendScanCode(0x76); break; }
        8 { [HotkeySender]::SendScanCode(0x77); break; }
        9 { [HotkeySender]::SendScanCode(0x78); break; }
        10 { [HotkeySender]::SendScanCode(0x79); break; }
        11 { [HotkeySender]::SendScanCode(0x7A); break; }
        12 { [HotkeySender]::SendScanCode(0x7B); break; }
    }

}

init_main
