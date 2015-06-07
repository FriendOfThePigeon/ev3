require 'ev3dev'
require 'os'

machine = {
	corrections = {},
	directions = {},
	current_direction = nil,
	positions_at_start_of_spin = nil,
	last_blue_reading = nil
}

function machine:find_devices()
	print("machine:find_devices()")
	self.wheel_dia = 30
	self.wheel_spacing = 200
	self.rotations_for_complete_spin = self.wheel_spacing / self.wheel_dia
	self.left_motor = LargeMotor('outB')
	self.left_motor:setSpeedRegulationEnabled('on')
	self.right_motor = LargeMotor('outC')
	self.right_motor:setSpeedRegulationEnabled('on')
	self.beeper = Sound()
	self.csensor = ColorSensor()
	self.csensor:setMode("RGB-RAW")
end

function machine:csensor()
	print("machine:csensor()")
	self.csensor:setMode(ColorSensor.ModeColor)
	self.csensor:setMode(ColorSensor.ModeReflect)
	self.csensor:value()
	self.csensor:floatValue()
end

function machine:sleep(s)
	print("machine:sleep(s)")
	os.execute("sleep " .. s)
end

function machine:beep_start()
	print("machine:beep_start()")
	self.beeper.tone(300, 100)
	self.sleep(0.1)
	self.beeper.tone(400, 100)
	self.sleep(0.1)
end

function machine:start()
	print("machine:start()")
	self:find_devices()
	self:beep_start()
	self.current_direction = self:get_random_direction()
	return self:start_driving_forward()
end

function machine:stop_motor(motor)
	print("machine:stop_motor(motor)")
	motor:setStopCommand('coast')
	motor:setCommand('stop')
end

function machine:change_motor_speeds(left, right)
	print("machine:change_motor_speeds(left, right)")
	left_motor:setDutyCycleSP(left)
	right_motor:setDutyCycleSP(right)
	-- We could use run-forever but it seems more likely that we made a mistake in our code 
	-- than that we don't need any steering correction for >30s.
	for m in left_motor, right_motor do
		m:stop()
		m:setTimeSP(30000)
		m:command("run-timed")
	end
end

function machine:start_driving_forward() 
	print("machine:start_driving_forward() ")
	self:change_motor_speeds(100, 100)
	return self:blue_1()
end

function machine:get_colors() 
	print("machine:get_colors() ")
	result = {}
	result['r'] = self.csensor:value(0)
	result['g'] = self.csensor:value(1)
	result['b'] = self.csensor:value(2)
	return result
end

function machine:get_blue_percent()
	print("machine:get_blue_percent()")
	rgb = self:get_colors()
	result = 0
	if (rgb['b'] ~= 0) and (rgb['g'] / rgb['b'] < 0.95) and (rgb['r'] / rgb['b'] < 0.75) then
		result = 100 * rgb['b'] / 75
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
	l = left_motor:position()
	rotations = math.abs(l - self.positions_at_start_of_spin['l']) / 360
	if rotations < self.rotations_for_complete_spin then
		return self:blue_2()
	end
	for i = 250, 150, -10 do
		self.beeper.tone(i, 100)
		self.sleep(0.1)
	end
	return nil -- end program
end

machine:start()
