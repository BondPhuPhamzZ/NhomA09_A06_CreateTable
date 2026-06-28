USE QuanLyDatVeMayBay_06;
GO

-- =========================================================================================
-- KỊCH BẢN TEST DÀNH RIÊNG CHO ĐỒ ÁN MÔN CSDL NÂNG CAO
-- Lưu ý: Bạn bôi đen từng khối (từ dòng chú thích đến chữ GO) rồi bấm F5 để xem kết quả.
-- =========================================================================================

-- -----------------------------------------------------------------------------------------
-- PHẦN 1: TEST STORED PROCEDURES (Biến thủ tục)
-- -----------------------------------------------------------------------------------------

-- 1. Test Dạng 1: Nhập liệu an toàn (SP Thêm Chuyến Bay)
-- Kịch bản: Cố tình nhập trùng mã máy bay hoặc sai lịch bay để test chức năng văng lỗi
BEGIN TRAN;
BEGIN TRY
    EXEC sp_ThemChuyenBay 
        @MaCB = 'VN0001', -- (Lỗi: Mã này đã có sẵn)
        @MaTuyen = 'TB_BKK_VCA', 
        @MaMB = 'VN-A322', 
        @NgayGioDi = '2026-06-24', 
        @NgayGioDen = '2026-06-28', 
        @GiaVeCoBan = 20000000;
END TRY
BEGIN CATCH
    PRINT N'Lỗi bắt được từ SP Dạng 1: ' + ERROR_MESSAGE();
END CATCH
ROLLBACK;
GO


-- 2. Test Dạng 2: SP có Output Parameter
-- Kịch bản: Tính doanh thu của 1 chuyến bay và in ra màn hình
DECLARE @TongTienTraVe DECIMAL(18,2);
-- (Chú ý: thay mã VN... bằng mã chuyến bay thực tế trong máy bạn nếu bị lỗi null)
DECLARE @MaCBTam VARCHAR(20) = (SELECT TOP 1 MaCB FROM CHUYENBAY);
EXEC sp_TinhDoanhThuCB @MaCB = @MaCBTam, @TongDoanhThu = @TongTienTraVe OUTPUT;
PRINT N'Doanh thu của chuyến bay ' + @MaCBTam + N' là: ' + CAST(@TongTienTraVe AS VARCHAR);
GO


-- 3. Test Dạng 3: Bảng tạm (#TempTable)
-- Kịch bản: Bảng tạm sẽ tính toán ngầm và in ra TOP 3 khách hàng giàu nhất
EXEC sp_TopKhachHangVip @TopN = 3;
GO


-- 4. Test Dạng 5: Nghiệp vụ Lõi (Bọc TRANSACTION để chống rác dữ liệu)
-- Kịch bản: Đặt vé máy bay (sẽ trừ số ghế trống, insert vào bảng VE)
BEGIN TRAN;
-- Tìm chuyến bay còn chỗ để test
DECLARE @MaCBDemo VARCHAR(20) = (SELECT TOP 1 MaCB FROM CHUYENBAY WHERE SoGheTrong > 0);
SELECT SoGheTrong AS 'Ghế TRƯỚC khi đặt' FROM CHUYENBAY WHERE MaCB = @MaCBDemo;

EXEC sp_DatVe 
    @MaCB = @MaCBDemo, 
    @MaKH = 1, 
    @MaNV = 'NV001', 
    @SoGhe = 'TEST01', 
    @HangGhe = N'Thương gia';

SELECT SoGheTrong AS 'Ghế SAU khi đặt (Bị trừ 1)' FROM CHUYENBAY WHERE MaCB = @MaCBDemo;
ROLLBACK; -- (Khôi phục lại DB như cũ)
GO


-- -----------------------------------------------------------------------------------------
-- PHẦN 2: TEST TRIGGERS (Trình kích hoạt ngầm)
-- -----------------------------------------------------------------------------------------

-- 1. Test Trigger chặn tạo chuyến bay quá khứ (AFTER INSERT)
-- Kịch bản: Thử thêm 1 chuyến bay của năm 2020 (Sẽ báo lỗi đỏ tươi!)
/* 
-- (Bôi đen đoạn INSERT này và F5 để ra lỗi màu Đỏ chứng minh cho giáo viên)
INSERT INTO CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
VALUES ('TEST_ERROR', 'TB_SGN_HAN', 'VN-A899', '2020-01-01', '2020-01-01', 1000000, 100, N'Sắp bay');
*/


-- 2. Test Trigger bảo vệ dữ liệu vĩnh viễn (INSTEAD OF DELETE)
-- Kịch bản: Kẻ gian muốn xóa toàn bộ khách hàng
/* 
-- (Bôi đen và F5, dữ liệu không hề suy suyển, thông báo đỏ sẽ chửi kẻ gian)
DELETE FROM KHACHHANG WHERE MaKH = 1;
*/


-- -----------------------------------------------------------------------------------------
-- PHẦN 3: TEST CURSORS (Con trỏ duyệt dữ liệu)
-- -----------------------------------------------------------------------------------------

-- 1. Test Cursor đồng bộ trạng thái
-- Kịch bản: Cập nhật đồng loạt các chuyến bay đã tới giờ hạ cánh
SELECT MaCB, NgayGioDen, TrangThai AS 'Trạng Thái Trước Đồng Bộ' 
FROM CHUYENBAY WHERE TrangThai = N'Sắp bay' OR TrangThai = N'Đang bay';

EXEC sp_DongBoTrangThaiChuyenBay;

SELECT MaCB, NgayGioDen, TrangThai AS 'Trạng Thái Sau Đồng Bộ' 
FROM CHUYENBAY;
GO
