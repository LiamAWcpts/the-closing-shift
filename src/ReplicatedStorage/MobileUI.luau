--shared helpers so every screen can tell a phone from a desktop and lay itself out for it
local UIS = game:GetService("UserInputService")

local M = {}


--a touch screen with no keyboard, or a finger was the last thing used
--ForceMobileUI on workspace lets a desktop test the phone layouts
function M.isTouch()
    if workspace:GetAttribute("ForceMobileUI") then return true end
    if not UIS.TouchEnabled then return false end
    if not UIS.KeyboardEnabled then return true end
    return UIS:GetLastInputType() == Enum.UserInputType.Touch
end



--phones in landscape are only about 360 to 430 tall, they get the compact layouts
function M.isCompact()
    local vp = workspace.CurrentCamera.ViewportSize
    if vp.Y < 620 or vp.X < 900 then return true end
    return M.isTouch() and vp.Y < 800
end


--phones skip the heavy extras, shadows on small lights, live viewports and thick particles
function M.isLowSpec()
    return M.isTouch()
end


--keyboard hint text on a computer, nothing on a phone where the buttons speak for themselves
function M.key(text)
    if M.isTouch() then return "" end
    return text
end


--a screen gui that keeps everything inside the safe part of the screen, clear of notches and the roblox buttons
function M.safeGui(name, order, parent)
    local g = Instance.new("ScreenGui")
    g.Name = name
    g.ResetOnSpawn = false
    g.DisplayOrder = order
    g.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
    g.Parent = parent
    return g
end


--runs fn now and again whenever the screen size or the kind of input changes
function M.watch(fn)
    local cam = workspace.CurrentCamera
    local lastTouch = M.isTouch()
    local lastSize = cam.ViewportSize
    fn()
    local function check()
        local t = M.isTouch()
        local s = workspace.CurrentCamera.ViewportSize
        if t ~= lastTouch or s ~= lastSize then
            lastTouch = t
            lastSize = s
            fn()
        end
    end
    cam:GetPropertyChangedSignal("ViewportSize"):Connect(check)
    UIS.LastInputTypeChanged:Connect(check)
    workspace:GetAttributeChangedSignal("ForceMobileUI"):Connect(check)
end

return M
