if adc.force_init_mode(adc.INIT_VDD33)
then
  node.restart()
  return -- don't bother continuing, the restart is scheduled
end


function sample()
  data = {}
  data.timestamp = tmr.now()
  data.vdd = adc.readvdd33() / 1000

  return data
end

function display(data)
  for k,v in pairs(data) do
    print(k..'='..v)
  end
end

function store(api_key, data, callback)
  payload = '{"api_key":"'..api_key..'","field1":'..data.vdd..'}'
  http.post('http://api.thingspeak.com/update',
    'Content-Type: application/json\r\n',
    payload,
    function(statusCode, data)
      print("Response: "..statusCode..", "..data)
      callback()
    end)
end


function process(api_key, interval)
  duration = interval * 1000000

  cb = function()
    elapsed = tmr.now()
    remaining = duration - elapsed
    if remaining < 1000000 then
      remaining = 1000000
    end
    print("Deep-sleeping for "..(remaining / 1000000).." seconds")
    node.dsleep(remaining)
  end

  data = sample()
  display(data)
  store(api_key, data, cb)
end


process(THINGSPEAK_API_KEY, 30)
