use QuanLyDatVeMayBay_06
go

-- 1. Sân bay (10 Sân Bay)
insert into SANBAY(MaSB, TenSB, ThanhPho, QuocGia)
values
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
('SIN', N'Changi', N'Singapore', N'Singapore')

-- 2. Dữ liệu Máy Bay (10 Máy bay)
insert into MAYBAY(MaMB, TenMB, TongSoGhe)
values
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

-- 3. Dữ liệu Nhân Viên (5 Nhân Viên)
insert into NHANVIEN(MaNV, HoTen, VaiTro)
values
('NV001', N'Nguyễn Văn Quản Trị', N'Admin'),
('NV002', N'Trần Thị Bán Vé 1', N'Bán vé'),
('NV003', N'Lê Văn Bán Vé 2', N'Bán vé'),
('NV004', N'Phạm Thu Kế Toán', N'Kế toán'),
('NV005', N'Hoàng Bán Vé 3', N'Bán vé')

select * from SANBAY
select * from MAYBAY
select * from NHANVIEN

-- 4. Dữ liệu Tuyến Bay (30 Tuyến bay)
declare @i int = 1
declare @MaSBDi varchar(10), @MaSBDen varchar(10)
while @i <= 35
begin
	-- Lấy random 2 Mã Sân Bay != nhau
	select top 1 @MaSBDi = MaSB from SANBAY order by newid()
	select top 1 @MaSBDen = MaSB from SANBAY where MaSB <> @MaSBDi order by newid()

	if not exists (select 1 from TUYENBAY where MaSBDi = @MaSBDi and MaSBDen = @MaSBDen)
	begin
		insert into TUYENBAY (MaTuyen,MaSBDi, MaSBDen)
		values('TB_' + @MaSBDi + '_' + @MaSBDen, @MaSBDi, @MaSBDen)
		set @i = @i + 1
	end
end

select * from TUYENBAY

-- 5. Dữ liệu Khách hàng & SĐT (> 30 Khách hàng)
declare @j int = 1
while @j <= 40
begin
	insert into KHACHHANG (HoTen, Email, SoHoChieu, QuocGiaCap, NgayHetHanPassport)
	values (
		N'Khách hàng' + cast(@j as nvarchar),
		'khach' + cast(@j as varchar) +  '@gmail.com',
		'B' + right('0000000' + cast(abs(checksum(newid())) % 10000000 as varchar), 7),
		N'Việt Nam',
		dateadd(year, 5, getdate())
	)

	declare @MaKH_VuaTao int = scope_identity()

	-- Thêm 1-2 SDT cho mỗi khách hàng
	insert into SDT_KHACHHANG (MaKH, SoDienThoai)
	values
	(@MaKH_VuaTao, '09' + right('00000000' + cast(abs(checksum(newid())) % 100000000 as varchar), 8))

	-- Số khách % 3 == 0 sẽ có 2 sdt (cần xem lại)
	if (@j % 3 = 0) 
	begin
		insert into SDT_KHACHHANG (MaKH, SoDienThoai)
		values
		(@MaKH_VuaTao, '08' + RIGHT('00000000' + cast(abs(checksum(newid())) % 100000000 as varchar), 8))
	end

	set @j = @j + 1
end

select * from KHACHHANG

-- 6. Dữ liệu Chuyến Bay (35 chuyến)
declare @k int = 1
declare @MaTuyen varchar(20), @MaMB varchar(20), @TongGhe int
while @k <= 35
begin
	select top 1 @MaTuyen = MaTuyen from TUYENBAY order by newid()
	select top 1 @MaMB = MaMB, @TongGhe = TongSoGhe from MAYBAY order by newid()

	declare @NgayDi datetime = dateadd(day, @k % 10, getdate())
	declare @NgayDen datetime = dateadd(hour, 2, @NgayDi)

	insert into CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
	values
	(
		'VN' + right('000' + cast(@k as varchar), 3) + '_' + format(@NgayDi, 'MMdd'),
        @MaTuyen,
        @MaMB,
        @NgayDi,
        @NgayDen,
        (abs(checksum(newid())) % 2000000) + 1000000, -- Giá từ 1tr đến 3tr
        @TongGhe,
        N'Sắp bay'
	)

	set @k = @k + 1
end

select * from CHUYENBAY

-- 7. Dữ liệu về thanh toán (50 vé)
declare @v int = 1
while @v <= 50
begin
	declare @MaCB varchar(20), @GiaCoBan decimal(18,2), @SoGheTrong int
	select top 1 @MaCB = MaCB, @GiaCoBan = GiaVeCoBan, @SoGheTrong = SoGheTrong
	from CHUYENBAY where SoGheTrong > 0 order by newid()

	declare @MaKH int = (select top 1 MaKH from KHACHHANG order by NEWID());
    declare @MaNV varchar(20) = (select top 1 MaNV from NHANVIEN where VaiTro = N'Bán vé' order by NEWID())
    
    declare @HangGhe nvarchar(50) = case when @v % 5 = 0 then N'Thương gia' else N'Phổ thông' end
    declare @GiaTien decimal(18,2) = case when @HangGhe = N'Thương gia' then @GiaCoBan * 2 else @GiaCoBan end
    
    -- Tránh trùng số ghế
    declare @SoGhe varchar(10) = cast((@SoGheTrong) as varchar) + case when @v % 2 = 0 then 'A' else 'B' end
    
    -- insert Vé
    insert into VE (MaCB, MaKH, MaNV, SoGhe, HangGhe, GiaTien, NgayDat, TrangThai)
    values (@MaCB, @MaKH, @MaNV, @SoGhe, @HangGhe, @GiaTien, getdate(), N'Đã thanh toán');
    
    declare @MaVe int = scope_identity();
    
    -- Update lại số ghế trống của chuyến bay (Minh họa, sau này dùng Trigger)
    update CHUYENBAY set SoGheTrong = SoGheTrong - 1 where MaCB = @MaCB;
    
    -- Insert Thanh Toán
    insert into THANHTOAN (LanTT, MaVe, SoTien, NgayTT, PhuongThuc)
    values (1, @MaVe, @GiaTien, getdate(), N'Chuyển khoản');

    set @v = @v + 1;
end

select * from THANHTOAN