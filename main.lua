local hotupdate = require "hotupdate"
local test = require "test"

hotupdate.Init({"D:\\fantasy\\test\\src"}, print)
local run_times = 0
local last_time = os.clock()



while true do
  local now_time = os.clock()
  if now_time - last_time > 3 then
    last_time = now_time
    run_times = run_times + 1
    
    hotupdate.Run()
    test.func()
    
    if run_times >= 10 then
      break
    end
  end
end