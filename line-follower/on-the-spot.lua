require 'ev3dev'
require 'os'

machine = {
	corrections = {},
	directions = {},
	current_direction = nil,
	positions_at_start_of_spin = nil,
	last_blue_reading = nil,
	debug_enabled = false
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
	if seconds >= 1 then
		self:debug("machine:sleep(seconds)")
	end
	os.execute("sleep " .. seconds)
end

function machine:get_colors() 
	self:debug("machine:get_colors()")
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
	self:debug("machine:get_blue_percent()")
	rgb = self:get_colors()
	result = 0
	-- Typical strong blue is approx. [r, g, b] = [15, 45, 65]
	-- But blue can read [50, 140, 145]
	if (rgb['b'] ~= 0) and (rgb['g'] / rgb['b'] < 1.1) and (rgb['r'] / rgb['b'] < 0.60) then
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

function machine:change_motor_speeds(left, right)
	print("machine:change_motor_speeds(" .. left .. ", " .. right .. ")")
	self.left_motor:setDutyCycleSP(left)
	self.right_motor:setDutyCycleSP(right)
	-- We could use run-forever but it seems more likely that we made a mistake in our code 
	-- than that we don't need any steering correction for >30s.
	for i, m in ipairs({self.left_motor, self.right_motor}) do
		m:setCommand("stop")
		m:setTimeSP(30000)
		m:setCommand("run-timed")
	end
end

function machine:stop_motors()
	for i, m in ipairs({self.left_motor, self.right_motor}) do
		m:setCommand("stop")
	end
end

function machine:beep_fanfare()
	print("machine:beep_fanfare()")
	self:beep(300, 100)
	self:beep(400, 50)
	self:sleep(0.05)
	self:beep(300, 100)
	self:beep(400, 400)
end

function machine:beep_here_we_go()
	print("machine:beep_here_we_go()")
	self:beep(300, 25)
	self:beep(300, 25)
	self:beep(300, 25)
end

function machine:start()
	print("machine:start()")
	self:find_devices()
	self:beep_fanfare()
	return self:choose_random_direction()
end

function machine:randomly_chosen_direction() 
	print("machine:randomly_chosen_direction() ")
	if math.random() < 0.5 then
		return -1
	else
		return 1
	end
end

function machine:other_direction(direction)
	print("machine:other_direction(direction)")
	return 0 - direction
end

function machine:choose_random_direction()
	print("machine:choose_random_direction()")
	self.current_direction = self:randomly_chosen_direction()
	return self:start_spinning()
end

function machine:start_spinning()
	print("machine:start_spinning()")
	self.positions_at_start_of_spin = {
		l = self.left_motor:position(),
		r = self.right_motor:position()
	}
	-- Start turning on the spot
	if self.current_direction < 0 then
		self:change_motor_speeds(-50, 50)
	else
		self:change_motor_speeds(50, -50)
	end
	return self:no_blue()
end

function machine:get_spin_since_mark()
	l = self.left_motor:position()
	rotations = math.abs(l - self.positions_at_start_of_spin['l']) / 360
	return rotations / self.rotations_for_complete_spin
end

function machine:debug(msg)
	if self.debug_enabled then
		print(msg)
	end
end

function machine:blue_2()
	self:debug("machine:blue_2()")
	b = self:get_blue_percent()
	if b > 0 then
		return self:beep_happy()
	end
	rotation = self:get_spin_since_mark()
	if rotation < 1.0 then
		return self:blue_2()
	end
	return beep_sad()
end

function machine:no_blue()
	self:debug("machine:no_blue()")
	b = self:get_blue_percent()
	if b == 0 then
		self:beep_here_we_go()
		return self:blue_2()
	end
	rotation = self:get_spin_since_mark()
	if rotation < 1.0 then
		return self:no_blue()
	end
	return beep_sad()
end

function machine:beep_happy()
	print("machine:beep_happy()")
	self:print_colors()
	self:stop_motors()
	print("Estimated rotation: " .. self:get_spin_since_mark())
	self:beep(400, 50)
	self:sleep(0.05)
	self:beep(400, 50)
	self:sleep(2)
	return self:choose_random_direction()
end

function machine:beep_sad()
	print("machine:beep_sad()")
	for i = 200, 100, -10 do
		self:beep(i, 0.1)
	end
	self:stop_motors()
	for i = 250, 150, -10 do
		self.beeper.tone(i, 100)
		self:sleep(0.1)
	end
	return nil -- end program
end

machine:start()
