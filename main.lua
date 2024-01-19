-- define default values

function loadSched()
    if not libSCHED then
        -- Loadable code chunk is called immediately and returns libGUI
        libSCHED = loadfile("libscheduler.lua")
    end
    return libSCHED()
end

local function paint4th(widget)
    -- 1/4 scree 388x132 (supported)
    paint6th(widget)
end

local function paintCell(cellIndex, cellData, x, y)
    lcd.color(lcd.RGB(0xF8, 0xB0, 0x38))
    lcd.drawText(x, y, "C" .. cellIndex .. " : ", LEFT)

    local text_w, text_h = lcd.getTextSize("C" .. cellIndex .. " : ")

    if cellData.low < 3.7 then lcd.color(RED) else lcd.color(WHITE) end
    x = x + text_w
    lcd.drawText(x, y, cellData.low, LEFT)

    lcd.color(BLACK)
    text_w, text_h = lcd.getTextSize(cellData.low)
    x = x + text_w
    lcd.drawText(x, y, "/", LEFT)

    if cellData.current < 3.7 then lcd.color(RED) else lcd.color(WHITE) end
    text_w, text_h = lcd.getTextSize("/")
    x = x + text_w
    lcd.drawText(x, y, cellData.current, LEFT)
end

local function paint6th(widget)
    -- 1/4 scree 388x132 (supported)

    function paint2Cells(widget)
        local y = 5
        local w, h = lcd.getWindowSize()
        lcd.font(FONT_L)
        local font_w, font_h = lcd.getTextSize(" ")
        for i, v in ipairs(widget.values) do
            local vLabel = "C" .. i .. " : " .. v.low .. "/" .. v.current
            local x = w / 2 - string.len(vLabel) * font_w
            paintCell(i, v, x, y)
            y = y + font_h
        end
    end

    function paint4Cells(widget, startIndex)
        local y = 5
        lcd.font(FONT_L)
        local font_w, font_h = lcd.getTextSize(" ")
        local endIndex = startIndex + 3
        if endIndex > #widget.values then endIndex = #widget.values end
        print("endIndex: " .. endIndex)
        for i=startIndex, endIndex, 2 do
            local vLabel = "C" .. i .. " : " .. widget.values[i].low .. "/" .. widget.values[i].current
            local x = 20
            paintCell(i, widget.values[i], x, y)
            if i+1 <= #widget.values then
                x = x+1 + string.len(vLabel) * font_w *2 + 15
                paintCell(i+1, widget.values[i+1], x, y)
            end
            y = y + font_h
        end
    end

    function paintAllCells(widget)
        local y = 5
        lcd.font(FONT_S)
        local font_w, font_h = lcd.getTextSize(" ")
        for i=1, #widget.values, 3 do
            --print("i: " .. i)
            local vLabel = "C" .. i .. ":" .. widget.values[i].low .. "/" .. widget.values[i].current
            local x = 10
            paintCell(i, widget.values[i], x, y)
            if i+1 <= #widget.values then
                x = x + string.len(vLabel) * font_w + 50
                paintCell(i+1, widget.values[i+1], x, y)
            end

            if i+2 <= #widget.values then
                x = x+1 + string.len(vLabel) * font_w + 50
                paintCell(i+2, widget.values[i+2], x, y)
            end
            y = y + font_h
        end
    end

    local y = 5
    local w, h = lcd.getWindowSize()

    if #widget.values == 2 then
        paint2Cells(widget)
    elseif #widget.values == 3 or #widget.values == 4 then
        paint4Cells(widget, 1)
    elseif #widget.values >= 5 then
        if widget.displayState == 0 then
            paintAllCells(widget)
        elseif widget.displayState == 1 then
            paint4Cells(widget, 1)
        else
            paint4Cells(widget, 5)
        end
    end
end

function reset_if_needed(widget)
    -- test if the reset switch is toggled, if so then reset all internal flags
    if widget.resetSwitch then
        -- Update switch position
        local debounced = widget.scheduler.check('reset_sw')
        --print("debounced: " .. tostring(debounced))
        local resetSwitchValue = widget.resetSwitch:value()
        if (debounced == nil or debounced == true) and -1024 ~= resetSwitchValue then
            -- reset switch
            widget.scheduler.add('reset_sw', false, 2) -- add the reset switch to the scheduler
            --print("reset start task: " .. tostring(service.scheduler.tasks['reset_sw'].ready))
            widget.scheduler.clear('reset_sw') -- set the reset switch to false in the scheduler so we don't run again
            --print("reset task: " .. tostring(service.scheduler.tasks['reset_sw'].ready))
            --print("reset switch toggled - debounced: " .. tostring(debounced))
            print("reset event")
            widget.scheduler.reset()
        elseif -1024 == resetSwitchValue then
            --print("reset switch released")
            widget.scheduler.remove('reset_sw')
        end
    end
end

----------------------------------------------------------------------------------------------------------------------
local name = "Voltage Sag"
local key = "vMin"

local function create()
    local libscheduler = libscheduler or loadSched()
    widget = {
        values = {},
        lipoSensor = nil,
        displayState = 0,
        resetSwitch = nil, -- switch to reset script, usually same switch to reset timers
        scheduler = libscheduler.new(),
    }
    return widget
end

local function paint(widget)

    local w, h = lcd.getWindowSize()
    local y = 0

    if w == 388 and h == 132 then
        paint4th(widget)
    elseif w == 300 and h == 66 then
        paint6th(widget)
    else
        paint4th(widget)
    end
end

local function wakeup(widget)
    --widget.bg_func()
    local sensor = system.getSource(widget.lipoSensor:name())
    local updateRequired = false

    reset_if_needed(widget)
    if sensor ~= nil then
        for cell = 1, sensor:value(OPTION_CELL_COUNT) do
            local cellVoltage = sensor:value(OPTION_CELL_INDEX(cell))

            if widget.values[cell] == nil or widget.values[cell].current ~= cellVoltage then
                updateRequired = true
                if widget.values[cell] == nil then
                    widget.values[cell] = {}
                end
                widget.values[cell].current = cellVoltage
                if widget.values[cell].low == nil or widget.values[cell].low > cellVoltage then
                    widget.values[cell].low = cellVoltage
                end
            end
        end

        if updateRequired then
            lcd.invalidate()
        end
    end

end

local function configure(widget)
    line = form.addLine("lipoSensor")
    form.addSourceField(line, nil,
            function() return widget.lipoSensor end,
            function(value) widget.lipoSensor = value end
    )

    line = form.addLine("Reset Switch")
    form.addSwitchField(line, form.getFieldSlots(line)[0], function()
        return widget.resetSwitch
    end, function(value)
        widget.resetSwitch = value
    end)
end

local function read(widget)
    widget.lipoSensor = storage.read("lipoSensor")
    widget.resetSwitch = storage.read("resetSwitch")
end

local function write(widget)
    storage.write("lipoSensor" ,widget.lipoSensor)
    storage.write("resetSwitch", widget.resetSwitch)
end

local function event(widget, category, value, x, y)
    print("Event received:", category, value, x, y)
    if category == EVT_KEY and value == KEY_ENTER_BREAK or category == EVT_TOUCH then
        widget.displayState = (widget.displayState + 1) % 3
        print("touch event: " .. widget.displayState)
        lcd.invalidate()
        return true
    else
        return false
    end
end

local function init()
    system.registerWidget({ key = key, name = name, create = create, paint = paint, wakeup = wakeup,
                            configure = configure, read = read, write = write, persistent = true, event=event })
end

return { init = init }
