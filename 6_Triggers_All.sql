USE QuanLyDatVeMayBay_06;
GO

-- =====================================================================
-- GIAI ĐOẠN 3: LẬP TRÌNH 9 TRIGGERS (BẢO VỆ DỮ LIỆU)
-- =====================================================================

-- ==========================================
-- DẠNG 1: AFTER INSERT TRIGGERS
-- ==========================================
-- 1. trg_DatVe: Tự động trừ ghế trống khi có người đặt vé thành công
CREATE TRIGGER trg_DatVe
ON VE
AFTER INSERT
AS
BEGIN
    -- Chỉ trừ ghế nếu vé mới không ở trạng thái 'Đã hủy'
    UPDATE CHUYENBAY
    SET SoGheTrong = SoGheTrong - 1
    FROM CHUYENBAY cb
    JOIN inserted i ON cb.MaCB = i.MaCB
    WHERE i.TrangThai <> N'Đã hủy';
END;
GO

-- 2. trg_ThanhToan: Khi có người INSERT vào bảng THANHTOAN, tự động đổi trạng thái Vé
CREATE TRIGGER trg_ThanhToan
ON THANHTOAN
AFTER INSERT
AS
BEGIN
    UPDATE VE
    SET TrangThai = N'Đã thanh toán'
    FROM VE v
    JOIN inserted i ON v.MaVe = i.MaVe;
END;
GO

-- 3. trg_KiemTraLichBay: Ngăn chặn thêm chuyến bay trong quá khứ
CREATE TRIGGER trg_KiemTraLichBay
ON CHUYENBAY
AFTER INSERT
AS
BEGIN
    IF EXISTS (SELECT 1 FROM inserted WHERE NgayGioDi < GETDATE())
    BEGIN
        RAISERROR(N'Lỗi Trigger: Không thể tạo chuyến bay với ngày khởi hành trong quá khứ!', 16, 1);
        ROLLBACK TRANSACTION;
    END
END;
GO

-- ==========================================
-- DẠNG 2: AFTER UPDATE TRIGGERS
-- ==========================================
-- 4. trg_HoanVe: Tự động trả lại ghế khi vé bị đổi trạng thái thành 'Đã hủy'
CREATE TRIGGER trg_HoanVe
ON VE
AFTER UPDATE
AS
BEGIN
    -- Kiểm tra nếu Trạng thái vé bị đổi sang 'Đã hủy' (mà dữ liệu cũ không phải 'Đã hủy')
    IF UPDATE(TrangThai)
    BEGIN
        UPDATE CHUYENBAY
        SET SoGheTrong = SoGheTrong + 1
        FROM CHUYENBAY cb
        JOIN inserted i ON cb.MaCB = i.MaCB
        JOIN deleted d ON i.MaVe = d.MaVe
        WHERE i.TrangThai = N'Đã hủy' AND d.TrangThai <> N'Đã hủy';
    END
END;
GO

-- 5. trg_CapNhatChuyenBay: Ràng buộc thời gian bay (Giờ đến phải sau Giờ đi ít nhất 30 phút)
CREATE TRIGGER trg_CapNhatChuyenBay
ON CHUYENBAY
AFTER UPDATE
AS
BEGIN
    IF UPDATE(NgayGioDi) OR UPDATE(NgayGioDen)
    BEGIN
        IF EXISTS (
            SELECT 1 
            FROM inserted 
            WHERE DATEDIFF(MINUTE, NgayGioDi, NgayGioDen) < 30
        )
        BEGIN
            RAISERROR(N'Lỗi Trigger: Khoảng cách giữa Giờ đi và Giờ đến phải ít nhất 30 phút!', 16, 1);
            ROLLBACK TRANSACTION;
        END
    END
END;
GO

-- 6. Tạo bảng LOG để chuẩn bị cho Trigger 6 (Lưu lịch sử sửa giá)
CREATE TABLE LOG_GIAVE (
    ID INT IDENTITY(1,1) PRIMARY KEY,
    MaCB VARCHAR(20),
    GiaVeCu DECIMAL(18,2),
    GiaVeMoi DECIMAL(18,2),
    NgayCapNhat DATETIME DEFAULT GETDATE(),
    NguoiCapNhat NVARCHAR(50) DEFAULT SYSTEM_USER
);
GO

-- trg_LogCapNhatGiaVe: Lưu lại lịch sử khi giá vé bị thay đổi
CREATE TRIGGER trg_LogCapNhatGiaVe
ON CHUYENBAY
AFTER UPDATE
AS
BEGIN
    IF UPDATE(GiaVeCoBan)
    BEGIN
        INSERT INTO LOG_GIAVE (MaCB, GiaVeCu, GiaVeMoi)
        SELECT i.MaCB, d.GiaVeCoBan, i.GiaVeCoBan
        FROM inserted i
        JOIN deleted d ON i.MaCB = d.MaCB
        WHERE i.GiaVeCoBan <> d.GiaVeCoBan; -- Chỉ lưu log nếu giá thực sự thay đổi
    END
END;
GO


-- ==========================================
-- DẠNG 3: INSTEAD OF DELETE TRIGGERS
-- ==========================================
-- 7. trg_ChongXoaSanBay: Ngăn xóa Sân bay nếu đã được sử dụng trong Tuyến bay
CREATE TRIGGER trg_ChongXoaSanBay
ON SANBAY
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM TUYENBAY tb
        JOIN deleted d ON tb.MaSBDi = d.MaSB OR tb.MaSBDen = d.MaSB
    )
    BEGIN
        RAISERROR(N'Lỗi Trigger: Sân bay này đang được sử dụng trong Tuyến bay. Tuyệt đối không thể xóa!', 16, 1);
    END
    ELSE
    BEGIN
        -- Nếu không vướng dữ liệu khóa ngoại, tiến hành xóa bình thường
        DELETE FROM SANBAY WHERE MaSB IN (SELECT MaSB FROM deleted);
    END
END;
GO

-- 8. trg_ChongXoaChuyenBay: Thay vì Xóa hẳn chuyến bay, chỉ đổi trạng thái thành 'Đã hủy' nếu đã có khách đặt
CREATE TRIGGER trg_ChongXoaChuyenBay
ON CHUYENBAY
INSTEAD OF DELETE
AS
BEGIN
    -- Nếu chuyến bay đã có vé được đặt, cấm xóa vĩnh viễn (Chỉ đổi trạng thái)
    IF EXISTS (SELECT 1 FROM VE v JOIN deleted d ON v.MaCB = d.MaCB)
    BEGIN
        PRINT N'Trigger cảnh báo: Chuyến bay đã có khách đặt vé. Hệ thống tự động chuyển trạng thái thành Đã hủy thay vì xóa vĩnh viễn khỏi CSDL!';
        UPDATE CHUYENBAY
        SET TrangThai = N'Đã hủy'
        WHERE MaCB IN (SELECT MaCB FROM deleted);
    END
    ELSE
    BEGIN
        -- Nếu chưa có ai đặt vé, cho phép xóa
        DELETE FROM CHUYENBAY WHERE MaCB IN (SELECT MaCB FROM deleted);
    END
END;
GO

-- 9. trg_ChongXoaKhachHang: Cấm xóa khách hàng đã từng giao dịch
CREATE TRIGGER trg_ChongXoaKhachHang
ON KHACHHANG
INSTEAD OF DELETE
AS
BEGIN
    IF EXISTS (
        SELECT 1 
        FROM VE v
        JOIN deleted d ON v.MaKH = d.MaKH
    )
    BEGIN
        RAISERROR(N'Lỗi Trigger: Khách hàng này đã có giao dịch mua vé. Không thể xóa để bảo toàn dữ liệu doanh thu!', 16, 1);
    END
    ELSE
    BEGIN
        -- Cho phép xóa nếu là khách vãng lai, chưa từng mua vé
        -- Nhớ xóa số điện thoại bên bảng con trước để tránh lỗi FK
        DELETE FROM SDT_KHACHHANG WHERE MaKH IN (SELECT MaKH FROM deleted);
        DELETE FROM KHACHHANG WHERE MaKH IN (SELECT MaKH FROM deleted);
    END
END;
GO
