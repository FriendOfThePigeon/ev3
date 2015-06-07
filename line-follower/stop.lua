require 'ev3dev'
require 'os'

machine = {
}

function machine:start()
	for i, p in ipairs({"outA", "outB", "outC", "outD"}) do
		m = LargeMotor(p)
		if m:connected() then
			print("Stopping motor on " .. p)
			m:setCommand("stop")
		end
	end
end

machine:start()
