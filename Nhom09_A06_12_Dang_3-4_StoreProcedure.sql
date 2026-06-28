use QuanLyDatVeMayBay_06

-- DẠNG 3: Store Procedure sử dụng bảng tạm và biến
-- 6. sp_TopKhachHangVip 
create proc sp_TopKhachHangVip
	@TopN int
as
begin
	-- try
	begin try
		create table #TopKH (
			MaKH int,
			HoTen nvarchar(100),
			TongChiTieu decimal(18,2),
			XepLoai nvarchar(50)
		)

		insert into #TopKH(MaKH, HoTen, TongChiTieu)
		select kh.MaKH, kh.HoTen, isnull(sum(tt.SoTien), 0)
		from KHACHHANG kh
		join VE v on kh.MaKH = v.MaKH
		join THANHTOAN tt on v.MaVe = tt.MaVe
		where v.TrangThai = N'Đã thanh toán'
		group by kh.MaKH, kh.HoTen

		update #TopKH
		set XepLoai = case
			when TongChiTieu > 50000000 then N'Kim Cương'
			when TongChiTieu > 20000000 then N'Bạch Kim'
			when TongChiTieu > 10000000 then N'Vàng'
			else
			N'Bạc'
		end

		-- result
		select top(@TopN) * from #TopKH order by TongChiTieu desc
		drop table #TopKH
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
	end catch
end
--
exec sp_TopKhachHangVip @TopN = 3


-- 7. sp_DoanhThuTheoTuyen -> Sử dụng biến bảng (@TableVariable)
create proc sp_DoanhThuTheoTuyen
as
begin
	-- try
	begin try
		-- Khai báo Table variable
		declare @tblDoanhThu table(
			MaTuyen varchar(20),
			TongTien decimal(18,2),
			SoChuyenBay int
		)

		-- insert into table variable
		insert into @tblDoanhThu (MaTuyen, TongTien, SoChuyenBay)
		select cb.MaTuyen, isnull(sum(tt.SoTien), 0), count(distinct cb.MaCB)
		from CHUYENBAY cb
		left join VE v on cb.MaCB = v.MaCB and v.TrangThai = N'Đã thanh toán'
		left join THANHTOAN tt on v.MaVe = tt.MaVe
		group by cb.MaTuyen

		-- return result
		select tb.MaTuyen, sb1.TenSB as SanBayDi, sb2.TenSB as SanBayDen,
				dt.SoChuyenBay, dt.TongTien
		from @tblDoanhThu dt
		join TUYENBAY tb on dt.MaTuyen = tb.MaTuyen
		join SANBAY sb1 on tb.MaSBDi = sb1.MaSB
		join SANBAY sb2 on tb.MaSBDen = sb2.MaSB
		order by dt.TongTien desc
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);
	end catch
end
--
exec sp_DoanhThuTheoTuyen


-- DẠNG 4: Store Procedure sử dụng Cursor
-- 8. sp_DongBoTrangThaiChuyenBay
select * from CHUYENBAY
create proc sp_DongBoTrangThaiChuyenBay
as
begin
	-- try
	begin try
		declare @MaCB varchar(20)
		declare @NgayGioDi datetime
		declare @NgayGioDen datetime
		declare @TrangThaiHienTai nvarchar(50)
		declare @SoChuyenDaCapNhat int = 0

		-- Cursor
		declare cur_ChuyenBay cursor for
		select MaCB, NgayGioDi, NgayGioDen, TrangThai
		from CHUYENBAY
		where TrangThai in(N'Sắp bay', N'Đang bay')

		open cur_ChuyenBay
		fetch next from cur_ChuyenBay into @MaCB, @NgayGioDi, @NgayGioDen, @TrangThaiHienTai

		while @@fetch_status = 0
		begin
			declare @TrangThaiMoi nvarchar(50) = @TrangThaiHienTai
			declare @HienTai datetime = getdate()

			if @HienTai >= @NgayGioDen
				set @TrangThaiMoi = N'Đã hạ cánh'
			else if @HienTai >= @NgayGioDi and @HienTai < @NgayGioDen
				set @TrangThaiMoi = N'Đang bay'

			-- 
			if @TrangThaiMoi <> @TrangThaiHienTai
			begin
				update CHUYENBAY
				set TrangThai = @TrangThaiMoi
				where current of cur_ChuyenBay

				set @SoChuyenDaCapNhat = @SoChuyenDaCapNhat + 1
			end
		
			fetch next from cur_ChuyenBay into @MaCB, @NgayGioDi, @NgayGioDen, @TrangThaiHienTai
		end

		close cur_ChuyenBay
		deallocate cur_ChuyenBay

		print N'Đã đồng bộ trạng thái cho' + cast(@SoChuyenDaCapNhat as varchar) + N'chuyến bay'
	end try

	-- catch
	begin catch
		declare @ErrorMessage nvarchar(4000) = error_message();
        raiserror(@ErrorMessage, 16, 1);

		if cursor_status('global', 'cur_ChuyenBay') >= -1
		begin
			close cur_ChuyenBay
			deallocate cur_ChuyenBay
		end
	end catch
end
--
exec sp_DongBoTrangThaiChuyenBay
select * from CHUYENBAY
--
select MaCB, NgayGioDen, TrangThai as N'Trạng thái trước đồng bộ'
from CHUYENBAY
where TrangThai = N'Sắp bay' or TrangThai = N'Đang bay'

exec sp_DongBoTrangThaiChuyenBay

select MaCB, NgayGioDen, TrangThai as N'Trạng Thái Sau Đồng Bộ' 
from CHUYENBAY


-- 9. sp_HuyVeQuaHan -> Cursor auto cancel các vé chx tt > 24h
create proc sp_HuyVeQuaHan
as
begin
	-- try
	begin try
		declare @MaVe int
		declare @MaCB varchar(20)
		declare @SoVeDaHuy int = 0

		-- Cursor
		declare cur_HuyVe cursor for
		select MaVe, MaCB
		from VE
		where TrangThai = N'Chưa thanh toán'
			and datediff(hour, NgayDat, getdate()) > 24

		open cur_HuyVe
		fetch next from cur_HuyVe into @MaVe, @MaCB

		while @@fetch_status = 0
		begin
			-- Change status
			update VE
			set TrangThai = N'Đã hủy'
			where current of cur_HuyVe

			-- Return SoGheTrong cho chuyến bay
			update CHUYENBAY
			set SoGheTrong = SoGheTrong + 1
			where MaCB = @MaCB

			set @SoVeDaHuy = @SoVeDaHuy + 1

			fetch next from cur_HuyVe into @MaVe, @MaCB
		end

		close cur_HuyVe
		deallocate cur_HuyVe

		print N'Hệ thống đã tự động hủy' + cast(@SoVeDaHuy as varchar) + N'vé quá hạn chưa thanh toán'
	end try

	-- catch
	begin catch
		declare @ErrorMsg nvarchar(4000) = error_message();
        raiserror(@ErrorMsg, 16, 1);

		if cursor_status('global', 'cur_HuyVe') >= -1
		begin
			close cur_HuyVe
			deallocate cur_HuyVe
		end
	end catch
end

exec sp_HuyVeQuaHan