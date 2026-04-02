# How I have streamlined my work with VS Code and GitHub Copilot CLI
I am going to include as much background as to how I ended up here. If you don't care about that and just want to understand my install and what I am doing, feel free to jump down [there](#install)

I am trying to streamline what a simple use case would be for this and how I would use it on a day-to-day basis.

What does CLI mean? Command Line Interface...start playing music from the 80s here. Really, graduate to VS Code and thank me. Run Terminal in the Editor and thank me again 😄

# Just tell me how you use it daily and I will decide whether to continue or not
- I have taught it to be my assistant using `copilot-instructions.md` and `skills`
- Update this opportunity
- Update this milestone
- Get me a list of activity for today
- Oh, and for each one of these things, commit them to instructions or add to skills
- Tell it to update tasks for customers
- Create a draft email for me
- I am planning a trip to see customers in **location**, tell me what is going on, give me some hotels by their offices and suggest dining locations for breakfast, lunch and dinner. And for after hours, good happy hour places
- Oh and for all of these, if not most, update my notes or create a separate markdown file 

# My Work Story
Key components that need to be there:
1. Email and Calendars
    - I move all my notes to a **folder** by customer
    - I **color categorize** my calendar events
1. Notes
    - Opportunities
        - Whether in CRM or not, what is hot and what is not
    - Meetings
        - Each meeting starts with `## YYYY-MM-DD: Title/Topic`
        - Follow Ups
    - I use emojis all over the place 🔥,⭐,🌤️,📅 and the good ole `TODO:`
1. Contacts
    - You would be amazed by what it can find
    - Find the C level and VP level at this company and add them to contacts
    - Sales Navigator integration would be amazing and hopefully coming soon
1. Schedule calls and follow up with customers
1. Add entries into our CRM tool and update comments and milestones
1. Research products and services
    - Work/Web is key here as some stuff is internal processing

# Tools and more Tools
- I have tried them all
- See [My Eveolution of Note Taking](#my-evolution-of-note-taking)
- Managing tasks in [Action Items, To Do, Takeaways](#action-items-to-do-takeaways)

## My Evolution of Note Taking
- OneNote
    - OG user
    - We used to use the infra thing or whatever on Laptops and do live meetings in like 2010 and it was awesome
        - Even the whole transcribe and play back and you could watch your notes draw out
    - Did this until 2025
    - However, now...
        - Corrupt files
        - Corrupt Search
        - Copilot support? Or not?
        - What about this vs Loop?
- Loop 
    - It is slow
    - Online only and search again...painful
    - Easy to share though so need to find happy medium
- GitHub
    - I have had my https://github.com/kirkhofer profile for awhile
    - Started adding my own repos to share knowledge and code
    - Markdown was simple and relatively easy to search
    - I started documenting stuff in MD and had inline code, etc.
    - Created personal repos for knowledge and worked on other teams to build out code bases 
- Markdown files in VS Code on OneDrive
    - Local files and fast
    - Saved to OneDrive so still have backup
    - Not sure about sensitivity labels
    - Obsidian is awesome editor but I don't feel I need it as much 🤔

## Action Items, To Do, Takeaways
- I have struggled with this...what "app" do I use to help me
- Outlook
    - Outlook tasks worked well...sort of
    - Could flag emails too
- To Do
    - Outlook tasks moved to To Do
    - I could use "hashtags" to easily find stuff
    - Flagged emails showed up
- Loop
    - Can assign stuff in here
    - Annoying nofications daily on stuff and hard to find them all
- Planner
    - Loved how it tracked status and comments
    - This got overhauled and because...yuck
- To Do
    - Copilot can't easily read my to do list 😄
    - What? Are you kidding me? Nope certain Admin permissions are not present
- Back to markdown


# Install
A great overview by the legend[Great overview by John Savil](https://www.youtube.com/watch?v=tQlNq8bH674)
- This has most of the steps and talks in detail about what everything does

You will want to start in a folder that has notes already or go from scratch and watch it work. I used **notes** in this install

## Terminal Steps
If you do not have Terminal installed, you need this. But it is there for Windows 11 and up by default

Make sure to exeucte these one at a time as you might not have proper access or get errors

```powershell copy
# Install the terminal
# NOTE: You probably have this installed already so just search for it first
winget install -e --id Microsoft.WindowsTerminal

# Install powershell this is not "Windows PowerShell"
winget install -e --id Microsoft.PowerShell

# Install node
winget install -e --id OpenJS.NodeJS

# Install GitHub CLI
winget install -e --id GitHub.Copilot
```

You have everything you need now but if you are in Terminal and see **Windows PowerShell** time to switch that:
- Open a new terminal tab with **PowerShell** or **Microsoft PowerShell**
- On that dropdown arrow, go in there and change the default to *not* be **Windows PowerShell** but the new one

```powershell copy
# Restart the PowerShell

# Go to OneDrive so anything you create is backed up
cd '.\OneDrive'

# Create a notes director or anything
mkdir notes; cd notes

# agency copilot
copilot

# Once you get familiar with copilot you can switch to copilot --yolo

# Login
/login

# Do option 1: 
# Copy the code by selecting it
# CTRL+CLICK into github.com

# Install from marketplace
/plugin marketplace add microsoft/work-iq

# Install workiq via plugin
/plugin install workiq@work-iq

# Accept the EULA (again in GitHub Copilot CLI)
workiq accept-eula

# Test it out
What are my upcoming meetings this week?
Summarize emails from Sarah about the budget
Find documents I worked on yesterday
```

You will notice a lot of annoying qustions about trust this or not but that is what `/yolo` is for to turn those off once you get the idea

## Create the instructions file
- You need a file to control how the CLI works for you
- Launch `/init` while in the CLI
- This might say there isn't any code or anything but just tell it you want it to help do work for customers
    - You need to be forceful here
    - You are not a developer
    - This is for customer and business notes
- It will create a file in `.github\copilot-instructions.md`. If it doesn't, tell it

## Tell it who you are and what you do
- Tell it your role and what you do and what you sell
- Tell it your customer names
- If you use tools where you need other IDs or something, tell it to remember those
- Everything you say will be put in the instructions
- Watch how it acts and thinks and modifies files, it is nuts

## Create Skills by Talking
- I used my programming background to create skills
- I use CRM and wanted to easily pull my opportunities and milestones and accounts
    - I pasted in URLs and it just figured out how to communicate with the OData REST APIs
- I use Power BI ~~datasets~~ semantic models
    - It figured out I might need an MCP server and there is an Artifact ID that was needed

## Sample: Folder Structure
 ```text
 📋 Root Notes (Like team notes, tech stuff, etc.)
 ├── .github/
 │   └── copilot-instructions.md   ← Copilot custom instructions
 |   └── skills/                   ← Copilot CLI skills
 |      ├── power-bi/     (SKILL.md + references/)
 |      ├── graph-helper/ (SKILL.md + scripts/)
 |      └── crm/          (SKILL.md + references/)
 ├── customer/             ← Per-account notes
 │   ├── customerA.md
 │   ├── customerB.md
 ```
- Some like to do a folder by customer and then let it generate things in the folders

# Future
- You can easily move your skills to your own plugin and share with others

# Credits
Too many to list off here and it continues to grow