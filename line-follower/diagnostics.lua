require 'ev3dev'

machine = {
}

function machine:find_devices()
	self.left_motor = LargeMotor('B')
	self.left_motor:setSpeedRegulationEnabled('on')
	self.right_motor = LargeMotor('C')
	self.right_motor:setSpeedRegulationEnabled('on')
	self.beeper = Sound()
	self.csensor = ColorSensor('1')
end

function machine:csensor()
	self.csensor:setMode(ColorSensor.ModeColor)
	self.csensor:setMode(ColorSensor.ModeReflect)
	self.csensor:value()
	self.csensor:floatValue()
end

function machine:beep_start()
	self.beeper.tone(1000, 300)
	self.beeper.tone(4000, 100)
end

function machine:start()
	self:find_devices()
	self:beep_start()
	self:test_motor(self.left_motor)
	self:test_motor(self.right_motor)
	return self:start_driving_forward()
end

function machine:test_motor(motor)
	motor:setPosition(motor.position() + 90)
	motor:setPosition(motor.position() - 90)
	motor:setStopCommand('coast')
	motor:setCommand('stop')
end

machine:start()
