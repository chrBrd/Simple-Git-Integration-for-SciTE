Simple Git Integration for SciTE
===

SciTE extension allowing simple Git version control on local files. Based on [debjan's](https://github.com/debjan) [SciTE Simple Version Control](https://github.com/debjan/scite-simple-version-control).

-- Supports Windows only.  
-- Currently completely untested with SciTE's sessions feature - might work, might not. Double checking is on the 'TODO' list; as I don't use SciTE very often it probably won't happen unless requested.

Requirements:
---
This script uses `spawner-ex.dll`, found in `scite-debug.zip` at the [scite-debug archive](http://files.luaforge.net/releases/scitedebug/scitedebug/0.9.1).  
-- Note: This library is used to prevent cmd windows from popping up every time `git.exe` is executed, although the extension will work without it if all instances of `spawner.popen()` in the script are replaced with `io.popen()`.

Installation
---
First, ensure your config settings are correct; these can be found in the `config` section at the top of the scipt.

|Property|Value|
|-------|-----|
|Git|Absolute path to  `git.exe`  (can be left as 'git.exe' if Git has System %PATH% entry).|
|spawner_path|Absolute path to `spawner-ex.dll`.|
|tortoise|Option to run through Tortoise GUI instead of using console commands.|
|TortoiseGit|Absolute path to `TortoiseGitProc.exe`  (Required if Tortoise GUI option is enabled. Can be left as 'TortoiseGitProc.exe' if Tortoise Git has System %PATH% entry (it does by default))|
|allow_destroy|Make destroy command available; **as SciTE doesn't seem to allow confirmation dialogues it's recommended this is kept off**.|
|command_number|Free SciTE command number slot; if you don't know what that means then you probably don't need to worry about it.|

From the toolbar select **Options > Open Lua Startup Script** and insert the following line into the file:

`dofile("C:\\<path-to>\\SciTE_GIT.lua")`

Once the file has been saved the extension should be working.

Use
---
Open/go to the tab of document you want to add to Git and press the right mouse button. You should see a 'Git' option at the bottom of the context menu:

![](http://i.imgur.com/9bYFhqt.png)

On selecting that the available commands window will open at the position of your caret:

![](http://i.imgur.com/TOHswrE.png)



If the `tortoise` option in the `config` section is set to `true`all commands with the exception of `Destroy` will be handled by the Tortoise GUI. Otherwise all commands will be executed using the Windows command line.

When using `git.exe` all messages are displayed in SciTE's Output window. Git commit messages are entered using SciTE's strip dialogue at the bottom of the SciTE window:

![](http://i.imgur.com/IzLqVqq.png)
