local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local WrapperCache = require(script.Parent.Cache.WrapperCache)
local SoundsList = require(script.Parent.Dictionaries.Sounds)

local ClientSignal_PlaySound -- put your remote event here
local AudioWrapper = {}
AudioWrapper.__index = AudioWrapper

return function(mode, clientName)
	local wrapper = setmetatable({}, AudioWrapper)
	wrapper.Mode = mode
	wrapper.Sounds = {}
	wrapper.Debug = true -- Enable debug prints
	wrapper.OnSoundEnded = {}

	-- CLIENT: listen for server signals
	if mode == "Client" then
		local cacheID = HttpService:GenerateGUID(false)
		WrapperCache.CachedClients[clientName] = { cacheID = cacheID }

		ClientSignal_PlaySound.OnClientEvent:Connect(function(action, soundPath, properties)
			if action == "Play" then
				if wrapper.Debug then
					print("[AudioWrapper][Client] PlaySignal:", soundPath)
				end
				wrapper:_playSound(soundPath, properties)
			elseif action == "Stop" then
				if wrapper.Debug then
					print("[AudioWrapper][Client] StopSignal:", soundPath)
				end
				wrapper:_stopSound(soundPath)
			end
		end)

		-- Cleanup on client leave
		Players.PlayerRemoving:Connect(function(player)
			if player.Name == clientName then
				for path in pairs(wrapper.Sounds) do
					wrapper:UnloadSound(path)
				end

				WrapperCache.CachedClients[clientName] = nil

				if wrapper.Debug then
					print("[AudioWrapper][Client] Cleaned up cache + sounds for:", clientName)
				end
			end
		end)
	end

	-- Load a sound (memory-safe)
	function wrapper:LoadSound(path)
		if self.Sounds[path] then
			if self.Debug then
				print("[AudioWrapper] Sound already loaded:", path)
			end
			return
		end

		local soundObj = SoundsList[path]
		if not soundObj then
			warn("[AudioWrapper] Sound path not found:", path)
			return
		end

		local clone = soundObj:Clone()
		clone.Parent = SoundService

		clone.Ended:Connect(function()
			if wrapper.Debug then
				print("[AudioWrapper] Sound ended:", path)
			end

			wrapper:UnloadSound(path)
			local callback = wrapper.OnSoundEnded[path]
			if callback then
				pcall(callback)
			end
		end)

		self.Sounds[path] = clone
		if self.Debug then
			print("[AudioWrapper] Sound loaded:", path)
		end
	end

	-- Unload a sound (cleanup)
	function wrapper:UnloadSound(path)
		local sound = self.Sounds[path]
		if sound then
			sound:Stop()
			sound:Destroy()
			self.Sounds[path] = nil
			self.OnSoundEnded[path] = nil
			if self.Debug then
				print("[AudioWrapper] Sound unloaded:", path)
			end
		end
	end

	-- Internal play
	function wrapper:_playSound(path, properties)
		if not self.Sounds[path] then
			self:LoadSound(path)
			if not self.Sounds[path] then
				return
			end
		end

		local sound = self.Sounds[path]
		if properties then
			for k, v in pairs(properties) do
				sound[k] = v
			end
		end
		sound:Play()

		if self.Debug then
			print("[AudioWrapper] Playing sound:", path)
		end
	end

	-- Internal stop
	function wrapper:_stopSound(path)
		local sound = self.Sounds[path]
		if sound and sound.IsPlaying then
			sound:Stop()
			if self.Debug then
				print("[AudioWrapper] Sound stopped:", path)
			end
		end
	end

	-- Pause a sound
	function wrapper:PauseSound(path)
		local sound = self.Sounds[path]
		if sound and sound.IsPlaying then
			sound:Pause()
			if self.Debug then
				print("[AudioWrapper] Sound paused:", path)
			end
		end
	end

	-- Resume a sound
	function wrapper:ResumeSound(path)
		local sound = self.Sounds[path]
		if sound and not sound.IsPlaying then
			sound:Play()
			if self.Debug then
				print("[AudioWrapper] Sound resumed:", path)
			end
		end
	end

	-- Set a custom parent for a sound
	function wrapper:SetParent(path, parent)
		local sound = self.Sounds[path]
		if not sound then
			if self.Debug then
				warn("[AudioWrapper] Tried to set parent for unloaded sound:", path)
			end
			return
		end

		if typeof(parent) ~= "Instance" then
			error("[AudioWrapper] Parent must be a Roblox Instance")
		end

		sound.Parent = parent

		if self.Debug then
			print(string.format("[AudioWrapper] Sound '%s' parented to %s", path, parent:GetFullName()))
		end
	end

	-- SERVER: Play sound for a player
	function wrapper:PlaySound(player, path, properties)
		if self.Mode ~= "Server" then
			error("PlaySound can only be called on Server")
		end
		if player and player:IsDescendantOf(game) then
			ClientSignal_PlaySound:FireClient(player, "Play", path, properties)
			if self.Debug then
				print("[AudioWrapper][Server] PlaySound sent to:", player.Name, path)
			end
		end
	end

	-- SERVER: Stop sound for a player
	function wrapper:StopSound(player, path)
		if self.Mode ~= "Server" then
			error("StopSound can only be called on Server")
		end
		if player and player:IsDescendantOf(game) then
			ClientSignal_PlaySound:FireClient(player, "Stop", path)
			if self.Debug then
				print("[AudioWrapper][Server] StopSound sent to:", player.Name, path)
			end
		end
	end

	return wrapper
end
