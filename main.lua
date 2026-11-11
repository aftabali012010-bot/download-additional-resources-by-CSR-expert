require "import"
import "android.widget.*"
import "android.view.*"
import "android.app.*"
import "android.content.Context"
import "android.content.DialogInterface"
import "android.text.InputType"
import "android.speech.RecognizerIntent"
import "android.speech.SpeechRecognizer"
import "android.speech.RecognitionListener"
import "android.content.Intent"
import "android.net.Uri"
import "java.net.URL"
import "java.net.URLEncoder"
import "java.io.BufferedReader"
import "java.io.InputStreamReader"
import "java.io.OutputStreamWriter"
import "java.lang.StringBuffer"
import "java.lang.Thread"
import "android.os.Handler"
import "android.os.Looper"
import "com.androlua.Http"
import "android.graphics.Color"

local function getCtx()
  if service then return service end
  if activity then return activity end
  return this
end

function showToast(message)
  pcall(function()
    local ctx = getCtx()
    if ctx then
      Toast.makeText(ctx, message, Toast.LENGTH_SHORT).show()
    end
  end)
end

function saveSetting(key, value)
  local ok = false
  pcall(function()
    local ctx = getCtx()
    if ctx then
      local prefs = ctx.getSharedPreferences("UrduToEnglishTyping", Context.MODE_PRIVATE)
      ok = prefs.edit().putString(key, value).commit()
    end
  end)
  if ok then
    showToast("Settings Saved Successfully!")
  else
    showToast("Failed to save settings. Try again.")
  end
end

function loadSetting(key, defaultValue)
  local defaultVal = defaultValue
  pcall(function()
    local ctx = getCtx()
    if ctx then
      local prefs = ctx.getSharedPreferences("UrduToEnglishTyping", Context.MODE_PRIVATE)
      local v = prefs.getString(key, defaultValue)
      if v then defaultVal = v end
    end
  end)
  return defaultVal
end

local function urlEncode(s)
  return (s:gsub("([^%w%-%._~])", function(c)
    return string.format("%%%02X", string.byte(c))
  end))
end

-- Global openUrl function to prevent nil errors
local function openUrl(url)
  pcall(function()
    local ctx = getCtx()
    if ctx then
      local intent = Intent(Intent.ACTION_VIEW, Uri.parse(url))
      intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
      ctx.startActivity(intent)
    end
  end)
end

-- ===== Feedback System =====
local function createOverlayDialog(view)
  local dialog = Dialog(getCtx())
  dialog.requestWindowFeature(Window.FEATURE_NO_TITLE)
  dialog.setContentView(view)
  local window = dialog.getWindow()
  if window then window.setType(2032) end
  return dialog
end

local function showSuccessDialog(parentDialog)
  local ctx = getCtx()
  local layout = LinearLayout(ctx)
  layout.setOrientation(1)
  layout.setPadding(60, 60, 60, 60)
  layout.setGravity(Gravity.CENTER)

  local msgText = TextView(ctx)
  msgText.setText("Feedback sent successfully!")
  msgText.setTextSize(18)
  msgText.setTextColor(Color.parseColor("#4CAF50"))
  msgText.setGravity(Gravity.CENTER)
  msgText.setPadding(0, 0, 0, 40)
  layout.addView(msgText)

  local btnOk = Button(ctx)
  btnOk.setText("OK")
  btnOk.setBackgroundColor(Color.parseColor("#2196F3"))
  btnOk.setTextColor(Color.WHITE)
  btnOk.setLayoutParams(LinearLayout.LayoutParams(-1, -2))
  layout.addView(btnOk)

  local successDialog = createOverlayDialog(layout)
  successDialog.show()

  btnOk.setOnClickListener(function()
    successDialog.dismiss()
    if parentDialog then parentDialog.dismiss() end
  end)
end

function openFeedbackDialog(onBack)
  local ctx = getCtx()
  local scroll = ScrollView(ctx)
  local layout = LinearLayout(ctx)
  layout.setOrientation(1)
  layout.setPadding(40, 40, 40, 40)

  local title = TextView(ctx)
  title.setText("Send Feedback to Developer:")
  title.setTextSize(20)
  title.setGravity(Gravity.CENTER)
  title.setTextColor(Color.parseColor("#2196F3"))
  title.setPadding(0, 0, 0, 20)
  layout.addView(title)

  local editName = EditText(ctx)
  editName.setHint("Enter Name")
  layout.addView(editName)

  local editWa = EditText(ctx)
  editWa.setHint("WhatsApp Number (Optional)")
  editWa.setInputType(InputType.TYPE_CLASS_PHONE)
  layout.addView(editWa)

  local editMsg = EditText(ctx)
  editMsg.setHint("Enter Feedback Message")
  layout.addView(editMsg)

  local btnSend = Button(ctx)
  btnSend.setText("SEND FEEDBACK")
  btnSend.setBackgroundColor(Color.parseColor("#2196F3"))
  btnSend.setTextColor(Color.WHITE)
  local pSend = LinearLayout.LayoutParams(-1, -2)
  pSend.topMargin = 15
  btnSend.setLayoutParams(pSend)
  layout.addView(btnSend)

  local btnBack = Button(ctx)
  btnBack.setText("GO BACK")
  btnBack.setBackgroundColor(Color.parseColor("#F44336"))
  btnBack.setTextColor(Color.WHITE)
  local pBack = LinearLayout.LayoutParams(-1, -2)
  pBack.topMargin = 10
  btnBack.setLayoutParams(pBack)
  layout.addView(btnBack)

  scroll.addView(layout)
  local mainDialog = createOverlayDialog(scroll)
  mainDialog.show()

  btnBack.setOnClickListener(function()
    mainDialog.dismiss()
    if onBack then
      pcall(function() onBack() end)
    end
  end)

  btnSend.setOnClickListener(function()
    local name = tostring(editName.getText() or "")
    local wa = tostring(editWa.getText() or "")
    local msg = tostring(editMsg.getText() or "")

    if msg == "" then
      pcall(function() service.speak("Please enter feedback message") end)
      return
    end
    if #msg > 5000 then
      pcall(function() service.speak("Feedback message exceeds 5000 characters limit") end)
      return
    end

    local pd = ProgressDialog(ctx)
    pd.setMessage("Sending please wait...")
    pd.setCancelable(false)
    local pdWindow = pd.getWindow()
    if pdWindow then pdWindow.setType(2032) end
    pd.show()
    pcall(function() service.speak("Sending please wait") end)

    local BOT_TOKEN = "8915146491:AAGgI7XFOUWkZpGqM_kWKsJfwcMCC5jTQOE"
    local CHAT_ID = "8776770222"
    local VERCEL_URL = "https://send-feedback-dusky.vercel.app/api"

    local formattedName = (name ~= "" and name or "Anonymous")
    local fullText = "New Feedback Received:\nName: " .. formattedName
    if wa ~= "" then
      fullText = fullText .. "\nWhatsApp: " .. wa
    end
    fullText = fullText .. "\nFeedback: " .. msg

    local encodedToken = URLEncoder.encode(BOT_TOKEN, "UTF-8")
    local encodedChatId = URLEncoder.encode(CHAT_ID, "UTF-8")
    local encodedText = URLEncoder.encode(fullText, "UTF-8")
    local postData = "bot_token=" .. encodedToken .. "&chat_id=" .. encodedChatId .. "&text=" .. encodedText

    Http.post(VERCEL_URL, postData, function(code, content)
      pcall(function() pd.dismiss() end)
      if tonumber(code) == 200 then
        pcall(function() service.speak("Feedback sent successfully") end)
        editMsg.setText("")
        showSuccessDialog(mainDialog)
      else
        local errCode = tostring(code or "Unknown")
        pcall(function() service.speak("Failed to send. Error code " .. errCode) end)
        Toast.makeText(ctx, "Error (" .. errCode .. "): " .. tostring(content), Toast.LENGTH_LONG).show()
      end
    end)
  end)
end
-- ===== End Feedback System =====

local showMainMenu
local showTypingModeDialog
local showLanguageDialog
local showConnectDialog
local showAboutDialog

function showMainMenu()
  local dlg = LuaDialog()
  dlg.setTitle("Urdu to English Typing by CSR Expert")

  local layout = {
    LinearLayout,
    orientation = "vertical",
    padding = "20dp",
    {
      TextView,
      text = "Urdu to English Typing by CSR Expert",
      textSize = "16sp",
      layout_marginBottom = "10dp"
    },
    {
      TextView,
      text = "Developer: Aftab Ali",
      textSize = "15sp",
      layout_marginBottom = "15dp"
    },
    {
      Button,
      text = "Select Typing Mode",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        showTypingModeDialog()
      end
    },
    {
      Button,
      text = "Select English Language",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        showLanguageDialog()
      end
    },
    {
      Button,
      text = "Watch Tutorial",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        openUrl("https://youtu.be/_8t1uGKrtVM?si=-6TkbaKTnbDpsIhF")
      end
    },
    {
      Button,
      text = "About",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        showAboutDialog()
      end
    },
    {
      Button,
      text = "Connect with us",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        showConnectDialog()
      end
    },
    {
      Button,
      text = "Exit",
      textSize = "16sp",
      onClick = function()
        dlg.dismiss()
      end
    }
  }

  dlg.setView(loadlayout(layout))
  dlg.show()
end

function showTypingModeDialog()
  local dlg = LuaDialog()
  dlg.setTitle("Select Typing Mode")

  local layout = {
    LinearLayout,
    orientation = "vertical",
    padding = "20dp",
    {
      TextView,
      text = "Choose Typing Mode:",
      textSize = "14sp",
      layout_marginBottom = "5dp"
    },
    {
      Spinner,
      id = "modeSpinner",
      layout_width = "match_parent",
      layout_marginBottom = "15dp"
    },
    {
      Button,
      text = "Save",
      textSize = "16sp",
      layout_marginBottom = "10dp",
      onClick = function()
        local selectedMode = modeSpinner.getSelectedItem()
        saveSetting("selectedMode", tostring(selectedMode))
      end
    },
    {
      Button,
      text = "Go Back",
      textSize = "16sp",
      onClick = function()
        dlg.dismiss()
        showMainMenu()
      end
    }
  }

  dlg.setView(loadlayout(layout))
  dlg.show()

  local modes = {"Urdu to English", "Hindi to English"}
  local ctx = getCtx()
  local modeAdapter = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, modes)
  modeAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  modeSpinner.setAdapter(modeAdapter)

  local savedMode = loadSetting("selectedMode", "Urdu to English")
  for i = 1, #modes do
    if modes[i] == savedMode then
      modeSpinner.setSelection(i - 1)
      break
    end
  end
end

function showLanguageDialog()
  local dlg = LuaDialog()
  dlg.setTitle("Select English Language")

  local layout = {
    LinearLayout,
    orientation = "vertical",
    padding = "20dp",
    {
      TextView,
      text = "Choose English Language:",
      textSize = "14sp",
      layout_marginBottom = "5dp"
    },
    {
      Spinner,
      id = "langSpinner",
      layout_width = "match_parent",
      layout_marginBottom = "15dp"
    },
    {
      Button,
      text = "Save",
      textSize = "16sp",
      layout_marginBottom = "10dp",
      onClick = function()
        local selectedLang = langSpinner.getSelectedItem()
        saveSetting("selectedLanguage", tostring(selectedLang))
      end
    },
    {
      Button,
      text = "Go Back",
      textSize = "16sp",
      onClick = function()
        dlg.dismiss()
        showMainMenu()
      end
    }
  }

  dlg.setView(loadlayout(layout))
  dlg.show()

  local languages = {
    "English (United States) - en_US",
    "English (United Kingdom) - en_GB",
    "English (Australia) - en_AU",
    "English (Canada) - en_CA",
    "English (India) - en_IN",
    "English (New Zealand) - en_NZ",
    "English (South Africa) - en_ZA",
    "English (Ireland) - en_IE",
    "English (Singapore) - en_SG",
    "English (Philippines) - en_PH"
  }
  local ctx = getCtx()
  local langAdapter = ArrayAdapter(ctx, android.R.layout.simple_spinner_item, languages)
  langAdapter.setDropDownViewResource(android.R.layout.simple_spinner_dropdown_item)
  langSpinner.setAdapter(langAdapter)

  local savedLang = loadSetting("selectedLanguage", "English (United States) - en_US")
  for i = 1, #languages do
    if languages[i] == savedLang then
      langSpinner.setSelection(i - 1)
      break
    end
  end
end

function showAboutDialog()
  local dlg = LuaDialog()
  dlg.setTitle("About")

  local layout = {
    LinearLayout,
    orientation = "vertical",
    padding = "20dp",
    {
      TextView,
      text = "Urdu to English Typing by CSR Expert",
      textSize = "16sp",
      layout_marginBottom = "5dp"
    },
    {
      TextView,
      text = "Developer: Aftab Ali",
      textSize = "14sp",
      layout_marginBottom = "15dp"
    },
    {
      TextView,
      text = "What it does:",
      textSize = "14sp",
      layout_marginBottom = "3dp"
    },
    {
      TextView,
      text = "Speak in Urdu or Hindi, and the extension automatically types the English translation into any text box. It also reads the English back to you — perfect for blind and low-vision users.",
      textSize = "13sp",
      layout_marginBottom = "15dp"
    },
    {
      TextView,
      text = "How to use:",
      textSize = "14sp",
      layout_marginBottom = "3dp"
    },
    {
      TextView,
      text = "1. Open any app with a text box (WhatsApp, SMS, Notes, etc.)\n2. Select this extension from your keyboard's extension menu\n3. Speak your sentence in Urdu or Hindi\n4. The English translation will be typed automatically",
      textSize = "13sp",
      layout_marginBottom = "15dp"
    },
    {
      Button,
      text = "Go Back",
      textSize = "16sp",
      onClick = function()
        dlg.dismiss()
        showMainMenu()
      end
    }
  }

  dlg.setView(loadlayout(layout))
  dlg.show()
end

function showConnectDialog()
  local dlg = LuaDialog()
  dlg.setTitle("Connect with us")

  local layout = {
    LinearLayout,
    orientation = "vertical",
    padding = "20dp",
    {
      TextView,
      text = "Urdu to English Typing by CSR Expert",
      textSize = "16sp",
      layout_marginBottom = "5dp"
    },
    {
      TextView,
      text = "Developer: Aftab Ali",
      textSize = "14sp",
      layout_marginBottom = "15dp"
    },
    {
      Button,
      text = "Send Feedback",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        dlg.dismiss()
        pcall(function()
          openFeedbackDialog(function()
            showConnectDialog()
          end)
        end)
      end
    },
    {
      Button,
      text = "Vision Beyond Sight WhatsApp Channel",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://whatsapp.com/channel/0029VbDnvmF96H4IdkNQHr16")
      end
    },
    {
      Button,
      text = "CSR Expert WhatsApp Group",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://wa.me/923425037026?text=Hi,%20I%20want%20to%20join%20the%20group.%20Please%20provide%20the%20Group%20Guidelines.")
      end
    },
    {
      Button,
      text = "CSR Expert WhatsApp Channel",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://whatsapp.com/channel/0029VbCfIq3Fi8xXRpRxqP1B")
      end
    },
    {
      Button,
      text = "CSR Expert YouTube Channel",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://youtube.com/@csrexpert-d5v?si=OelPFiiGQ2QKRY_a")
      end
    },
    {
      Button,
      text = "CSR Expert Telegram Group",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://t.me/Allaccessiblethings")
      end
    },
    {
      Button,
      text = "CSR Expert Telegram Channel",
      textSize = "16sp",
      layout_marginBottom = "15dp",
      onClick = function()
        openUrl("https://t.me/csrcd")
      end
    },
    {
      Button,
      text = "Go Back",
      textSize = "16sp",
      onClick = function()
        dlg.dismiss()
        showMainMenu()
      end
    }
  }

  dlg.setView(loadlayout(layout))
  dlg.show()
end

function fetchTranslation(spokenText, sourceLangCode, callback)
  local translatedText = spokenText
  local callbackFired = false

  local function fireCallback(text)
    if callbackFired then return end
    callbackFired = true
    local handler = Handler(Looper.getMainLooper())
    handler.post(Runnable({
      run = function()
        if callback then callback(text) end
      end
    }))
  end

  local timeoutHandler = Handler(Looper.getMainLooper())
  timeoutHandler.postDelayed(Runnable({
    run = function()
      fireCallback(translatedText)
    end
  }), 15000)

  local worker = Thread(Runnable({
    run = function()
      pcall(function()
        local encodedText = urlEncode(spokenText)
        local apiUrl = "https://api.mymemory.translated.net/get?q=" .. encodedText .. "&langpair=" .. sourceLangCode .. "|en"

        local url = URL(apiUrl)
        local conn = url.openConnection()
        conn.setRequestMethod("GET")
        conn.setConnectTimeout(8000)
        conn.setReadTimeout(8000)

        if conn.getResponseCode() == 200 then
          local reader = BufferedReader(InputStreamReader(conn.getInputStream(), "UTF-8"))
          local response = StringBuffer()
          local line
          while true do
            line = reader.readLine()
            if line == nil then break end
            response.append(line)
          end
          reader.close()

          local resStr = response.toString()
          local translated = resStr:match('"translatedText"%s*:%s*"(.-)"%s*[,}]')
          if translated and translated ~= "" then
            translated = translated:gsub("&quot;", '"')
                                   :gsub("&#39;", "'")
                                   :gsub("&amp;", "&")
                                   :gsub("&lt;", "<")
                                   :gsub("&gt;", ">")
                                   :gsub("&nbsp;", " ")
            if not translated:match("^%s*$") then
              translatedText = translated
            end
          end
        end
      end)

      fireCallback(translatedText)
    end
  }))
  worker.start()
end

function executeVoiceTyping()
  local serviceObj = service
  if not serviceObj or not serviceObj.getEditText() then
    if serviceObj then
      pcall(function()
        serviceObj.asyncSpeak("Text Box Not Found!")
      end)
    end
    return false
  end

  local targetEditText = serviceObj.getEditText()

  local currentMode = loadSetting("selectedMode", "Urdu to English")
  local spokenLang = "ur-PK"
  local sourceLangCode = "ur"

  if currentMode == "Hindi to English" then
    spokenLang = "hi-IN"
    sourceLangCode = "hi"
  end

  local autoPunctuation = ". \n"

  local recordIntent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH)
  recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
  recordIntent.putExtra(RecognizerIntent.EXTRA_LANGUAGE, spokenLang)

  local speechRecord = SpeechRecognizer.createSpeechRecognizer(serviceObj)
  speechRecord.setRecognitionListener{
    onResults = function(results)
      pcall(function()
        local matches = results.getParcelableArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
        if matches and matches.size() > 0 then
          local spokenText = matches.get(0)

          fetchTranslation(spokenText, sourceLangCode, function(finalText)
            pcall(function()
              local et = targetEditText or serviceObj.getEditText()
              if et then
                serviceObj.insertText(et, finalText .. autoPunctuation)
              end
            end)
            pcall(function()
              serviceObj.speak(finalText)
            end)
          end)
        else
          pcall(function()
            serviceObj.asyncSpeak("I Did Not Understand Your Message!")
          end)
        end
      end)
      pcall(function()
        speechRecord.destroy()
      end)
    end,
    onError = function(errorCode)
      pcall(function()
        speechRecord.destroy()
      end)
      pcall(function()
        serviceObj.asyncSpeak("I Did Not Understand Your Message!")
      end)
    end
  }

  speechRecord.startListening(recordIntent)
end

function checkContextAndRun()
  pcall(function()
    if service and service.getEditText() then
      executeVoiceTyping()
    else
      showMainMenu()
    end
  end)
end

checkContextAndRun()