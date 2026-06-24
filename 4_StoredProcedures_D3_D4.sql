USE QuanLyDatVeMayBay_06;
GO

-- =====================================================================
-- DẠNG 3: STORED PROCEDURE SỬ DỤNG BẢNG TẠM VÀ BẢNG BIẾN
-- =====================================================================

-- 6. sp_TopKhachHangVIP: Sử dụng Bảng Tạm cục bộ (#Temp)
-- Phân tích và trả về Top N khách hàng chi tiêu nhiều nhất
CREATE PROCEDURE sp_TopKhachHangVIP
    @TopN INT
AS
BEGIN
    BEGIN TRY
        -- Tạo bảng tạm để lưu trữ dữ liệu tính toán
        CREATE TABLE #TopKH (
            MaKH INT,
            HoTen NVARCHAR(100),
            TongChiTieu DECIMAL(18,2),
            XepLoai NVARCHAR(50)
        );

        -- Đổ dữ liệu vào bảng tạm
        INSERT INTO #TopKH (MaKH, HoTen, TongChiTieu)
        SELECT kh.MaKH, kh.HoTen, ISNULL(SUM(tt.SoTien), 0)
        FROM KHACHHANG kh
        JOIN VE v ON kh.MaKH = v.MaKH
        JOIN THANHTOAN tt ON v.MaVe = tt.MaVe
        WHERE v.TrangThai = N'Đã thanh toán'
        GROUP BY kh.MaKH, kh.HoTen;

        -- Cập nhật phân loại (XepLoai) trực tiếp trên bảng tạm
        UPDATE #TopKH
        SET XepLoai = CASE 
            WHEN TongChiTieu > 50000000 THEN N'Kim Cương'
            WHEN TongChiTieu > 20000000 THEN N'Bạch Kim'
            WHEN TongChiTieu > 10000000 THEN N'Vàng'
            ELSE N'Bạc'
        END;

        -- Lấy ra kết quả trả về cho người dùng
        SELECT TOP (@TopN) * FROM #TopKH ORDER BY TongChiTieu DESC;

        -- Xóa bảng tạm (Thực ra SQL Server sẽ tự xóa khi kết thúc SP, nhưng viết ra thể hiện sự cẩn thận)
        DROP TABLE #TopKH;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO

-- 7. sp_DoanhThuTheoTuyen: Sử dụng Biến Bảng (@TableVariable)
CREATE PROCEDURE sp_DoanhThuTheoTuyen
AS
BEGIN
    BEGIN TRY
        -- Khai báo biến bảng (Table Variable)
        DECLARE @tblDoanhThu TABLE (
            MaTuyen VARCHAR(20),
            TongTien DECIMAL(18,2),
            SoChuyenBay INT
        );

        -- Đổ dữ liệu tính toán vào biến bảng
        INSERT INTO @tblDoanhThu (MaTuyen, TongTien, SoChuyenBay)
        SELECT cb.MaTuyen, ISNULL(SUM(tt.SoTien), 0), COUNT(DISTINCT cb.MaCB)
        FROM CHUYENBAY cb
        LEFT JOIN VE v ON cb.MaCB = v.MaCB AND v.TrangThai = N'Đã thanh toán'
        LEFT JOIN THANHTOAN tt ON v.MaVe = tt.MaVe
        GROUP BY cb.MaTuyen;

        -- Trả về kết quả
        SELECT tb.MaTuyen, sb1.TenSB AS SanBayDi, sb2.TenSB AS SanBayDen, 
               dt.SoChuyenBay, dt.TongTien
        FROM @tblDoanhThu dt
        JOIN TUYENBAY tb ON dt.MaTuyen = tb.MaTuyen
        JOIN SANBAY sb1 ON tb.MaSBDi = sb1.MaSB
        JOIN SANBAY sb2 ON tb.MaSBDen = sb2.MaSB
        ORDER BY dt.TongTien DESC;
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
    END CATCH
END;
GO


-- =====================================================================
-- DẠNG 4: STORED PROCEDURE SỬ DỤNG CURSOR
-- =====================================================================

-- 8. sp_DongBoTrangThaiChuyenBay: Sử dụng Cursor duyệt qua các chuyến bay
CREATE PROCEDURE sp_DongBoTrangThaiChuyenBay
AS
BEGIN
    BEGIN TRY
        DECLARE @MaCB VARCHAR(20);
        DECLARE @NgayGioDi DATETIME;
        DECLARE @NgayGioDen DATETIME;
        DECLARE @TrangThaiHienTai NVARCHAR(50);
        DECLARE @SoChuyenDaCapNhat INT = 0;

        -- Khai báo Cursor lấy các chuyến bay chưa hoàn thành
        DECLARE cur_ChuyenBay CURSOR FOR
        SELECT MaCB, NgayGioDi, NgayGioDen, TrangThai
        FROM CHUYENBAY
        WHERE TrangThai IN (N'Sắp bay', N'Đang bay');

        OPEN cur_ChuyenBay;
        FETCH NEXT FROM cur_ChuyenBay INTO @MaCB, @NgayGioDi, @NgayGioDen, @TrangThaiHienTai;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            DECLARE @TrangThaiMoi NVARCHAR(50) = @TrangThaiHienTai;
            DECLARE @HienTai DATETIME = GETDATE();

            -- Logic xác định trạng thái
            IF @HienTai >= @NgayGioDen
                SET @TrangThaiMoi = N'Đã hạ cánh';
            ELSE IF @HienTai >= @NgayGioDi AND @HienTai < @NgayGioDen
                SET @TrangThaiMoi = N'Đang bay';

            -- Nếu có sự thay đổi, tiến hành Update
            IF @TrangThaiMoi <> @TrangThaiHienTai
            BEGIN
                UPDATE CHUYENBAY
                SET TrangThai = @TrangThaiMoi
                WHERE CURRENT OF cur_ChuyenBay; -- Cập nhật dòng hiện tại của Cursor (Nhanh và chuẩn xác)

                SET @SoChuyenDaCapNhat = @SoChuyenDaCapNhat + 1;
            END

            FETCH NEXT FROM cur_ChuyenBay INTO @MaCB, @NgayGioDi, @NgayGioDen, @TrangThaiHienTai;
        END

        CLOSE cur_ChuyenBay;
        DEALLOCATE cur_ChuyenBay;

        PRINT N'Đã đồng bộ trạng thái cho ' + CAST(@SoChuyenDaCapNhat AS VARCHAR) + N' chuyến bay.';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMessage NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMessage, 16, 1);
        
        -- Dọn dẹp Cursor nếu có lỗi xảy ra để tránh tràn bộ nhớ
        IF CURSOR_STATUS('global', 'cur_ChuyenBay') >= -1
        BEGIN
            CLOSE cur_ChuyenBay;
            DEALLOCATE cur_ChuyenBay;
        END
    END CATCH
END;
GO

-- 9. sp_HuyVeQuaHan: Dùng Cursor hủy tự động các vé chưa thanh toán quá 24h
CREATE PROCEDURE sp_HuyVeQuaHan
AS
BEGIN
    BEGIN TRY
        DECLARE @MaVe INT;
        DECLARE @MaCB VARCHAR(20);
        DECLARE @SoVeDaHuy INT = 0;

        -- Khai báo Cursor lấy các vé chưa thanh toán và đã quá 24h kể từ lúc đặt
        DECLARE cur_HuyVe CURSOR FOR
        SELECT MaVe, MaCB
        FROM VE
        WHERE TrangThai = N'Chưa thanh toán' 
          AND DATEDIFF(HOUR, NgayDat, GETDATE()) > 24;

        OPEN cur_HuyVe;
        FETCH NEXT FROM cur_HuyVe INTO @MaVe, @MaCB;

        WHILE @@FETCH_STATUS = 0
        BEGIN
            -- 1. Đổi trạng thái vé thành 'Đã hủy'
            UPDATE VE 
            SET TrangThai = N'Đã hủy' 
            WHERE CURRENT OF cur_HuyVe;

            -- 2. Cộng trả lại 1 ghế trống cho chuyến bay
            UPDATE CHUYENBAY
            SET SoGheTrong = SoGheTrong + 1
            WHERE MaCB = @MaCB;

            SET @SoVeDaHuy = @SoVeDaHuy + 1;

            FETCH NEXT FROM cur_HuyVe INTO @MaVe, @MaCB;
        END

        CLOSE cur_HuyVe;
        DEALLOCATE cur_HuyVe;

        PRINT N'Hệ thống đã tự động hủy ' + CAST(@SoVeDaHuy AS VARCHAR) + N' vé quá hạn thanh toán.';
    END TRY
    BEGIN CATCH
        DECLARE @ErrorMsg NVARCHAR(4000) = ERROR_MESSAGE();
        RAISERROR(@ErrorMsg, 16, 1);
        
        IF CURSOR_STATUS('global', 'cur_HuyVe') >= -1
        BEGIN
            CLOSE cur_HuyVe;
            DEALLOCATE cur_HuyVe;
        END
    END CATCH
END;
GO
