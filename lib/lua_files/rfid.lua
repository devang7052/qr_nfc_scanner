function main()
    local student_name = ""
    local function read_rfid()
        rfid_start_reading()
        local start_time = millis()
        local timeout = 10000

        while true do
            local success, uid = rfid_read_data()
            if success then
                buzzer_beep(100, 50, 1)
                local json_output = string.format(
                                        '{"msgtype":"rfid","value":"%s","device":"Devices.memoryBoard"}',
                                        uid)
                ble_print(json_output)
                rfid_stop_reading()
                clear_display()
                return true
            end

            if (millis() - start_time) > timeout then
                rfid_stop_reading()
                clear_display()
                return false
            end
            delay(200)
        end
    end

main()