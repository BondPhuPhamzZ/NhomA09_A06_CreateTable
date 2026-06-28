use QuanLyDatVeMayBay_06
go

-- 12 STORE PROCEDURE

-- DẠNG 1: Store Procedure với tham số đầu vào (Input Parameter)
-- 1. sp_ThemSanBay: Insert check trùng MaSB
create proc sp_ThemSanBay
	@MaSB varchar(10),
	@TenSB nvarchar(100),
	@ThanhPho nvarchar(100),
	@QuocGia nvarchar(100)
as
begin
	-- try
	begin try
		if exists (select 1 from SANBAY where MaSB = @MaSB)
		begin
			raiserror(N'Lỗi: Mã sân bay %s đã tồn tại trong hệ thống!', 16, 1, @MaSB)
			return
		end

		insert into SANBAY(MaSB, TenSB, ThanhPho, QuocGia)
		values (@MaSB, @TenSB, @ThanhPho, @QuocGia)

		print N'Thêm sân bay thành công!'
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message()
		raiserror(@ErrorMessage, 16, 1)
	end catch
end
--
select * from SANBAY
exec sp_ThemSanBay @MaSB = 'SGN', @TenSB = N'Tân Sơn Nhất', @ThanhPho = N'Hồ Chí Minh', @QuocGia = N'Việt Nam'
exec sp_ThemSanBay @MaSB = 'PQC2', @TenSB = N'Phú Quốc 2', @ThanhPho = N'Kiên Giang', @QuocGia = N'Việt Nam'


-- 2. sp_TimKhachHang: Tra cứu khách hàng theo SDT
create proc sp_TimKhachHang
	@SoDienThoai varchar(20)
as
begin
	-- try
	begin try
		if not exists(select 1 from SDT_KHACHHANG where SoDienThoai = @SoDienThoai)
		begin
			raiserror(N'Lỗi: không tìm thấy khách hàng nào sử dụng số điện thoại %s', 16, 1, @SoDienThoai)
			return
		end

		select kh.MaKH, kh.HoTen, kh.Email, kh.SoHoChieu, sdt.SoDienThoai
		from KHACHHANG kh
		join SDT_KHACHHANG sdt on kh.MaKH = sdt.MaKH
		where sdt.SoDienThoai = @SoDienThoai
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
	end catch
end

select * from SDT_KHACHHANG
exec sp_TimKhachHang @SoDienThoai = '0996707965'
select * from KHACHHANG


-- 3. sp_ThemChuyenBay: Check tồn tại khóa ngoại trước khi Insert
create proc sp_ThemChuyenBay
	@MaCB varchar(20),
	@MaTuyen varchar(20),
	@MaMB varchar(20),
	@NgayGioDi datetime,
	@NgayGioDen datetime,
	@GiaVeCoBan decimal(18,2)
as
begin
	-- try
	begin try
		-- Check trùng MaCB
		if exists (select 1 from CHUYENBAY where MaCB = @MaCB)
		begin
			raiserror(N'Lỗi: Mã chuyến bay %s đã tồn tại!', 16, 1, @MaCB);
            return;
		end

		-- Check MaTuyen ko tồn tại
		if not exists (select 1 from TUYENBAY where MaTuyen = @MaTuyen)
		begin
			raiserror(N'Lỗi: Tuyến bay %s không tồn tại trong hệ thống!', 16, 1, @MaTuyen);
            return;
		end
		
		-- Check MaMB ko tồn tại
		if not exists(select 1 from MAYBAY where MaMB = @MaMB)
		begin
			raiserror(N'Lỗi: Máy bay %s không tồn tại!', 16, 1, @MaMB);
            return;
		end

		-- Gán tổng số ghế của Máy bay cho SoGheTrong của Chuyến bay
		declare @TongSoGhe int
		select @TongSoGhe = TongSoGhe from MAYBAY where MaMB = @MaMB

		insert into CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
		values (@MaCB, @MaTuyen, @MaMB, @NgayGioDi, @NgayGioDen, @GiaVeCoBan, @TongSoGhe, N'Sắp bay')

		print N'Thêm chuyến bay mới thành công'
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
	end catch
end
--
select * from CHUYENBAY
select * from TUYENBAY
select * from MAYBAY
exec sp_ThemChuyenBay @MaCB = 'VN0001', @MaTuyen = 'TB_BKK_VCA', @MaMB = 'VN-A322', @NgayGioDi = '2026-06-24', @NgayGioDen = '2026-06-28', @GiaVeCoBan = 20000000
--
begin tran
begin try
	exec sp_ThemChuyenBay
		@MaCB = 'VN0001', 
        @MaTuyen = 'TB_BKK_VCA', 
        @MaMB = 'VN-A322', 
        @NgayGioDi = '2026-06-24', 
        @NgayGioDen = '2026-06-28', 
        @GiaVeCoBan = 20000000;
end try
begin catch
	print N'Lỗi: ' + error_message()
end catch



-- DẠNG 2: Store Procedure trả về result = Output & Return
-- 4. sp_TinhDoanhThuCB: Return tổng tiền của 1 chuyến bay qua biến Output
create proc sp_TinhDoanhThuCB
	@MaCB varchar(20),
	@TongDoanhThu decimal(18,2) output
as
begin
	-- try
	begin try
		if not exists (select 1 from CHUYENBAY where MaCB = @MaCB)
		begin
			raiserror(N'Lỗi: Chuyến bay %s không tồn tại!', 16, 1, @MaCB);
            return;
		end

		select @TongDoanhThu = isnull(sum(tt.SoTien), 0)
		from THANHTOAN tt
		join VE v on tt.MaVe = v.MaVe
		where v.MaCB = @MaCB and v.TrangThai = N'Đã thanh toán'
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
	end catch
end
--
select * from CHUYENBAY
declare @DoanhThu decimal(18,2)
exec sp_TinhDoanhThuCB @MaCB = 'VN010_0623', @TongDoanhThu = @DoanhThu output
print N'Doanh thu chuyến bay là: ' + cast(@DoanhThu as varchar)




-- 5. check Trạng thái của Vé: Kết hợp Return và Output
-- return 0: Hợp lệ, return 1: Lỗi (ko cho hủy)
create proc sp_KiemTraTrangThaiVe
	@MaVe int,
	@ThongBao nvarchar(500) output
as
begin
	-- try
	begin try
		declare @TrangThaiVe nvarchar(50)
		declare @NgayGioDi datetime

		select @TrangThaiVe = v.TrangThai, @NgayGioDi = cb.NgayGioDi
		from VE v
		join CHUYENBAY cb on v.MaCB = cb.MaCB
		where v.MaVe = @MaVe

		if @@ROWCOUNT = 0
		begin
			set @ThongBao = N'Vé không tồn tại!'
			return 1
		end

		if @TrangThaiVe = N'Đã hủy'
		begin
			set @ThongBao = N'Vé này đã bị hủy trước đó'
			return 1
		end

		if datediff(hour, getdate(), @NgayGioDi) < 24
		begin
			set @ThongBao = N'Chỉ được phép hủy vé trước giờ bay 24 tiếng. Quá hạn hủy!';
            return 1;
		end

		set @ThongBao = N'Vé hợp lệ. Có thể tiến hành thủ tục hủy vé.';
        return 0;
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
        return 1;
	end catch
end
--
select * from VE
declare @ThongBao nvarchar(500)
declare @KetQua int
exec @KetQua = sp_KiemTraTrangThaiVe @MaVe = 1, @ThongBao = @ThongBao output
print @ThongBao


