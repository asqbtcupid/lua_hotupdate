local HU = require "luahotupdate"
HU.Init("hotupdatelist", {"D:\\ldt\\workspace\\hotimplement\\src"}) --please replace the second parameter with you src path

function sleep(t)
  local now_time = os.clock()
  while true do
    if os.clock() - now_time > t then
      HU.Update() 
      return 
    end
  end
end











--[[***************************************
*******************************************]]
local test = require "test"
print("start runing")
while true do
  test.func()
  sleep(3)
end
--***************************************
--***************************************



