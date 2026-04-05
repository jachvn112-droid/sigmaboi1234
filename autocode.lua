local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CodeRedeemRemote = ReplicatedStorage:WaitForChild("RemoteEvents"):WaitForChild("CodeRedeem")

-- Gọi file cấu hình code của game để lấy danh sách
local success, CodesConfig = pcall(function()
    return require(ReplicatedStorage:WaitForChild("CodesConfig"))
end)

if not success then
    warn("❌ Không thể lấy dữ liệu từ CodesConfig. Có thể đường dẫn bị sai hoặc file chưa load.")
    return
end

-- Lấy bảng chứa các code
local codesList = CodesConfig.Codes

print("🚀 Bắt đầu Auto Redeem Codes...")

-- Vòng lặp chạy qua tất cả các code trong module
for codeName, codeData in pairs(codesList) do
    print("⏳ Đang thử nhập code: " .. tostring(codeName))
    
    -- Gửi request lên server (dùng pcall để script không bị lỗi ngắt quãng)
    local invokeSuccess, response = pcall(function()
        return CodeRedeemRemote:InvokeServer(codeName)
    end)
    
    if invokeSuccess then
        print("✅ Đã gửi lệnh redeem cho: " .. codeName)
    else
        print("⚠️ Lỗi khi thử nhập code " .. codeName .. " - " .. tostring(response))
    end
    
    -- Đợi 1 giây trước khi nhập code tiếp theo để tránh bị phát hiện spam/kick
    task.wait(1)
end

print("🎉 Hoàn tất quá trình nhập code!")
