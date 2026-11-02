require "import"
import "com.androlua.Ticker"
if ti then
ti.stop()
  service.speak("skip add disabled for youtube thank you for using!")
  ti=nil
  return true
end
ti=Ticker()
ti.Period=100
ti.onTick=function()
service.click({{"Skip ad",}})
end
ti.start()
service.speak("skip add unabled for youtube")