use master
drop database QuanLyDatVeMayBay_06

create database QuanLyDatVeMayBay_06
use QuanLyDatVeMayBay_06

-- Bảng 1: Sân bay
create table SANBAY (
	MaSB varchar(10) primary key,
	TenSB nvarchar(100) not null,
	ThanhPho nvarchar(100) not null,
	QuocGia nvarchar(100) not null
)

-- Bảng 2: Tuyến bay
create table TUYENBAY (
	MaTuyen varchar(20) primary key,
	MaSBDi varchar(10) not null,
	MaSBDen varchar(10) not null,
	constraint FK_TUYENBAY_SBDi foreign key (MaSBDi) references SANBAY(MaSB),
	constraint FK_TUYENBAY_SBDen foreign key(MaSBDen) references SANBAY(MaSB),
	-- Constraint: Sân bay đi và sân bay đến ko đc trùng nhau
	constraint CHK_TuyenBay_KhacSanBay check (MaSBDi <> MaSBDen)
)

-- Bảng 3: Máy bay
create table MAYBAY (
	MaMB varchar(20) primary key,
	TenMB nvarchar(100) not null,
	TongSoGhe int not null,
	-- Constraint: Số ghế phải > 0
	constraint CHK_MayBay_TongSoGhe check (TongSoGhe > 0)
)

-- Bảng 4: Chuyến bay
create table CHUYENBAY (
	MaCB varchar(20) primary key,
	MaTuyen varchar(20) not null,
	MaMB varchar(20) not null,
	NgayGioDi datetime not null,
	NgayGioDen datetime not null,
	GiaVeCoBan decimal(18,2) not null,
	SoGheTrong int not null,
	TrangThai nvarchar(50) not null,
	constraint FK_CHUYENBAY_TUYENBAY foreign key (MaTuyen) references TUYENBAY(MaTuyen),
	constraint FK_CHUYENBAY_MAYBAY foreign key (MaMB) references MAYBAY(MaMB),
	--
	constraint CHK_ChuyenBay_ThoiGian check (NgayGioDi < NgayGioDen),
	constraint CHK_ChuyenBay_GiaVe check (GiaVeCoBan > 0),
	constraint CHK_ChuyenBay_SoGheTrong check (SoGheTrong >= 0),
	constraint CHK_ChuyenBay_TrangThai check (TrangThai in (N'Sắp bay', N'Đang bay', N'Đã hạ cánh', N'Đã hủy'))
)

-- Bảng 5: Khách hàng 
create table KHACHHANG(
	MaKH int identity(1,1) primary key,
	HoTen nvarchar(100) not null,
	Email varchar(100),
	SoHoChieu varchar(20) unique not null,
	QuocGiaCap nvarchar(100) not null,
	NgayHetHanPassport date not null
)

-- Bảng 6: SDT_KHACHHANG (thuộc tính đa trị tách bảng)
create table SDT_KHACHHANG (
	MaKH int not null,
	SoDienThoai varchar(20) not null,
	primary key (MaKH, SoDienThoai),
	constraint FK_SDT_KHACHHANG foreign key (MaKH) references KHACHHANG(MaKH) on delete cascade
)

-- Bảng 7: Nhân viên
create table NHANVIEN (
	MaNV varchar(20) primary key,
	HoTen nvarchar(100) not null,
	VaiTro nvarchar(50) not null,
	constraint CHK_NhanVien_VaiTro check (VaiTro in (N'Admin', N'Bán vé', N'Kế toán'))
)

-- Bảng 8: Vé
create table VE (
	MaVe int identity(1,1) primary key,
	MaCB varchar(20) not null,
	MaKH int not null,
	MaNV varchar(20),
	SoGhe varchar(10) not null,
	HangGhe nvarchar(50) not null,
	GiaTien decimal(18,2) not null,
	NgayDat datetime default getdate(),
	TrangThai nvarchar(50) not null,
	constraint FK_VE_CHUYENBAY foreign key (MaCB) references CHUYENBAY(MaCB),
	constraint FK_VE_KHACHHANG foreign key (MaKH) references KHACHHANG(MaKH),
	constraint FK_VE_NHANVIEN foreign key (MaNV) references NHANVIEN(MaNV),
	-- 
	constraint UQ_Ve_SoGhe unique (MaCB, SoGhe),
	-- 
	constraint CHK_Ve_HangGhe check (HangGhe in (N'Phổ thông', N'Thương gia')),
	constraint CHK_Ve_GiaTien check (GiaTien >= 0),
	constraint CHK_Ve_TrangThai check (TrangThai in (N'Chưa thanh toán', N'Đã thanh toán', N'Đã hủy'))
)

-- Bảng 9
create table THANHTOAN (
	LanTT int not null,
	MaVe int not null,
	SoTien decimal(18,2) not null,
	NgayTT datetime default getdate(),
	PhuongThuc nvarchar(50) not null,
	primary key (LanTT, MaVe),
	constraint FK_THANHTOAN_VE foreign key (MaVe) references VE(MaVe) on delete cascade,
	constraint CHK_ThanhToan_SoTien check (SoTien > 0),
	constraint CHK_ThanhToan_PhuongThuc check (PhuongThuc in (N'Tiền mặt', N'Chuyển khoản', N'Thẻ tín dụng'))
)