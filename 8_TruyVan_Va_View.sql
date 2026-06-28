USE QuanLyDatVeMayBay_06;
GO

-- =========================================================================================
-- PHẦN 1: 5 CÂU TRUY VẤN NGHIỆP VỤ PHỨC TẠP (SELECT, JOIN, GROUP BY, HAVING, SUBQUERY)
-- =========================================================================================

-- Câu 1: Tìm danh sách các Khách hàng VIP có tổng chi tiêu mua vé (đã thanh toán) lớn hơn 5.000.000 VNĐ.
-- Yêu cầu áp dụng: JOIN (nhiều bảng), GROUP BY, HAVING
SELECT 
    kh.MaKH, 
    kh.HoTen, 
    kh.SoHoChieu,
    COUNT(v.MaVe) AS SoVeDaMua,
    SUM(tt.SoTien) AS TongChiTieu
FROM KHACHHANG kh
JOIN VE v ON kh.MaKH = v.MaKH
JOIN THANHTOAN tt ON v.MaVe = tt.MaVe
WHERE v.TrangThai = N'Đã thanh toán'
GROUP BY kh.MaKH, kh.HoTen, kh.SoHoChieu
HAVING SUM(tt.SoTien) > 5000000
ORDER BY TongChiTieu DESC;
GO


-- Câu 2: Thống kê số lượng chuyến bay và tổng doanh thu dự kiến của từng Sân bay xuất phát (Sân bay đi).
-- Yêu cầu áp dụng: JOIN, GROUP BY, Aggregate Functions
SELECT 
    sb.MaSB AS MaSanBayDi,
    sb.TenSB AS TenSanBayDi,
    COUNT(cb.MaCB) AS SoChuyenBay,
    ISNULL(SUM(v.GiaTien), 0) AS TongDoanhThu
FROM SANBAY sb
JOIN TUYENBAY tb ON sb.MaSB = tb.MaSBDi
JOIN CHUYENBAY cb ON tb.MaTuyen = cb.MaTuyen
LEFT JOIN VE v ON cb.MaCB = v.MaCB AND v.TrangThai = N'Đã thanh toán'
GROUP BY sb.MaSB, sb.TenSB
ORDER BY SoChuyenBay DESC;
GO


-- Câu 3: Tìm thông tin những chuyến bay có doanh thu cao nhất hệ thống.
-- Yêu cầu áp dụng: Subquery (Truy vấn lồng), JOIN, GROUP BY, HAVING
SELECT 
    cb.MaCB,
    tb.MaSBDi,
    tb.MaSBDen,
    SUM(tt.SoTien) AS DoanhThu
FROM CHUYENBAY cb
JOIN TUYENBAY tb ON cb.MaTuyen = tb.MaTuyen
JOIN VE v ON cb.MaCB = v.MaCB
JOIN THANHTOAN tt ON v.MaVe = tt.MaVe
WHERE v.TrangThai = N'Đã thanh toán'
GROUP BY cb.MaCB, tb.MaSBDi, tb.MaSBDen
HAVING SUM(tt.SoTien) = (
    -- Subquery tìm ra mức doanh thu cao nhất
    SELECT MAX(TongTien)
    FROM (
        SELECT SUM(SoTien) AS TongTien
        FROM VE v2
        JOIN THANHTOAN tt2 ON v2.MaVe = tt2.MaVe
        WHERE v2.TrangThai = N'Đã thanh toán'
        GROUP BY v2.MaCB
    ) AS MaxDoanhThu
);
GO


-- Câu 4: Tìm danh sách các chuyến bay "Ế" (Chưa có bất kỳ hành khách nào đặt vé).
-- Yêu cầu áp dụng: Subquery (NOT IN) hoặc LEFT JOIN kèm IS NULL
SELECT 
    cb.MaCB, 
    mb.TenMB,
    cb.NgayGioDi,
    cb.SoGheTrong
FROM CHUYENBAY cb
JOIN MAYBAY mb ON cb.MaMB = mb.MaMB
WHERE cb.MaCB NOT IN (
    -- Subquery lấy ra những chuyến bay ĐÃ CÓ người đặt vé
    SELECT DISTINCT MaCB FROM VE
);
GO


-- Câu 5: Thống kê tổng doanh thu theo từng tháng trong năm hiện tại, chỉ lấy những tháng có doanh thu > 0.
-- Yêu cầu áp dụng: Built-in Date Functions (MONTH, YEAR), GROUP BY, HAVING
SELECT 
    MONTH(tt.NgayTT) AS Thang,
    YEAR(tt.NgayTT) AS Nam,
    COUNT(tt.MaVe) AS SoVeDaBan,
    SUM(tt.SoTien) AS DoanhThuThang
FROM THANHTOAN tt
JOIN VE v ON tt.MaVe = v.MaVe
WHERE v.TrangThai = N'Đã thanh toán' AND YEAR(tt.NgayTT) = YEAR(GETDATE())
GROUP BY MONTH(tt.NgayTT), YEAR(tt.NgayTT)
HAVING SUM(tt.SoTien) > 0
ORDER BY Nam, Thang;
GO


-- =========================================================================================
-- PHẦN 2: TẠO VIEW CHO CÁC TRUY VẤN THƯỜNG DÙNG
-- =========================================================================================

-- View 1: View_ChuyenBay_ConCho (Cho phép khách hàng tra cứu nhanh các chuyến bay còn chỗ trống)
CREATE VIEW View_ChuyenBay_ConCho
AS
SELECT 
    cb.MaCB,
    sbDi.ThanhPho AS DiemXuatPhat,
    sbDen.ThanhPho AS DiemDen,
    cb.NgayGioDi,
    cb.NgayGioDen,
    cb.GiaVeCoBan,
    cb.SoGheTrong,
    cb.TrangThai
FROM CHUYENBAY cb
JOIN TUYENBAY tb ON cb.MaTuyen = tb.MaTuyen
JOIN SANBAY sbDi ON tb.MaSBDi = sbDi.MaSB
JOIN SANBAY sbDen ON tb.MaSBDen = sbDen.MaSB
WHERE cb.SoGheTrong > 0 AND cb.TrangThai = N'Sắp bay';
GO

-- Cách gọi thử View 1:
-- SELECT * FROM View_ChuyenBay_ConCho;
-- GO


-- View 2: View_ChiTietGiaoDich (Cho phép kế toán đối soát thông tin thanh toán của khách hàng nhanh chóng)
CREATE VIEW View_ChiTietGiaoDich
AS
SELECT 
    tt.LanTT,
    v.MaVe,
    kh.HoTen AS TenKhachHang,
    kh.SoHoChieu,
    v.MaCB,
    tt.SoTien,
    tt.PhuongThuc,
    tt.NgayTT
FROM THANHTOAN tt
JOIN VE v ON tt.MaVe = v.MaVe
JOIN KHACHHANG kh ON v.MaKH = kh.MaKH
WHERE v.TrangThai = N'Đã thanh toán';
GO

-- Cách gọi thử View 2:
-- SELECT * FROM View_ChiTietGiaoDich;
-- GO
