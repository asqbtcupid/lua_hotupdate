local test = {}
local times = 0

local function upvalue_func()
  print("upvalue func")
end

function test.func()
  times = times + 1
  print("func", times)
  upvalue_func()
end

return test