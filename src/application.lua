if adc.force_init_mode(adc.INIT_VDD33)
then
  node.restart()
  return -- don't bother continuing, the restart is scheduled
end

-- I2C pins
id  = 0  -- need this to identify (software) I2C bus?
sda = 3  -- connect to pin GPIO0
scl = 4  -- connect to pin GPIO2


function sample()
  local data = {}
  data.timestamp = tmr.now()
  data.vdd = adc.readvdd33() / 1000

  status = bme280.init(sda, scl)
  if status == 2 then  -- Check if BME280?
    local temp, pressure, humidity = bme280.read()

    if temp ~= nil then
      data.temperature = temp / 100
      data.pressure = pressure / 1000
      data.humidity = humidity / 1000
    end
  end

  status = tsl2561.init(sda, scl)
  if status == tsl2561.TSL2561_OK then
    data.lux = tsl2561.getlux()
  end

  return data
end

function display(data)
  for k,v in pairs(data) do
    print(' '..k..'='..v)
  end
end

function store(api_key, data, callback)
  local payload = {
      api_key = api_key,
      field1 = data.vdd,
      field2 = data.temperature,
      field3 = data.humidity,
      field4 = data.pressure,
      field5 = data.lux
  }

  http.post('http://api.thingspeak.com/update',
    'Content-Type: application/json\r\n',
    sjson.encode(payload),
    function(status, body)
      print("HTTP Response: status="..status..", body="..body)
      callback()
    end)
end


function process(api_key, interval)
  local duration = interval * 1000000

  local cb = function()
    elapsed = tmr.now()
    remaining = duration - elapsed
    if remaining < 1000000 then
      remaining = 1000000
    end
    print("Deep-sleeping for "..(remaining / 1000000).." seconds")
    node.dsleep(remaining)
  end

  local data = sample()
  display(data)
  store(api_key, data, cb)
end


function i2c_scan()
  -- Based on work by zeroday & sancho among many other open source authors
  -- This code is public domain, attribution to gareth@l0l.org.uk appreciated.

  -- initialize i2c with our id and pins in slow mode :-)
  i2c.setup(id, sda, scl, i2c.SLOW)

  -- user defined function: read from reg_addr content of dev_addr
  local read_reg = function (dev_addr, reg_addr)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.TRANSMITTER)
    i2c.write(id, reg_addr)
    i2c.stop(id)
    i2c.start(id)
    i2c.address(id, dev_addr, i2c.RECEIVER)
    c=i2c.read(id,1)
    i2c.stop(id)
    return c
  end

  print("Scanning I2C Bus")
  for i = 0, 127 do
    if (string.byte(read_reg(i, 0)) == 0) then
      print("I2C device found at address: 0x"..string.format("%02X",i))
    end
  end
end

--i2c_scan()
process(THINGSPEAK_API_KEY, 120)
