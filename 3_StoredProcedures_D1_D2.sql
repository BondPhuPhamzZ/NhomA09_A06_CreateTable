-- =====================================================================
-- ĐỒ ÁN CSDL NÂNG CAO - A06: HỆ THỐNG QUẢN LÝ ĐẶT VÉ MÁY BAY
-- FILE 3: STORED PROCEDURES (PHẦN 1 - DẠNG 1 & DẠNG 2)
-- =====================================================================

USE QuanLyDatVeMayBay_A06;
GO

-- =====================================================================
-- DẠNG 1: STORED PROCEDURE VỚI THAM SỐ ĐẦU VÀO (INPUT PARAMETERS)
-- =====================================================================

-- 1. sp_ThemSanBay: INSERT có kiểm tra trùng mã MaSB
CREATE PROCEDURE sp_ThemSanBay
    @MaSB VARCHAR(10),
    @TenSB NVARCHAR(100),
    @ThanhPho NVARCHAR(100),
    @QuocGia NVARCHAR(100)
AS
BEGIN
    BEGIN TRY
        -- Kiểm tra trùng lặp Khóa Chính
        IF EXISTS (SELECT 1 FROM SANBAY WHERE MaSB = @MaSB)
        BEGIN
            RAISERROR(N'Lỗi: Mã sân bay %s đã tồn tại trong hệ thống!', 16, 1, @MaSB);
            RETURN;
        END

        INSERT INTO SANBAY (MaSB, TenSB, ThanhPho, QuocGia)
        VALUES (@MaSB, @TenSB, @ThanhPho, @QuocGia);
        
        PRINT N'Thêm sân bay thành công!';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- 2. sp_TimKhachHang: Tra cứu khách hàng theo SĐT, dùng IF EXISTS báo lỗi
CREATE PROCEDURE sp_TimKhachHang
    @SoDienThoai VARCHAR(20)
AS
BEGIN
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM SDT_KHACHHANG WHERE SoDienThoai = @SoDienThoai)
        BEGIN
            RAISERROR(N'Lỗi: Không tìm thấy khách hàng nào sử dụng số điện thoại %s', 16, 1, @SoDienThoai);
            RETURN;
        END

        SELECT kh.MaKH, kh.HoTen, kh.Email, kh.SoHoChieu, sdt.SoDienThoai
        FROM KHACHHANG kh
        JOIN SDT_KHACHHANG sdt ON kh.MaKH = sdt.MaKH
        WHERE sdt.SoDienThoai = @SoDienThoai;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- 3. sp_ThemChuyenBay: Kiểm tra tồn tại Khóa ngoại trước khi Insert
CREATE PROCEDURE sp_ThemChuyenBay
    @MaCB VARCHAR(20),
    @MaTuyen VARCHAR(20),
    @MaMB VARCHAR(20),
    @NgayGioDi DATETIME,
    @NgayGioDen DATETIME,
    @GiaVeCoBan DECIMAL(18,2)
AS
BEGIN
    BEGIN TRY
        -- Bắt lỗi 1: Trùng mã chuyến bay
        IF EXISTS (SELECT 1 FROM CHUYENBAY WHERE MaCB = @MaCB)
        BEGIN
            RAISERROR(N'Lỗi: Mã chuyến bay %s đã tồn tại!', 16, 1, @MaCB);
            RETURN;
        END

        -- Bắt lỗi 2: Khóa ngoại Tuyến bay không tồn tại
        IF NOT EXISTS (SELECT 1 FROM TUYENBAY WHERE MaTuyen = @MaTuyen)
        BEGIN
            RAISERROR(N'Lỗi: Tuyến bay %s không tồn tại trong hệ thống!', 16, 1, @MaTuyen);
            RETURN;
        END

        -- Bắt lỗi 3: Khóa ngoại Máy bay không tồn tại
        IF NOT EXISTS (SELECT 1 FROM MAYBAY WHERE MaMB = @MaMB)
        BEGIN
            RAISERROR(N'Lỗi: Máy bay %s không tồn tại!', 16, 1, @MaMB);
            RETURN;
        END

        -- Lấy tổng số ghế của máy bay để gán cho SoGheTrong ban đầu
        DECLARE @TongSoGhe INT;
        SELECT @TongSoGhe = TongSoGhe FROM MAYBAY WHERE MaMB = @MaMB;

        INSERT INTO CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
        VALUES (@MaCB, @MaTuyen, @MaMB, @NgayGioDi, @NgayGioDen, @GiaVeCoBan, @TongSoGhe, N'Sắp bay');
        
        PRINT N'Thêm chuyến bay mới thành công!';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- =====================================================================
-- DẠNG 2: STORED PROCEDURE TRẢ VỀ KẾT QUẢ BẰNG OUTPUT & RETURN
-- =====================================================================

-- 4. sp_TinhDoanhThuCB: Trả về tổng tiền của 1 chuyến bay qua biến OUTPUT
CREATE PROCEDURE sp_TinhDoanhThuCB
    @MaCB VARCHAR(20),
    @TongDoanhThu DECIMAL(18,2) OUTPUT
AS
BEGIN
    BEGIN TRY
        IF NOT EXISTS (SELECT 1 FROM CHUYENBAY WHERE MaCB = @MaCB)
        BEGIN
            RAISERROR(N'Lỗi: Chuyến bay %s không tồn tại!', 16, 1, @MaCB);
            RETURN;
        END

        -- Tính tổng tiền từ bảng Thanh Toán liên kết với Vé của chuyến bay này
        SELECT @TongDoanhThu = ISNULL(SUM(tt.SoTien), 0)
        FROM THANHTOAN tt
        JOIN VE v ON tt.MaVe = v.MaVe
        WHERE v.MaCB = @MaCB AND v.TrangThai = N'Đã thanh toán';

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- 5. sp_KiemTraTrangThaiVe: Kết hợp RETURN và OUTPUT
-- RETURN 0: Hợp lệ (Cho phép hủy), RETURN 1: Lỗi (Không cho hủy)
CREATE PROCEDURE sp_KiemTraTrangThaiVe
    @MaVe INT,
    @ThongBao NVARCHAR(500) OUTPUT
AS
BEGIN
    BEGIN TRY
        DECLARE @TrangThaiVe NVARCHAR(50);
        DECLARE @NgayGioDi DATETIME;

        -- Lấy trạng thái vé và giờ cất cánh
        SELECT @TrangThaiVe = v.TrangThai, @NgayGioDi = cb.NgayGioDi
        FROM VE v
        JOIN CHUYENBAY cb ON v.MaCB = cb.MaCB
        WHERE v.MaVe = @MaVe;

        IF @@ROWCOUNT = 0
        BEGIN
            SET @ThongBao = N'Vé không tồn tại!';
            RETURN 1;
        END

        IF @TrangThaiVe = N'Đã hủy'
        BEGIN
            SET @ThongBao = N'Vé này đã bị hủy trước đó.';
            RETURN 1;
        END

        IF DATEDIFF(HOUR, GETDATE(), @NgayGioDi) < 24
        BEGIN
            SET @ThongBao = N'Chỉ được phép hủy vé trước giờ bay 24 tiếng. Quá hạn hủy!';
            RETURN 1;
        END

        SET @ThongBao = N'Vé hợp lệ. Có thể tiến hành thủ tục hủy vé.';
        RETURN 0;

    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
        RETURN 1;
    END CATCH
END;
GO
