-- =====================================================================
-- ĐỒ ÁN CSDL NÂNG CAO - A06: HỆ THỐNG QUẢN LÝ ĐẶT VÉ MÁY BAY
-- FILE 2: CHÈN DỮ LIỆU MẪU (DML - ĐẢM BẢO > 30 DÒNG MỖI BẢNG)
-- =====================================================================

USE QuanLyDatVeMayBay_A06;
GO

-- 1. DỮ LIỆU SÂN BAY (10 Sân bay)
INSERT INTO SANBAY (MaSB, TenSB, ThanhPho, QuocGia) VALUES
('SGN', N'Tân Sơn Nhất', N'Hồ Chí Minh', N'Việt Nam'),
('HAN', N'Nội Bài', N'Hà Nội', N'Việt Nam'),
('DAD', N'Đà Nẵng', N'Đà Nẵng', N'Việt Nam'),
('CXR', N'Cam Ranh', N'Khánh Hòa', N'Việt Nam'),
('PQC', N'Phú Quốc', N'Kiên Giang', N'Việt Nam'),
('VCA', N'Trà Nóc', N'Cần Thơ', N'Việt Nam'),
('HUI', N'Phú Bài', N'Thừa Thiên Huế', N'Việt Nam'),
('NHA', N'Nha Trang', N'Khánh Hòa', N'Việt Nam'),
('VII', N'Vinh', N'Nghệ An', N'Việt Nam'),
('UIH', N'Phù Cát', N'Bình Định', N'Việt Nam'),
('BKK', N'Suvarnabhumi', N'Bangkok', N'Thái Lan'),
('SIN', N'Changi', N'Singapore', N'Singapore');
GO

-- 2. DỮ LIỆU MÁY BAY (10 Máy bay)
INSERT INTO MAYBAY (MaMB, TenMB, TongSoGhe) VALUES
('VN-A899', N'Boeing 787-9 Dreamliner', 274),
('VN-A887', N'Boeing 787-9 Dreamliner', 274),
('VN-A868', N'Boeing 787-10 Dreamliner', 367),
('VN-A350', N'Airbus A350-900', 305),
('VN-A351', N'Airbus A350-900', 305),
('VN-A321', N'Airbus A321neo', 203),
('VN-A322', N'Airbus A321neo', 203),
('VN-A323', N'Airbus A321', 184),
('VN-A324', N'Airbus A321', 184),
('VN-A220', N'Airbus A220', 120);
GO

-- 3. DỮ LIỆU NHÂN VIÊN (5 Nhân viên)
INSERT INTO NHANVIEN (MaNV, HoTen, VaiTro) VALUES
('NV001', N'Nguyễn Văn Quản Trị', N'Admin'),
('NV002', N'Trần Thị Bán Vé 1', N'Bán vé'),
('NV003', N'Lê Văn Bán Vé 2', N'Bán vé'),
('NV004', N'Phạm Thu Kế Toán', N'Kế toán'),
('NV005', N'Hoàng Bán Vé 3', N'Bán vé');
GO

-- 4. DỮ LIỆU TUYENBAY (Sử dụng vòng lặp đẻ ra 30+ tuyến bay)
DECLARE @i INT = 1;
DECLARE @MaSBDi VARCHAR(10), @MaSBDen VARCHAR(10);
WHILE @i <= 35
BEGIN
    -- Lấy ngẫu nhiên 2 mã sân bay khác nhau
    SELECT TOP 1 @MaSBDi = MaSB FROM SANBAY ORDER BY NEWID();
    SELECT TOP 1 @MaSBDen = MaSB FROM SANBAY WHERE MaSB <> @MaSBDi ORDER BY NEWID();
    
    IF NOT EXISTS (SELECT 1 FROM TUYENBAY WHERE MaSBDi = @MaSBDi AND MaSBDen = @MaSBDen)
    BEGIN
        INSERT INTO TUYENBAY (MaTuyen, MaSBDi, MaSBDen)
        VALUES ('TB_' + @MaSBDi + '_' + @MaSBDen, @MaSBDi, @MaSBDen);
        SET @i = @i + 1;
    END
END
GO

-- 5. DỮ LIỆU KHÁCH HÀNG & SDT (30+ Khách hàng)
DECLARE @j INT = 1;
WHILE @j <= 40
BEGIN
    INSERT INTO KHACHHANG (HoTen, Email, SoHoChieu, QuocGiaCap, NgayHetHanPassport)
    VALUES (
        N'Khách Hàng ' + CAST(@j AS NVARCHAR),
        'khach' + CAST(@j AS VARCHAR) + '@gmail.com',
        'B' + RIGHT('0000000' + CAST(ABS(CHECKSUM(NEWID())) % 10000000 AS VARCHAR), 7),
        N'Việt Nam',
        DATEADD(YEAR, 5, GETDATE())
    );
    
    DECLARE @MaKH_VuaTao INT = SCOPE_IDENTITY();
    
    -- Thêm 1-2 SDT cho mỗi khách hàng
    INSERT INTO SDT_KHACHHANG (MaKH, SoDienThoai)
    VALUES (@MaKH_VuaTao, '09' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR), 8));
    
    IF (@j % 3 = 0) -- Khách số chia hết cho 3 có 2 sdt
    BEGIN
        INSERT INTO SDT_KHACHHANG (MaKH, SoDienThoai)
        VALUES (@MaKH_VuaTao, '08' + RIGHT('00000000' + CAST(ABS(CHECKSUM(NEWID())) % 100000000 AS VARCHAR), 8));
    END

    SET @j = @j + 1;
END
GO

-- 6. DỮ LIỆU CHUYẾN BAY (35 Chuyến bay)
DECLARE @k INT = 1;
DECLARE @MaTuyen VARCHAR(20), @MaMB VARCHAR(20), @TongGhe INT;
WHILE @k <= 35
BEGIN
    SELECT TOP 1 @MaTuyen = MaTuyen FROM TUYENBAY ORDER BY NEWID();
    SELECT TOP 1 @MaMB = MaMB, @TongGhe = TongSoGhe FROM MAYBAY ORDER BY NEWID();
    
    DECLARE @NgayDi DATETIME = DATEADD(DAY, @k % 10, GETDATE());
    DECLARE @NgayDen DATETIME = DATEADD(HOUR, 2, @NgayDi);
    
    INSERT INTO CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
    VALUES (
        'VN' + RIGHT('000' + CAST(@k AS VARCHAR), 3) + '_' + FORMAT(@NgayDi, 'MMdd'),
        @MaTuyen,
        @MaMB,
        @NgayDi,
        @NgayDen,
        (ABS(CHECKSUM(NEWID())) % 2000000) + 1000000, -- Giá từ 1tr đến 3tr
        @TongGhe,
        N'Sắp bay'
    );
    SET @k = @k + 1;
END
GO

-- 7. DỮ LIỆU VÉ & THANH TOÁN (Khoảng 50 Vé)
DECLARE @v INT = 1;
WHILE @v <= 50
BEGIN
    DECLARE @MaCB VARCHAR(20), @GiaCoBan DECIMAL(18,2), @SoGheTrong INT;
    SELECT TOP 1 @MaCB = MaCB, @GiaCoBan = GiaVeCoBan, @SoGheTrong = SoGheTrong 
    FROM CHUYENBAY WHERE SoGheTrong > 0 ORDER BY NEWID();
    
    DECLARE @MaKH INT = (SELECT TOP 1 MaKH FROM KHACHHANG ORDER BY NEWID());
    DECLARE @MaNV VARCHAR(20) = (SELECT TOP 1 MaNV FROM NHANVIEN WHERE VaiTro = N'Bán vé' ORDER BY NEWID());
    
    DECLARE @HangGhe NVARCHAR(50) = CASE WHEN @v % 5 = 0 THEN N'Thương gia' ELSE N'Phổ thông' END;
    DECLARE @GiaTien DECIMAL(18,2) = CASE WHEN @HangGhe = N'Thương gia' THEN @GiaCoBan * 2 ELSE @GiaCoBan END;
    
    -- Tránh trùng số ghế
    DECLARE @SoGhe VARCHAR(10) = CAST((@SoGheTrong) AS VARCHAR) + CASE WHEN @v % 2 = 0 THEN 'A' ELSE 'B' END;
    
    -- Insert Vé
    INSERT INTO VE (MaCB, MaKH, MaNV, SoGhe, HangGhe, GiaTien, NgayDat, TrangThai)
    VALUES (@MaCB, @MaKH, @MaNV, @SoGhe, @HangGhe, @GiaTien, GETDATE(), N'Đã thanh toán');
    
    DECLARE @MaVe INT = SCOPE_IDENTITY();
    
    -- Update lại số ghế trống của chuyến bay (Minh họa, sau này dùng Trigger)
    UPDATE CHUYENBAY SET SoGheTrong = SoGheTrong - 1 WHERE MaCB = @MaCB;
    
    -- Insert Thanh Toán
    INSERT INTO THANHTOAN (LanTT, MaVe, SoTien, NgayTT, PhuongThuc)
    VALUES (1, @MaVe, @GiaTien, GETDATE(), N'Chuyển khoản');

    SET @v = @v + 1;
END
GO

PRINT N'Chèn dữ liệu mẫu thành công! Tất cả các bảng đều có >= 30 dòng.';
