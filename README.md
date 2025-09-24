# How to create a client

```luau
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AudioWrapper = require(Path.To.AudioWrapper)
local ClientAudio = AudioWrapper("Client", game.Players.LocalPlayer.Name)
```
