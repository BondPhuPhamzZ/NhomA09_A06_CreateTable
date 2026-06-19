-- =====================================================================
-- ĐỒ ÁN CSDL NÂNG CAO - A06: HỆ THỐNG QUẢN LÝ ĐẶT VÉ MÁY BAY
-- FILE 1: KHỞI TẠO CƠ SỞ DỮ LIỆU & BẢNG (DDL)
-- =====================================================================

-- 1. Tạo Database
CREATE DATABASE QuanLyDatVeMayBay_A06;
GO

USE QuanLyDatVeMayBay_A06;
GO

-- =====================================================================
-- 2. TẠO BẢNG (Tuân thủ thứ tự để không bị lỗi Khóa Ngoại)
-- =====================================================================

-- Bảng 1: SANBAY
CREATE TABLE SANBAY (
    MaSB VARCHAR(10) PRIMARY KEY,
    TenSB NVARCHAR(100) NOT NULL,
    ThanhPho NVARCHAR(100) NOT NULL,
    QuocGia NVARCHAR(100) NOT NULL
);
GO

-- Bảng 2: TUYENBAY
CREATE TABLE TUYENBAY (
    MaTuyen VARCHAR(20) PRIMARY KEY,
    MaSBDi VARCHAR(10) NOT NULL,
    MaSBDen VARCHAR(10) NOT NULL,
    CONSTRAINT FK_TUYENBAY_SBDi FOREIGN KEY (MaSBDi) REFERENCES SANBAY(MaSB),
    CONSTRAINT FK_TUYENBAY_SBDen FOREIGN KEY (MaSBDen) REFERENCES SANBAY(MaSB),
    -- Ràng buộc: Sân bay đi và đến không được trùng nhau
    CONSTRAINT CHK_TuyenBay_KhacSanBay CHECK (MaSBDi <> MaSBDen)
);
GO

-- Bảng 3: MAYBAY
CREATE TABLE MAYBAY (
    MaMB VARCHAR(20) PRIMARY KEY,
    TenMB NVARCHAR(100) NOT NULL,
    TongSoGhe INT NOT NULL,
    -- Ràng buộc: Số ghế phải lớn hơn 0
    CONSTRAINT CHK_MayBay_TongSoGhe CHECK (TongSoGhe > 0)
);
GO

-- Bảng 4: CHUYENBAY
CREATE TABLE CHUYENBAY (
    MaCB VARCHAR(20) PRIMARY KEY,
    MaTuyen VARCHAR(20) NOT NULL,
    MaMB VARCHAR(20) NOT NULL,
    NgayGioDi DATETIME NOT NULL,
    NgayGioDen DATETIME NOT NULL,
    GiaVeCoBan DECIMAL(18,2) NOT NULL,
    SoGheTrong INT NOT NULL,
    TrangThai NVARCHAR(50) NOT NULL,
    CONSTRAINT FK_CHUYENBAY_TUYENBAY FOREIGN KEY (MaTuyen) REFERENCES TUYENBAY(MaTuyen),
    CONSTRAINT FK_CHUYENBAY_MAYBAY FOREIGN KEY (MaMB) REFERENCES MAYBAY(MaMB),
    -- Ràng buộc toàn vẹn:
    CONSTRAINT CHK_ChuyenBay_ThoiGian CHECK (NgayGioDi < NgayGioDen),
    CONSTRAINT CHK_ChuyenBay_GiaVe CHECK (GiaVeCoBan > 0),
    CONSTRAINT CHK_ChuyenBay_SoGheTrong CHECK (SoGheTrong >= 0),
    CONSTRAINT CHK_ChuyenBay_TrangThai CHECK (TrangThai IN (N'Sắp bay', N'Đang bay', N'Đã hạ cánh', N'Đã hủy'))
);
GO

-- Bảng 5: KHACHHANG
CREATE TABLE KHACHHANG (
    MaKH INT IDENTITY(1,1) PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    Email VARCHAR(100),
    SoHoChieu VARCHAR(20) UNIQUE NOT NULL,
    QuocGiaCap NVARCHAR(100) NOT NULL,
    NgayHetHanPassport DATE NOT NULL
);
GO

-- Bảng 6: SDT_KHACHHANG (Thuộc tính đa trị tách bảng)
CREATE TABLE SDT_KHACHHANG (
    MaKH INT NOT NULL,
    SoDienThoai VARCHAR(20) NOT NULL,
    PRIMARY KEY (MaKH, SoDienThoai),
    CONSTRAINT FK_SDT_KHACHHANG FOREIGN KEY (MaKH) REFERENCES KHACHHANG(MaKH) ON DELETE CASCADE
);
GO

-- Bảng 7: NHANVIEN
CREATE TABLE NHANVIEN (
    MaNV VARCHAR(20) PRIMARY KEY,
    HoTen NVARCHAR(100) NOT NULL,
    VaiTro NVARCHAR(50) NOT NULL,
    CONSTRAINT CHK_NhanVien_VaiTro CHECK (VaiTro IN (N'Admin', N'Bán vé', N'Kế toán'))
);
GO

-- Bảng 8: VE
CREATE TABLE VE (
    MaVe INT IDENTITY(1,1) PRIMARY KEY,
    MaCB VARCHAR(20) NOT NULL,
    MaKH INT NOT NULL,
    MaNV VARCHAR(20),
    SoGhe VARCHAR(10) NOT NULL,
    HangGhe NVARCHAR(50) NOT NULL,
    GiaTien DECIMAL(18,2) NOT NULL,
    NgayDat DATETIME DEFAULT GETDATE(),
    TrangThai NVARCHAR(50) NOT NULL,
    CONSTRAINT FK_VE_CHUYENBAY FOREIGN KEY (MaCB) REFERENCES CHUYENBAY(MaCB),
    CONSTRAINT FK_VE_KHACHHANG FOREIGN KEY (MaKH) REFERENCES KHACHHANG(MaKH),
    CONSTRAINT FK_VE_NHANVIEN FOREIGN KEY (MaNV) REFERENCES NHANVIEN(MaNV),
    -- Ràng buộc chống trùng chỗ ngồi trên cùng 1 chuyến bay
    CONSTRAINT UQ_Ve_SoGhe UNIQUE (MaCB, SoGhe),
    -- Các ràng buộc khác
    CONSTRAINT CHK_Ve_HangGhe CHECK (HangGhe IN (N'Phổ thông', N'Thương gia')),
    CONSTRAINT CHK_Ve_GiaTien CHECK (GiaTien >= 0),
    CONSTRAINT CHK_Ve_TrangThai CHECK (TrangThai IN (N'Chưa thanh toán', N'Đã thanh toán', N'Đã hủy'))
);
GO

-- Bảng 9: THANHTOAN (Thực thể yếu)
CREATE TABLE THANHTOAN (
    LanTT INT NOT NULL,
    MaVe INT NOT NULL,
    SoTien DECIMAL(18,2) NOT NULL,
    NgayTT DATETIME DEFAULT GETDATE(),
    PhuongThuc NVARCHAR(50) NOT NULL,
    PRIMARY KEY (LanTT, MaVe),
    CONSTRAINT FK_THANHTOAN_VE FOREIGN KEY (MaVe) REFERENCES VE(MaVe) ON DELETE CASCADE,
    CONSTRAINT CHK_ThanhToan_SoTien CHECK (SoTien > 0),
    CONSTRAINT CHK_ThanhToan_PhuongThuc CHECK (PhuongThuc IN (N'Tiền mặt', N'Chuyển khoản', N'Thẻ tín dụng'))
);
GO

PRINT N'Khởi tạo Cơ sở dữ liệu và 9 Bảng thành công!';
