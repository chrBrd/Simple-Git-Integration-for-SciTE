--[[
	** Config Settings **
	gitPath: 	Absolute path to  'git.exe'  (can be left as 'git.exe' if Git has System %PATH% entry).
	spawnerPath:	Absolute path to 'spawner-ex.dll'.
	tortoise:	 Option to run through Tortoise GUI instead of using console commands.
	TortoiseGit:	Absolute path to 'TortoiseGitProc.exe'  (can be left as 'TortoiseGitProc.exe' if Tortoise Git has System %PATH% entry (it does by default)); required if Tortoise GUI option is enabled.
	allowDestroy:	Make destroy command available; as SciTE doesn't seem to allow confirmation dialogues it's recommended this is kept off.
	commandNumber:	Free SciTE command number slot.	
--]]	
	
git = {
	
	-- Configuration data for use in the script.
	config = {   
		gitPath = "C:/Program Files/Git/cmd/git.exe",
		spawnerPath = "C:/Program Files (x86)/SciTE/extensions/spawner-ex.dll",
		tortoise = false,
		TortoiseGit = "TortoiseGitProc.exe",
		allowDestroy = true,
		commandNumber = 30,
	},	

	-- Group of functions used by the init() method.
	initFuncs = {
	
		--Initialise the extension.
		init = function(self)
			self:setVariables()
			if not self.getSpawner() then return end
			ctrl.gitExists =  ctrl.gitExists or self:checkGitExists(config['gitPath']) 
			if not ctrl.gitExists then return end
			self.checkWinVer()
			self.addToContext()
		end,	
	
			-- Set variables to be used throughout the script.
			setVariables = function(self)
				scite_git = git.onContextSelect
				config = git.config
				session ={['control']={}, ['status']={}, ['stamp']={}}
				ctrl = session.control			
				cmds = self.setCommands()
			end,
			
				-- Set up the strings used for Git commands.
				setCommands = function()
					if not config.tortoise then
						cmds = {
							Log    = 'log --graph',
							Diff   = 'diff',
							Add    = 'add',
							Commit = 'commit',
							Revert = 'checkout',
							Remove = 'rm --cached',
							Status = 'status -u'
						}
					else cmds =  {	
						Log    = '/command:log /path:',
						Diff   = '/command:diff /path:',
						Add    = '/command:add /path:',
						Commit = '/command:commit /path:',
						Revert = '/command:revert /path:',
						Remove ='/command:remove /path:',
						Status = '/command:repostatus /path:'
					}
					end
					cmds.Root   = 'rev-parse --show-toplevel'
					cmds.PorcStatus   = 'status --porcelain -u'
					return cmds
				end,		
		
			--Load the spawner.
			-- TODO: Possibly add user choice to continue using io.popen() if spawner not found.
			getSpawner = function()		
				local fn, err
				fn, err = package.loadlib(config.spawnerPath, 'luaopen_spawner')		
				if fn then fn() return true
				else print('ERROR: spawner-ex.dll could not be found! Please check the path in the config section.') return false 
				end
			end,
			
			-- Check the Git executable exists.
			checkGitExists = function(self, gitPath)
				if self.checkDir(gitPath) then return true
				elseif self.checkPath(gitPath) then return true
				else print('ERROR: Git executable not found! Please check the path in the config section.') return false end
			end,
			
				-- Check for git.exe in the gitPath directory set in config.
				checkDir = function(gitPath)
					return spawner.popen(('if exist %q (echo true) else (echo false)'):format(gitPath)):read('*a'):gsub('\n', '') == 'true'
				end,
				
				-- Check for git.exe in Window's %PATH% variable.
				checkPath = function(gitPath)
					return spawner.popen('for %f in (' .. gitPath .. ') do @if "%~$PATH:f"=="" (echo false) else (echo true)'):read('*a'):gsub('\n', '') 
				end,
			
			-- Checks Windows version. 
			checkWinVer = function()
				if not session['ver'] and spawner then
					local verString = spawner.popen('ver'):read('*a'):gsub('\n', '')
					local verNum = (string.find(verString, 'Version'))+8
					local verNumEnd = verNum + string.find(verString:sub(verNum), '%.')
					session['ver'] = tonumber(verString:sub(verNum, verNumEnd))
				end
			end,
			
			-- Add Git option to SciTE's right-click context menu.
			addToContext = function()
				cmdNum = config.commandNumber
				context = props['user.context.menu']
				gitContext = ('||%s|11%s|'):format('Git', cmdNum)
				if not context:find(gitContext) then
					props['user.context.menu'] = context..gitContext
					props['command.' .. cmdNum .. '.*'] = 'scite_git'
					props['command.mode.' .. cmdNum .. '.*'] = 'subsystem:lua'
				end
			end,		
	},
	
	-- Group of functions used to create the User List context menu.
	listFuncs = {	

		-- Executes when 'Git' option is selected on the context menu.
		listSelect = function(self)
			if ctrl[props['FilePath']] then
				self:createList(ctrl[props['FilePath']])
			elseif commandFuncs.gitStatus(true):sub(1,1) ~= 'f' then
				ctrl[props['FilePath']] = "Git"; self:createList()
			else
				OnUserListSelection = function(num, cmd) return commandFuncs:initRepo(cmd) end
				editor:UserListShow(3, "Init")
			end		
		end,		
	
		-- Create the list
		createList = function(self)
			sessionFuncs:SetModifiedStamp()
			sessionFuncs.setSessionStatus()		
			local allowedCmds = self.getAllowedCmds()
			local cmdList = self.filterCommands(allowedCmds)
			self.displayList(cmdList)
		end,		
		
		-- Return allowed commands based on the results of the status query.
		getAllowedCmds = function()
			local cmds
			local code = session.status[props['FilePath']]
			if code == '?' then cmds = {1}; if config.allowDestroy then cmds[#cmds+1] = 8 end
			elseif code == 'M' then cmds = {2,3,4,5,7}
			elseif code == 'C' or code == " " then cmds = {4,6,7}; if config.allowDestroy then cmds[#cmds+1] = 8 end
			elseif code == 'A' then cmds = {2,3,4,5,7}
			elseif code == 'R' or code == 'D' then cmds = {2,4,5,7}
			else cmds = {7} 
			end
			return cmds			
		end,		
		
		-- Match the numbers in the allowed commands table with the commands to be listed.
		filterCommands = function(allowedCmds)
			local displayList = ''
			local cmds = {'Add', 'Commit', 'Diff', 'Log', 'Revert', 'Remove', 'Status', 'Destroy'}
			for i, v in ipairs(allowedCmds) do displayList = displayList .. ' ' .. cmds[v] end
			return displayList:sub(2)
		end,
		
		-- Send the list actions to SciTe for display on the context menu.
		displayList = function(cmdList)			
		-- TODO Check token function and what condition triggers it.
			if scite_UserListShow then scite_UserListShow(self.token(cmdList), 1, commandFuncs.executeCmd)			
			else 
				OnUserListSelection = function(listNumber, selectedCmd)
				return commandFuncs:executeCmd(selectedCmd) end
				editor:UserListShow(6, cmdList)
			end		
		end,
		
		-- TODO: Not sure what function this serves yet...
		token = function(cmdList)
		print('TOKEN ACTIVATED')
			local l = {}
			for v in string.gmatch(cmdList, "%S+") do l[#l+1] = v end
			return l
		end,
	},
	
	-- Group of functions for Git commands.
	commandFuncs = {
	
		-- Check Git's status.
		gitStatus = function(porcelain)
		if porcelain == true then status = cmds['PorcStatus'] else status = cmds['Status'] end
		-- TODO: Is that C at the end needed?
			return spawner.popen(('cd /D %q & %q %s %q'):format(props['FileDir'], config.gitPath, status, props['FileNameExt'])):read('*a') .. 'C'
		end,
		
		-- Initialise a new repo.
		initRepo = function(self, cmd)
			ctrl[props['FilePath']] = cmd:gsub("Init", "")

			print(spawner.popen(("cd /D %q & %q init && %q add %q && %q commit -m init"):format(props['FileDir'], config.gitPath, config.gitPath, props['FilePath'], config.gitPath)):read("*a"))
			commandFuncs:executeCmd('Status')
			sessionFuncs.setSessionStatus()
		end,

		-- Execute git command chosen from context menu.
		executeCmd = function(self, cmd)
			if cmd =="Destroy" then
				-- TODO Maybe add a confirmation dialogue. Appears the only way to do this through the API is by having users type a confirmation string into the strip dialogue box.
				self.destroy()
			else
				if config.tortoise then
					self.tortoise(cmd)				
				else
					scite.MenuCommand(IDM_CLEAROUTPUT)
					if cmd == "Commit" then self:dialog(cmd)
					else print(spawner.popen(("cd /D %q & %q %s %q"):format(props['FileDir'], config.gitPath, cmds[cmd], props['FileNameExt'])):read("*a")) 
					end
				end
			end
		end,
		
		-- Destroy a Git repo.
		destroy = function()
			local projectRoot = spawner.popen(('cd /D %q & %q %s'):format(props['FileDir'], config.gitPath, cmds['Root'])):read('*a'):gsub('\n', '') .. '/.' ..  ctrl[props['FilePath']]:lower()			
			spawner.popen(('if exist %q rd /s /q %q'):format(projectRoot, projectRoot))
			print('Repo destroyed')
		end,

		-- Take care of tortoise stuff
		tortoise = function(cmd)	
			spawner.popen(("cd /D %q & %q %s%q"):format(props['FileDir'], config["TortoiseGit"], cmds[cmd], props['FileNameExt']))
		end,
		
		-- Enables the dialogue strip to input the commit message.
		dialog = function(self, cmd)
			scite.StripShow("!'" .. cmd .. "'[]((OK))(Cancel)")
			function OnStrip(control, change)
				if change == 1 and control == 2 then
					local msg = scite.StripValue(1)
					if msg:len() > 0 then
						print(spawner.popen(("cd /D %q & %q %s %q -m %q && echo %s"):format(props['FileDir'], config.gitPath, cmds[cmd], props['FileNameExt'], msg, msg)):read("*a"))
						sessionFuncs.setSessionStatus()
					end
					scite.StripShow("")
				end
			end
		end		
	},
	
	-- Group of session functions.
	sessionFuncs = {		
		
		-- Set a timestamp of the files' modification dates and times into the session.
		SetModifiedStamp = function(self)	
			if props['FileDir'] ~= '' then	
				if session['ver'] > 5 then
					local dateTime = spawner.popen('forfiles /p "'..props['FileDir']..'" /m '..props['FileNameExt']..' /c "cmd /c echo @fdate @ftime"'):read('*a'):gsub('\n', '')
					if session.stamp[props['FilePath']] ~= dateTime then
						session.stamp[props['FilePath']] = dateTime
					end
					self.setSessionStatus()					
				else self.setSessionStatus() end
			end
		end,
		
		-- Set the current Git status in the session.
		setSessionStatus = function()
			session.status[props['FilePath']] = (commandFuncs.gitStatus(true):gsub(' ','')):sub(1,1)			
			if session.status[props['FilePath']]:gsub("f", "a") == "a" then session.status[props['FilePath']], ctrl[props['FilePath']] = nil end
		end
	},	

	-- Set up function groups from each table of functions.
	setFuncs = function()
		initFuncs = setmetatable(git.initFuncs, git.initFuncs)
		listFuncs = setmetatable(git.listFuncs, git.listFuncs)
		sessionFuncs = setmetatable(git.sessionFuncs, git.sessionFuncs)
		commandFuncs = setmetatable(git.commandFuncs, git.commandFuncs)
	end,
	
	-- Sequence the master functions.
	sequence = function()
		git.setFuncs()
		initFuncs:init()	
	end,

	-- Initialise the context menu list on selection.
	onContextSelect = function()
		listFuncs:listSelect()
	end
}

git.sequence()
