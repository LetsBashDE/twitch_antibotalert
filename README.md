# Whats is this
Some time ago the bot Hoss00312 started to get on my nerves.
So I created a simple powershell script "twich_hossa" that works with the Twitch Helix API.
But a week later Hoss00312 disappeared from Twitch and was never seen again. 
So I decided to extend the script to a better generic "Anti Bot Alert" system that dynamically captures all known bots from twitchinsights.net that were active in the last 10 days.
Of course, it's Powershell - so it only works with Windows and I have no plans to port this script.

# Videos
There Videos are originaly from "twitch_hossa" but it works exactly the same for your.
- German: https://www.youtube.com/watch?v=tfht5v6GYQc
- English: https://www.youtube.com/watch?v=WbfpptzvEuo

# What it does
Basicly the Script is checking continuesly the latest follower of your channel and if first a regular
expression matches to the user or second the username matches with a known Bot then a hotkey will be pressed by the script to hide your notification source in OBS.
After a defined time the hotkey will be pressed again to activate the source again.

# Requirements
Since we made a huge change to our code you may don´t need any of this, but just in case I leave the links down below.
- Visual C++ Redistributable for Visual Studio
  - For 32-Bit Operating Systems: https://aka.ms/vs/16/release/vc_redist.x86.exe
  - For 64-Bit Operating Systems: https://aka.ms/vs/16/release/vc_redist.x64.exe
  
# How to run
- You need to have 2 factor/mfa authentication enabled on your Twitch account. (All Affiliate should have this already)
- Place the init.cmd and process.ps1 into the same directory of your choice.
- Start the init.cmd file and follow the assistant
  - Define the F1-12 Key as a Hotkey
  - Enter your channel name
  - Create a new extention with a Name and a defined OAuth Redirect URL
  - Let the script authenticate and get the token
- Next time you run the init.cmd all settings will be loaded automaticly
- Setup your Alertbox with a delay of 5 seconds
  - On Streamlabs you can change this on the website for every alert

# A new Bot is going on my nerves!
If a simelar Bot to Hoss is back in town then you can add regular expressions to hide that alerts. Edit the process.ps1 and look for "$pattern      += ".*(0|o|O)312.*"            # Regular expression of a bad follower". Just copy that line and define a new regular expression in the brackets ".*(0|o|O)312.*". Normaly regular expressions start and end with a slash, but in powershell this is not the case. If you would like to test your expressions then head to http://regex101.com

# When it failes or start fresh
If something goes wrong you can delete the channel.txt, clientid.txt and token.txt files that will be placed in the same directory as init.cmd and process.ps1.

# Things you should not do
You must not run this as an Administrator because of the path "execute at folder" definition of windows. Programms that will be run as Administrator starts usualy at %winwir%\system32. If you realy want this script to run as an administrator then edit the init.cmd and delete the line 5 "goto execute". Then execute the init.cmd normaly and it will evelate itself into the administrative executionlayer.

# License
You are free to use this code and modify it by your own, but a credit to LetsBash.de must be included.

# Warranty
This script does not come with any warranty and will be provided as it is.

# Is this dangerous?
Nope - Everything regarding processing and authentication will be handeld between your computer and twitch. But you should not store the script on a public folder.
