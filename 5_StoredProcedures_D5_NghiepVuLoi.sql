USE QuanLyDatVeMayBay_06;
GO

-- =====================================================================
-- DẠNG 5: STORED PROCEDURE NGHIỆP VỤ LÕI (SỬ DỤNG TRANSACTION)
-- =====================================================================

-- 10. sp_DatVe: Nghiệp vụ đặt vé phức tạp
CREATE PROCEDURE sp_DatVe
    @MaCB VARCHAR(20),
    @MaKH INT,
    @MaNV VARCHAR(20),
    @SoGhe VARCHAR(10),
    @HangGhe NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN; -- Bắt đầu giao dịch an toàn (Chống xung đột dữ liệu)

        -- 1. Kiểm tra chuyến bay hợp lệ
        DECLARE @SoGheTrong INT, @GiaVeCoBan DECIMAL(18,2), @TrangThaiCB NVARCHAR(50);
        
        -- Dùng (UPDLOCK) để khóa dòng này, người khác không thể tranh mua cùng 1 chuyến bay lúc này
        SELECT @SoGheTrong = SoGheTrong, @GiaVeCoBan = GiaVeCoBan, @TrangThaiCB = TrangThai
        FROM CHUYENBAY WITH (UPDLOCK) 
        WHERE MaCB = @MaCB;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Chuyến bay không tồn tại!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        IF @TrangThaiCB <> N'Sắp bay'
        BEGIN
            RAISERROR(N'Chuyến bay đã cất cánh hoặc bị hủy. Không thể đặt vé!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        IF @SoGheTrong <= 0
        BEGIN
            RAISERROR(N'Chuyến bay đã hết chỗ trống!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        -- 2. Kiểm tra trùng ghế
        IF EXISTS (SELECT 1 FROM VE WHERE MaCB = @MaCB AND SoGhe = @SoGhe AND TrangThai <> N'Đã hủy')
        BEGIN
            RAISERROR(N'Ghế %s đã có người đặt!', 16, 1, @SoGhe);
            ROLLBACK TRAN; RETURN;
        END

        -- 3. Tính giá vé thực tế
        DECLARE @GiaTien DECIMAL(18,2) = @GiaVeCoBan;
        IF @HangGhe = N'Thương gia' SET @GiaTien = @GiaVeCoBan * 2.0;

        -- 4. Thêm vé mới (Trạng thái mặc định: Chưa thanh toán)
        INSERT INTO VE (MaCB, MaKH, MaNV, SoGhe, HangGhe, GiaTien, NgayDat, TrangThai)
        VALUES (@MaCB, @MaKH, @MaNV, @SoGhe, @HangGhe, @GiaTien, GETDATE(), N'Chưa thanh toán');

        DECLARE @MaVeMoi INT = SCOPE_IDENTITY();

        -- 5. Cập nhật lại số ghế trống cho chuyến bay
        UPDATE CHUYENBAY
        SET SoGheTrong = SoGheTrong - 1
        WHERE MaCB = @MaCB;

        COMMIT TRAN; -- Chốt giao dịch
        PRINT N'Đặt vé thành công! Mã vé của bạn là: ' + CAST(@MaVeMoi AS VARCHAR);
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN; -- Hủy giao dịch nếu có lỗi
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

-- 11. sp_ThanhToanVe: Nghiệp vụ thanh toán
CREATE PROCEDURE sp_ThanhToanVe
    @MaVe INT,
    @PhuongThuc NVARCHAR(50)
AS
BEGIN
    BEGIN TRY
        BEGIN TRAN;

        DECLARE @TrangThaiVe NVARCHAR(50), @GiaTien DECIMAL(18,2);
        SELECT @TrangThaiVe = TrangThai, @GiaTien = GiaTien
        FROM VE WITH (UPDLOCK)
        WHERE MaVe = @MaVe;

        IF @@ROWCOUNT = 0
        BEGIN
            RAISERROR(N'Vé không tồn tại!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        IF @TrangThaiVe = N'Đã thanh toán'
        BEGIN
            RAISERROR(N'Vé này đã được thanh toán trước đó!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        IF @TrangThaiVe = N'Đã hủy'
        BEGIN
            RAISERROR(N'Vé này đã bị hủy, không thể thanh toán!', 16, 1);
            ROLLBACK TRAN; RETURN;
        END

        -- Tìm lần thanh toán tiếp theo
        DECLARE @LanTT INT;
        SELECT @LanTT = ISNULL(MAX(LanTT), 0) + 1 FROM THANHTOAN WHERE MaVe = @MaVe;

        -- Ghi nhận thanh toán
        INSERT INTO THANHTOAN (LanTT, MaVe, SoTien, NgayTT, PhuongThuc)
        VALUES (@LanTT, @MaVe, @GiaTien, GETDATE(), @PhuongThuc);

        -- Cập nhật trạng thái vé
        UPDATE VE SET TrangThai = N'Đã thanh toán' WHERE MaVe = @MaVe;

        COMMIT TRAN;
        PRINT N'Thanh toán vé thành công!';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO

-- 12. sp_HuyVeKhachHang: Nghiệp vụ hủy vé (Tái sử dụng SP Dạng 2)
CREATE PROCEDURE sp_HuyVeKhachHang
    @MaVe INT
AS
BEGIN
    BEGIN TRY
        -- 1. Gọi SP Dạng 2 (Đã tạo trước đó) để kiểm tra xem có được phép hủy không
        DECLARE @ThongBao NVARCHAR(500);
        DECLARE @KetQuaCheck INT;
        
        EXEC @KetQuaCheck = sp_KiemTraTrangThaiVe @MaVe = @MaVe, @ThongBao = @ThongBao OUTPUT;

        -- Nếu Return 1 (Lỗi) thì văng lỗi và ngừng xử lý
        IF @KetQuaCheck = 1
        BEGIN
            RAISERROR(@ThongBao, 16, 1);
            RETURN;
        END

        -- 2. Tiến hành hủy vé nếu hợp lệ
        BEGIN TRAN;

        DECLARE @MaCB VARCHAR(20);
        SELECT @MaCB = MaCB FROM VE WHERE MaVe = @MaVe;

        -- Đổi trạng thái vé
        UPDATE VE SET TrangThai = N'Đã hủy' WHERE MaVe = @MaVe;

        -- Hoàn lại ghế trống cho chuyến bay
        UPDATE CHUYENBAY SET SoGheTrong = SoGheTrong + 1 WHERE MaCB = @MaCB;

        COMMIT TRAN;
        PRINT N'Hủy vé thành công. Đã hoàn lại chỗ trống cho hệ thống.';
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0 ROLLBACK TRAN;
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
    END CATCH
END;
GO
