use QuanLyDatVeMayBay_06

-- DẠNG 5: Store Procedure nghiệp vụ lõi (Transaction)
--
-- 10. Đặt vé 
alter proc sp_DatVe
	@MaCB varchar(20),
	@MaKH int,
	@MaNV varchar(20),
	@SoGhe varchar(10),
	@HangGhe nvarchar(50)
as
begin
	-- try
	begin try
		begin tran

			declare @SoGheTrong int, @GiaVeCoBan decimal(18,2), @TrangThaiCB nvarchar(50)
			select @SoGheTrong = SoGheTrong, @GiaVeCoBan = GiaVeCoBan, @TrangThaiCB = TrangThai
			from CHUYENBAY with (updlock)
			where MaCB = @MaCB

			if @@rowcount = 0
			begin
				raiserror(N'Chuyến bay không tồn tại', 16, 1)
				rollback tran
				return
			end
		
			if @TrangThaiCB <> N'Sắp bay'
			begin 
				raiserror(N'Chuyến bay đã cất cánh hoặc bị hủy. Không thể đặt vé!', 16, 1)
				rollback tran
				return
			end

			if @SoGheTrong <= 0
			begin
				raiserror(N'Chuyến bay đã hết chỗ trống', 16, 1)
				rollback tran
				return
			end

			if exists (select 1 from VE where MaCB = @MaCB and SoGhe = @SoGhe and TrangThai <> N'Đã hủy')
			begin
				raiserror(N'Ghế %s đã có người đặt!', 16, 1, @SoGhe)
				rollback tran
				return
			end

			declare @GiaTien decimal(18,2) = @GiaVeCoBan
			if @HangGhe = N'Thương gia' set @GiaTien = @GiaVeCoBan * 2.0

			insert into VE(MaCB, MaKH, MaNV, SoGhe, HangGhe, GiaTien, NgayDat, TrangThai)
			values (@MaCB, @MaKH, @MaNV, @SoGhe, @HangGhe, @GiaTien, getdate(), N'Chưa thanh toán')
		
			declare @MaVeMoi int = scope_identity()

		commit tran
		print N'Đặt vé thành công! Mã vé của bạn là: ' + cast(@MaVeMoi as varchar)
	end try
	
	-- catch
	begin catch
		if @@TRANCOUNT > 0 
			rollback tran
		declare @ErrorMsg nvarchar(4000) = error_message()
		raiserror(@ErrorMsg, 16, 1)
	end catch
end
--
begin tran
declare @MaCBDemo varchar(20) = (select top 1 MaCB from CHUYENBAY where SoGheTrong > 0 and TrangThai = N'Sắp bay')
select SoGheTrong as N'Ghế trước khi đặt' from CHUYENBAY where MaCB = @MaCBDemo

exec sp_DatVe
	@MaCB = @MaCBDemo, 
    @MaKH = 1, 
    @MaNV = 'NV001', 
    @SoGhe = 'TEST01', 
    @HangGhe = N'Thương gia'

select SoGheTrong as N'Ghế sau khi đặt' from CHUYENBAY where MaCB = @MaCBDemo
rollback


-- 11. Thanh toán
alter proc sp_ThanhToanVe
	@MaVe int,
	@PhuongThuc nvarchar(50)
as
begin
	-- try
	begin try
		begin tran
			declare @TrangThaiVe nvarchar(50), @GiaTien decimal(18,2)
			select @TrangThaiVe = TrangThai, @GiaTien = GiaTien
			from VE with (updlock)
			where MaVe = @MaVe

			if @@rowcount = 0
			begin
				raiserror(N'Vé không tồn tại', 16, 1)
				rollback tran
				return
			end

			if @TrangThaiVe = N'Đã thanh toán'
			begin
				raiserror(N'Vé này đã được thanh toán trước đó', 16, 1)
				rollback tran
				return
			end

			if @TrangThaiVe = N'Đã hủy'
			begin
				raiserror(N'Vé này đã bị hủy, không thể thanh toán!', 16, 1)
				rollback tran 
				return
			end

			declare @LanTT int
			select @LanTT = isnull(max(LanTT), 0) + 1
			from THANHTOAN
			where MaVe = @MaVe

			insert into THANHTOAN (LanTT, MaVe, SoTien, NgayTT, PhuongThuc)
			values (@LanTT, @MaVe, @GiaTien, getdate(), @PhuongThuc)

		commit tran
		print N'Thanh toán vé thành công'
	end try

	-- catch
	begin catch
		if @@trancount > 0 rollback tran
		declare @ErrorMsg nvarchar(4000) = error_message()
        raiserror(@ErrorMsg, 16, 1)
	end catch
end
--
begin tran
declare @MaVeTest int
select top 1 @MaVeTest = MaVe from VE where TrangThai = N'Chưa thanh toán'

select MaVe, TrangThai as N'Trạng thái trước thanh toán' from VE where MaVe = @MaVeTest

print N'Tiến hành thanh toán cho vé số: ' + cast(@MaVeTest as varchar)
exec sp_ThanhToanVe @MaVe = @MaVeTest, @PhuongThuc = N'Chuyển khoản'

select MaVe, TrangThai as N'Trạng thái sau thanh toán' from VE where MaVe = @MaVeTest
select * from THANHTOAN where MaVe = @MaVeTest

rollback
select * from THANHTOAN


-- 12. Hủy vé
alter proc sp_HuyVeKhachHang	
	@MaVe int
as
begin
	-- try
	begin try
		declare @ThongBao nvarchar(500)
		declare @KetQuaCheck int

		exec @KetQuaCheck = sp_KiemTraTrangThaiVe @MaVe = @MaVe, @ThongBao = @ThongBao output

		if @KetQuaCheck = 1
		begin
			raiserror(@ThongBao, 16, 1)
			return
		end

		-- Hợp lệ -> hủy vé
		begin tran
			declare @MaCB varchar(20)
			select @MaCB = MaCB
			from VE
			where MaVe = @MaVe

			update VE set TrangThai = N'Đã hủy'
			where MaVe = @MaVe

		commit tran
		print N'Hủy vé thành công. Đã hoàn lại chỗ trống cho hệ thống!'
	end try

	-- catch
	begin catch
		if @@TRANCOUNT > 0 
			rollback tran
		declare @ErrorMsg nvarchar(4000) = error_message()
        raiserror(@ErrorMsg, 16, 1)
	end catch
end
--
begin tran
declare @MaVeDemo int, @MaCBDemo varchar(20)

select top 1 
    @MaVeDemo = v.MaVe, 
    @MaCBDemo = v.MaCB 
from VE v
join CHUYENBAY cb on v.MaCB = cb.MaCB
where v.TrangThai <> N'Đã hủy' and datediff(hour, getdate(), cb.NgayGioDi) > 24
-- Trước khi hủy
select TrangThai as N'Trạng thái vé trước khi hủy' from VE where MaVe = @MaVeDemo
select SoGheTrong as N'Số ghế trống trước khi hủy' from CHUYENBAY where MaCB = @MaCBDemo

-- 
print N'Đang tiến hành hủy vé số: ' + cast(@MaVeDemo as varchar)
exec sp_HuyVeKhachHang @MaVe = @MaVeDemo

-- Sau khi hủy
select TrangThai as N'Trạng thái vé sau khi hủy ' from VE where MaVe = @MaVeDemo
select SoGheTrong as N'Số ghế trống sau khi hủy ' from CHUYENBAY where MaCB = @MaCBDemo

rollback
