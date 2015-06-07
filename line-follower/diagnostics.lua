require 'ev3dev'
require 'os'

machine = {
}

function sleep(sec) 
  os.execute("sleep " .. tonumber(sec))
end

function machine:find_motor(port)
	result = LargeMotor(port)
	if (result:connected()) then
		result:setStopCommand('coast')
		result:setDutyCycleSP(75)
		print("Found a LargeMotor at " .. result:portName())
		print("Duty cycle: " .. result:dutyCycle())
		print("Count per rot: " .. result:countPerRot())
		print("Current position: " .. result:position())
		print("Supported commands: " .. result:commands())
	end
	return result
end

function machine:find_devices()
	self.left_motor = self:find_motor("outB")
	self.right_motor = self:find_motor("outC")
	self.beeper = Sound()
	self.csensor = ColorSensor()
	if self.csensor:connected() then
		print("Found csensor at " .. self.csensor:portName())
	else
		print("Didn't find csensor !?")
	end
end

function machine:csensor()
	self.csensor:setMode(ColorSensor.ModeColor)
	self.csensor:setMode(ColorSensor.ModeReflect)
	self.csensor:value()
	self.csensor:floatValue()
end

function machine:beep_start()
	self.beeper.tone(300, 100)
	sleep(0.2)
	self.beeper.tone(500, 125)
	sleep(0.2)
end

function machine:read_csensor_values()
	for i = 0, 150 do
		print("value: " .. self.csensor:value() .. " fvalue: " .. self.csensor:floatValue())
		sleep(0.1)
	end
end	

function machine:read_color_and_intensity()
	self.csensor:setMode("RGB-RAW")
	for i = 0, 100 do
		raw = {}
		for j = 0, 2 do
			raw[j] = self.csensor:value(j)
		end
		print("[ " .. raw[0] .. " , " .. raw[1] .. " , " .. raw[2] .. " ]")
		sleep(0.1)
	end
end	

function machine:test_color_sensor()
	print("Testing color sensor")
	print("Testing ModeColor")
	self.csensor:setMode(ColorSensor.ModeColor)
	self:read_csensor_values()
--	print("Testing ModeReflect")
--	self.csensor:setMode(ColorSensor.ModeReflect)
--	self:read_csensor_values()
--	print("Testing ModeAmbient")
--	self.csensor:setMode(ColorSensor.ModeAmbient)
--	self:read_csensor_values()
	print("Done testing color sensor")
end

function machine:start()
	self:find_devices()
	self:beep_start()
	--self:test_motor(self.left_motor)
	--self:test_motor(self.right_motor)
	--self:test_color_sensor()
	self:read_color_and_intensity()
end

function machine:test_motor(motor)
	self.beeper.tone(200, 300)
	sleep(0.1)
	print("Turning motor...")
	motor:setPositionSP(motor:position() + 720)
	motor:setCommand("run-to-abs-pos")
	print("Command issued...")
	self.beeper.tone(300, 100)
	print("Sleeping...")
	sleep(3)
	self.beeper.tone(200, 100)
	print("Turning motor...")
	motor:setPositionSP(motor:position() - 720)
	motor:setCommand("run-to-abs-pos")
	print("Command issued...")
	self.beeper.tone(300, 100)
	print("Sleeping...")
	sleep(3)
	print("Stopping (if it were needed)...")
	self.beeper.tone(300, 100)
	motor:setStopCommand('coast')
	motor:setCommand('stop')
end

function machine:drive_over_there()
	self.beeper.tone(200, 100)
	self.beeper.tone(300, 100)
	self.beeper.tone(200, 100)
	self.beeper.tone(300, 400)
	self.left_motor:setPositionSP(2880)
	self.right_motor:setPositionSP(2880)
	self.left_motor:setCommand("run-to-rel-pos")
	self.right_motor:setCommand("run-to-rel-pos")
	sleep(10)
	self.left_motor:setCommand('stop')
	self.right_motor:setCommand('stop')
end

machine:start()
