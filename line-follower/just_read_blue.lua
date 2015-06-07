require 'ev3dev'
require 'os'

machine = {
	corrections = {},
	directions = {},
	current_direction = nil,
	positions_at_start_of_spin = nil,
	last_blue_reading = nil,
	debug = false
}

function machine:find_devices()
	print("machine:find_devices()")
	self.wheel_dia = 30
	self.wheel_spacing = 200
	self.rotations_for_complete_spin = self.wheel_spacing / self.wheel_dia
	self.left_motor = LargeMotor('outB')
	self.left_motor:setSpeedRegulationEnabled('off')
	self.right_motor = LargeMotor('outC')
	self.right_motor:setSpeedRegulationEnabled('off')
	self.beeper = Sound()
	self.csensor = ColorSensor()
	self.csensor:setMode("RGB-RAW")
end

function machine:sleep(seconds)
	print("machine:sleep(seconds)")
	os.execute("sleep " .. seconds)
end

function machine:get_colors() 
	print("machine:get_colors() ")
	result = {}
	result['r'] = self.csensor:value(0)
	result['g'] = self.csensor:value(1)
	result['b'] = self.csensor:value(2)
	return result
end

function machine:print_colors()
	rgb = self:get_colors()
	out = "[" .. rgb['r'] .. ", " .. rgb['g'] .. ", " .. rgb['b'] .. "]"
	if rgb['b'] > 0 then
		out = out .. " => [" .. rgb['r']/rgb['b'] .. ", " .. rgb['g'] / rgb['b'] .. "]"
	end
	out = out .. " => " .. 100 * rgb['b'] / 65
	print(out)
end

function machine:get_blue_percent()
	if self.debug then
		print("machine:get_blue_percent()")
	end
	rgb = self:get_colors()
	result = 0
	-- Typical strong blue is approx. [r, g, b] = [15, 45, 65]
	-- But blue can read [50, 140, 145]
	if (rgb['b'] ~= 0) and (rgb['g'] / rgb['b'] < 0.98) and (rgb['r'] / rgb['b'] < 0.60) then
		result = 100 * rgb['b'] / 65
		if result > 100 then
			result = 100
		end
	end
	self.last_blue_reading = self.this_blue_reading
	self.this_blue_reading = result
	return result
end

function machine:sleep_a_little()
	print("machine:sleep_a_little()")
	self:sleep(0.1)
end

function machine:beep(pitch, duration)
	print("machine:beep(pitch, duration)")
	self.beeper.tone(pitch, duration)
	self:sleep(duration * 0.001)
end

function machine:start()
	print("machine:start()")
	self:find_devices()
	for i = 0, 120 do
		self:print_colors()
		print("=> " .. self:get_blue_percent())
		self:sleep(0.5)
	end
end

machine:start()
