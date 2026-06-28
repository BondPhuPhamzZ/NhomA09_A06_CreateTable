use QuanLyDatVeMayBay_06

-- DẠNG 1: After insert triggers							
-- 1. Trừ ghế khi có ng đặt thành công
create trigger trg_DatVe
on VE
after insert
as
begin
	update CHUYENBAY
	set SoGheTrong = SoGheTrong - 1
	from CHUYENBAY cb
	join inserted i on cb.MaCB = i.MaCB
	where i.TrangThai <> N'Đã hủy'
end
-- Lỗi cần check lại
select * from CHUYENBAY
select * from VE
insert into VE (MaCB, MaKH, MaNV, SoGhe, HangGhe, GiaTien, NgayDat, TrangThai)
values ('VN0001', 2, 'NV001', 'GHE98', N'Phổ thông', 1000000, getdate(), N'Chưa thanh toán')


-- 2. Insert bảng THANHTOAN -> đổi trạng thái vé
create trigger trg_ThanhToan
on THANHTOAN
after insert
as
begin
	update VE
	set TrangThai = N'Đã thanh toán'
	from VE v
	join inserted i on v.MaVe = i.MaVe
end
-- Lỗi cần check lại
select * from VE
select * from THANHTOAN

select MaVe, TrangThai from VE where SoGhe = 'GHE98'
insert into THANHTOAN (LanTT, MaVe, SoTien, NgayTT, PhuongThuc)
values (1, 104, 1000000, getdate(), N'Tiền mặt')
select MaVe, TrangThai from VE where SoGhe = 'GHE98'


-- 3. Ko dc thêm chuyến bay trong quá khứ
create trigger trg_KiemTraLichBay
on CHUYENBAY
after insert
as
begin
	if exists(select 1 from inserted where NgayGioDi < getdate())
	begin
		raiserror(N'Lỗi: không thể tạo chuyến bay với ngày khởi hành trong quá khứ', 16, 1)
		rollback transaction
	end
end
--
insert into CHUYENBAY (MaCB, MaTuyen, MaMB, NgayGioDi, NgayGioDen, GiaVeCoBan, SoGheTrong, TrangThai)
values ('VN_TEST', 'TB_SGN_HAN', 'VN-A899', '2020-01-01', '2020-01-01', 1000000, 100, N'Sắp bay')


-- DẠNG 2: After update triggers
-- 4. trg_HoanVe: Trả ghế khi đổi status Vé
create trigger trg_HoanVe
on VE
after update
as
begin
	if update(TrangThai)
	begin
		update CHUYENBAY
		set SoGheTrong = SoGheTrong + 1
		from CHUYENBAY cb
		join inserted i on cb.MaCB = i.MaCB
		join deleted d on i.MaVe = d.MaVe
		where i.TrangThai = N'Đã hủy' and d.TrangThai <> N'Đã hủy'
	end
end
--
update VE set TrangThai = N'Đã hủy' where MaVe = 2


-- 5. Cập nhật time bay
create trigger trg_CapNhatChuyenBay
on CHUYENBAY
after update
as
begin
	if update(NgayGioDi) or update(NgayGioDen)
	begin
		if exists(select 1 from inserted where datediff(minute, NgayGioDi, NgayGioDen) < 30)
		begin
			raiserror(N'Lỗi: Khoảng cách giữa Giờ đi và Giờ đến phải ít nhất 30 phút', 16, 1)
			rollback transaction
		end
	end
end	
--
select * from CHUYENBAY
update CHUYENBAY 
set NgayGioDen = dateadd(minute, 10, NgayGioDi)
where MaCB = 'VN007_0630'
--
begin tran
declare @MaCB varchar(20) = (select top 1 MaCB from CHUYENBAY)
begin try
    update CHUYENBAY 
    set NgayGioDen = dateadd(minute, 10, NgayGioDi)
    where MaCB = @MaCB;
end try
begin catch
    print error_message()
end catch
rollback


-- 6. Lịch sử sửa giá Vé
create table LOG_GIAVE (
	ID int identity(1,1) primary key,
	MaCB varchar(20),
	GiaVeCu decimal(18,2),
	GiaVeMoi decimal(18,2),
	NgayCapNhat datetime default getdate(),
	NguoiCapNhat nvarchar(50) default system_user
)

create trigger trg_LogCapNhatGiaVe
on CHUYENBAY
after update
as
begin
	if update(GiaVeCoBan)
	begin
		insert into LOG_GIAVE (MaCB, GiaVeCu, GiaVeMoi)
		select i.MaCB, d.GiaVeCoBan, i.GiaVeCoBan
		from inserted i
		join deleted d on i.MaCB = d.MaCB
		where i.GiaVeCoBan <> d.GiaVeCoBan
	end
end
--
begin tran
declare @MaCB varchar(20) = (select top 1 MaCB from CHUYENBAY);
update CHUYENBAY set GiaVeCoBan = GiaVeCoBan + 500000 where MaCB = @MaCB;
select * from LOG_GIAVE;
rollback


-- DẠNG 3: Instead of delete trigger
-- 7. Ko dc xóa Sân bay nếu đã dc sdung trong Tuyến bay
create trigger trg_ChongXoaSanBay
on SANBAY
instead of delete
as
begin
	if exists(select 1 from TUYENBAY tb join deleted d on tb.MaSBDi = d.MaSB or tb.MaSBDen = d.MaSB)
	begin
		raiserror(N'Lỗi: Sân bay này đang được sử dụng trong Tuyến bay. Tuyệt đối không thể xóa!', 16, 1)
	end
	--
	else
	begin
		delete from SANBAY where MaSB in (select MaSB from deleted)
	end
end
--
begin tran
begin try
    delete from SANBAY where MaSB = 'SGN';
end try
begin catch
    print error_message();
end catch


-- 8. Ko xóa hẳn CHUYENBAY nếu đã có khách đặt -> đổi status thành "Đã hủy"
create trigger trg_ChongXoaChuyenBay
on CHUYENBAY
instead of delete
as
begin
	if exists (select 1 from Ve v join deleted d on v.MaCB = d.MaCB)
	begin
		print N'Cảnh báo: Chuyến bay đã có khách đặt vé. Chuyến bay sẽ chuyển trạng thái thành "Đã hủy!"'
		update CHUYENBAY
		set TrangThai = N'Đã hủy'
		where MaCB in (select MaCB from deleted)
	end
	--
	else
	begin
		delete from CHUYENBAY where MaCB in (select MaCB from deleted)
	end
end
--
select * from CHUYENBAY
delete from CHUYENBAY where MaCB = 'VN002_0625'


-- 9. Cấm xóa khách hàng đã từng giao dịch
create trigger trg_ChongXoaKhachHang
on KHACHHANG
instead of delete
as
begin
	if exists(select 1 from VE v join deleted d on v.MaKH = d.MaKH)
	begin
		raiserror(N'Lỗi: Khách hàng này đã từng có giao dịch mua vé. Không thể xóa để bảo toàn dữ liệu doanh thu!', 16, 1)
	end
	--
	else
	begin
		delete from SDT_KHACHHANG where MaKH in (select MaKH from deleted)
		delete from KHACHHANG where MaKH in (select MaKH from deleted)
	end
end
--
delete from KHACHHANG where MaKH = 2
--
declare @MaKH int = (select top 1 MaKH from VE);
begin try
    delete from KHACHHANG where MaKH = @MaKH;
end try
begin catch
    print error_message();
end catch