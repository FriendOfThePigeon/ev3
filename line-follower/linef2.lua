require 'ev3dev'
require 'os'

machine = {
	corrections = {},
	directions = {},
	current_direction = nil,
	positions_at_start_of_spin = nil,
	last_blue_reading = nil
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

function machine:sleep(s)
	if seconds >= 1 then
		self:debug("machine:sleep(s)")
	end
	os.execute("sleep " .. s)
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
	self.current_direction = self:randomly_chosen_direction()
	return self:start_driving_forward()
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

function machine:start_driving_forward() 
	print("machine:start_driving_forward() ")
	self:change_motor_speeds(100, 100)
	return self:blue_1()
end

function machine:sleep_a_little()
	print("machine:sleep_a_little()")
	self:sleep(0.1)
end

function machine:blue_1() 
	print("machine:blue_1() ")
	b = self:get_blue_percent()
	if b == 0 then
		return self:beep_uh_oh()
	end
	if b < 75 then
		return self:beep_hmm()
	end
	self:sleep_a_little()
	return self:blue_1()
end

function machine:get_directions()
	print("machine:get_directions()")
	if #self.corrections == 0 then
		direction1 = self:randomly_chosen_direction()
	elseif #self.corrections == 1 then
		direction1 = self.corrections[1]
	elseif self.corrections[1] == self.corrections[2] then
		direction1 = self.corrections[2]
	else 
		direction1 = self.corrections[1]
	end
	direction2 = self:other_direction(direction1)
	return [ direction1, direction2 ]
end

function machine:machine:beep_hmm()
	print("machine:machine:beep_hmm()")
	self.beeper.tone(200, 100)
	self.sleep(0.1)
	self.beeper.tone(180, 200)
	self.sleep(0.2)
	self.directions = get_directions()
	return self:start_turning()
end

function machine:start_turning()
	print("machine:start_turning()")
	if #self.directions == 0 then
		return self:beep_uh_oh()
	end
	self.current_direction = table.remove(self.directions)
	if self.current_direction < 0 then
		self:change_motor_speeds(80, 100)
	else
		self:change_motor_speeds(100, 80)
	end
	return self:blue_lower()
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

function machine:blue_lower()
	print("machine:blue_lower()")
	b = self:get_blue_percent()
	if b == 0 then
		return self:start_turning() -- Try the other direction
	end
	if b < self.last_blue_reading then
		return self:start_turning()
	end
	if b > 75 then
		return self:beep_happy()
	end
	-- Turn harder
	l = self.left_motor:dutyCycle()
	r = serf.right_motor:dutyCycle()
	if l + r > 0 then
		if l < r then
			l = l - 20
			r = r - 10
		else
			r = r - 20
			l = l - 10
		end
		self:change_motor_speeds(l, r)
	end
	return self:blue_lower()
end

function machine:beep_happy()
	print("machine:beep_happy()")
	self.beeper.tone(350, 100)
	self.sleep(0.1)
	self.beeper.tone(350, 100)
	self.sleep(0.1)
	if #self.corrections >= 2 then
		table.remove(self.corrections)
	end
	table.insert(self.corrections, self.current_direction)
	return self:start_driving_forward()
end

function machine:beep_uh_oh()
	print("machine:beep_uh_oh()")
	self.positions_at_start_of_spin = {
		'l' = left_motor:position()
		'r' = right_motor:position()
	}
	-- Start turning on the spot
	if current_direction < 0 then
		self.change_motor_speeds(-50, 50)
	else
		self.change_motor_speeds(-50, 50)
	end
	return self:blue_2()
end

function machine:blue_2()
	print("machine:blue_2()")
	b = self:get_blue_percent()
	if b > 0 then
		return self:beep_happy()
	end
	if self:get_spin_since_mark() < 1.0 then
		return self:blue_2()
	end
	for i = 250, 150, -10 do
		self.beeper.tone(i, 100)
		self.sleep(0.1)
	end
	return nil -- end program
end

machine:start()
