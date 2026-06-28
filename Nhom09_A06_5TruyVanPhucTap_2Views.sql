use QuanLyDatVeMayBay_06

-- 5 Câu truy vấn nghiệp vụ phức tạp (select, join, group by, having, subquery)
--
-- 1. Tìm dsach khách hàng vip có tổng chi tiêu mua vé (đã thanh toán) > 5.000.000 VNĐ
-- Áp dụng: join (nhiều bảng), group by, having
select kh.MaKH, kh.HoTen, kh.SoHoChieu, COUNT(v.MaVe) as SoVeDaMua, SUM(tt.SoTien) as TongChiTieu
from KHACHHANG kh
join VE v on kh.MaKH = v.MaKH
join THANHTOAN tt on v.MaVe = tt.MaVe
where v.TrangThai = N'Đã thanh toán'
group by kh.MaKH, kh.HoTen, kh.SoHoChieu
having SUM(tt.SoTien) > 5000000
order by TongChiTieu desc


-- 2. Thống kê số lượng chuyến bay và tổng doanh thu dự kiến của từng Sân bay xuất phát (SBDi)
-- Áp dụng: join, group by, aggregate functions
select sb.MaSB as MaSanBayDi, sb.TenSB as TenSanBayDi, COUNT(cb.MaCB) as SoChuyenBay, ISNULL(sum(v.GiaTien), 0) as TongDoanhThu
from SANBAY sb
join TUYENBAY tb on sb.MaSB = tb.MaSBDi
join CHUYENBAY cb on tb.MaTuyen = cb.MaTuyen
left join VE v on cb.MaCB = v.MaCB and v.TrangThai = N'Đã thanh toán'
group by sb.MaSB, sb.TenSB
order by SoChuyenBay desc


-- 3. Tìm thông tin chuyến bay có doanh thu cao nhất hệ thống
-- Áp dụng: Subquery (truy vấn lồng), join, group by, having
select cb.MaCB, tb.MaSBDi, tb.MaSBDen, SUM(tt.SoTien) as DoanhThu
from CHUYENBAY cb
join TUYENBAY tb on cb.MaTuyen = tb.MaTuyen
join VE v on cb.MaCB = v.MaCB
join THANHTOAN TT ON v.MaVe = tt.MaVe
where v.TrangThai = N'Đã thanh toán'
group by cb.MaCB, tb.MaSBDi, tb.MaSBDen
having SUM(tt.SoTien) = (
	select MAX(TongTien)
	from(
		select SUM(SoTien) as TongTien
		from VE v2
		join THANHTOAN tt2 on v2.MaVe = tt2.MaVe
		where v2.TrangThai = N'Đã thanh toán'
		group by v2.MaCB
	) as MaxDoanhThu
) 
select * from THANHTOAN
select * from VE


-- 4. Tìm danh sách các chuyến bay "Ế" (chx có bất kì khách nào đặt vé)
-- Áp dụng: Subquery (not in) hoặc left join kèm is null
select cb.MaCB, mb.TenMB, cb.NgayGioDi, cb.SoGheTrong
from CHUYENBAY cb
join MAYBAY mb on cb.MaMB = mb.MaMB
where cb.MaCB not in(
	select distinct MaCB from VE
)


-- 5. Thống kê tổng doanh thu theo từng tháng trong năm hiện tại
-- Áp dụng: (MONTH, YEAR), group by, having
select 
	MONTH(tt.NgayTT) as Thang,
	YEAR(tt.NgayTT) as Nam,
	COUNT(tt.MaVe) as SoVeDaBan,
	SUM(tt.SoTien) as DoanhThuThang
from THANHTOAN tt
join VE v on tt.MaVe = v.MaVe
where v.TrangThai = N'Đã thanh toán' and YEAR(tt.NgayTT) = YEAR(GETDATE())
group by MONTH(tt.NgayTT), YEAR(tt.NgayTT)
having SUM(tt.SoTien) > 0
order by Nam, Thang



-- View cho các truy vấn thường dùng
--
-- 1. cho phép khách tra cứu nhanh các chuyến bay còn chỗ trống
create view View_ChuyenBay_ConCho
as
select
	cb.MaCB,
	sbDi.ThanhPho as DiemXuatPhat,
	sbDen.ThanhPho as DiemDen,
	cb.NgayGioDi,
	cb.NgayGioDen,
	cb.GiaVeCoBan,
	cb.SoGheTrong,
	cb.TrangThai
from CHUYENBAY cb
join TUYENBAY tb on cb.MaTuyen = tb.MaTuyen
join SANBAY sbDi on tb.MaSBDi = sbDi.MaSB
join SANBAY sbDen on tb.MaSBDen = sbDen.MaSB
where cb.SoGheTrong > 0 and cb.TrangThai = N'Sắp bay'
--
select * from View_ChuyenBay_ConCho


-- 2. Cho phép kế toàn đối soát thông tin thanh toán của khách hàng nhanh chóng
create view View_ChiTietGiaoDich
as
select
	tt.LanTT,
	v.MaVe,
	kh.HoTen as TenKhachHang,
	kh.SoHoChieu,
	v.MaCB,
	tt.SoTien,
	tt.PhuongThuc,
	tt.NgayTT
from THANHTOAN tt
join VE v on tt.MaVe = v.MaVe
join KHACHHANG kh on v.MaKH = kh.MaKH
where v.TrangThai = N'Đã thanh toán'
--
select * from View_ChiTietGiaoDich

