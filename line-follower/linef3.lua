require 'ev3dev'
require 'os'

machine = {
	corrections = {},
	directions = {},
	current_direction = nil,
	positions_at_start_of_spin = nil,
	last_blue_reading = nil,
	debug_enabled = false,
	notes_hmm = { { 200, 100 } },
	notes_uh_oh = { { 180, 100 }, { 160, 200 } }
	notes_lost = { { 160, 300 } },
	notes_happy = { { 350, 100 }, { 350, 100 } },
	notes_fanfare = { { 300, 100 }, { 400, 50 }, { 300, 100 }, { 400, 400 } }
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
	if s >= 1 then
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
	self:play(self.notes_fanfare)
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
	self:change_motor_speeds(60, 60)
	return self:blue_1()
end

function machine:sleep_a_little()
	print("machine:sleep_a_little()")
	self:sleep(0.1)
end

function machine:blue_1() 
	-- We are driving forward - checking that the blue reading doesn't drop.
	print("machine:blue_1() ")
	b = self:get_blue_percent()
	if b == 0 then
		return self:beep_uh_oh()
	end
	if b < 75 then
		return self:beep_hmm()
	end
	--self:sleep_a_little()
	return self:blue_1()
end

function machine:get_directions()
	print("machine:get_directions()")
	if #self.corrections == 0 then
		direction1 = self:randomly_chosen_direction()
		print("randomly chose " .. direction1)
	elseif #self.corrections == 1 then
		direction1 = self.corrections[1]
		print("only one prev correction - choosing same (" .. direction1 .. ")")
	elseif self.corrections[1] == self.corrections[2] then
		direction1 = self.corrections[1]
		print("last two corrections matched - choosing same (" .. direction1 .. ")")
	else 
		--direction1 = self.corrections[2]
		--print("last two corrections didn't match - choosing other (" .. direction1 .. ")")
		direction1 = self.corrections[1]
		print("last two corrections didn't match - choosing last one (" .. direction1 .. ")")
	end
	direction1 = direction1 / math.abs(direction1)
	result = {
		direction1 * 30,
		direction1 * -60,
		direction1 * 120,
		direction1 * -180
	}
	return result
end

function machine:play(notes)
	for ignore, note in ipairs(notes) do
		self.beeper.tone(note[1], note[2])
		self:sleep(0.1)
	done
end

function machine:beep_hmm()
	print("machine:machine:beep_hmm()")
	self:stop_motors()
	return self:start_turning(self.notes_hmm)
end

function machine:beep_uh_oh()
	print("machine:beep_uh_oh()")
	return self:start_turning(self.notes_uh_oh)
end

function machine:start_turning(notes)
	print("machine:start_turning()")
	self.positions_at_start_of_spin = {
		l = self.left_motor:position(),
		r = self.right_motor:position()
	}
	self:stop_motors()
	self:play(notes)
	self.directions = self:get_directions()
	return self:spin_to_next_mark()
end

function machine:spin_to_next_mark()
	print("machine:spin_to_next_mark()")
	if #self.directions == 0 then
		return self:lost_abort() -- end program
	end
	self.current_direction = table.remove(self.directions, 1)
	print("current_direction now " .. self.current_direction)
	if self.current_direction < 0 then
		self:change_motor_speeds(50, -50)
	else
		self:change_motor_speeds(-50, 50)
	end
	return self:blue_2()
end

function machine:blue_2()
	-- We have lost the line and are spinning, looking for blue.
	b = self:get_blue_percent()
	if b > 0 then
		return self:back_on_track()
	end
	spin = self:get_spin_since_mark()
	print("machine:blue_2() [" .. spin .. "]")
	if (self.current_direction > 0 and spin < self.current_direction)
		or (self.current_direction < 0 and spin > self.current_direction) then
		return self:blue_2() -- Not reached mark - keep spinning
	end
	return self:spin_to_next_mark()
end

function machine:get_spin_since_mark()
	l = self.left_motor:position()
	degree_rotations = math.abs(l - self.positions_at_start_of_spin['l'])
	return degree_rotations / self.rotations_for_complete_spin
end

function machine:debug(msg)
	if self.debug_enabled then
		print(msg)
	end
end

function machine:back_on_track()
	print("machine:back_on_track()")
	self:stop_motors()
	self:play(self.notes_happy)
	if #self.corrections >= 2 then
		table.remove(self.corrections)
	end
	table.insert(self.corrections, 1, self.current_direction)
	return self:start_driving_forward()
end

function machine:lost_abort()
	print("machine:lost_abort()")
	self:stop_motors()
	self:play(self.notes_lost)
end

machine:start()
